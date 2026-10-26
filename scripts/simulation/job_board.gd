class_name JobBoard
extends RefCounted

var _next_job_id: int = 1
var jobs: Dictionary = {} # int (job_id) -> HaulJob

func create_job(resource_id: StringName, amount: int, source_inv: Inventory, dest_inv: Inventory, priority: int = 0, current_tick: int = 0) -> HaulJob:
	if source_inv == null or dest_inv == null or amount <= 0:
		return null
	
	# Validate source has enough unreserved stock
	if source_inv.get_available_outgoing(resource_id) < amount:
		return null
	
	# Validate destination can accept and has capacity
	var is_self_transfer: bool = (source_inv == dest_inv)
	if not is_self_transfer and not dest_inv.can_accept(resource_id, amount):
		return null
	if is_self_transfer and not dest_inv.accepts(resource_id):
		return null
	
	# Atomically reserve
	var out_ok: bool = source_inv.reserve_out(resource_id, amount)
	if not out_ok:
		return null
	
	var in_ok: bool = false
	if is_self_transfer:
		var current: int = dest_inv.get_reserved_in(resource_id)
		dest_inv.reserved_in[resource_id] = current + amount
		in_ok = true
	else:
		in_ok = dest_inv.reserve_in(resource_id, amount)
	if not in_ok:
		# Rollback source reservation
		source_inv.release_reserved_out(resource_id, amount)
		return null
	
	var job: HaulJob = HaulJob.new(_next_job_id, resource_id, amount, source_inv.owner_id, dest_inv.owner_id, priority, current_tick)
	_next_job_id += 1
	job.status = HaulJob.Status.RESERVED
	job.reserved_amount = amount
	jobs[job.id] = job
	return job

func assign_job(job: HaulJob, citizen_id: int) -> bool:
	if job == null or job.status != HaulJob.Status.RESERVED:
		return false
	job.assigned_citizen_id = citizen_id
	job.status = HaulJob.Status.ASSIGNED
	return true

func execute_pickup(job: HaulJob, source_inv: Inventory) -> bool:
	if job == null or source_inv == null:
		return false
	if job.status != HaulJob.Status.ASSIGNED and job.status != HaulJob.Status.RESERVED:
		return false
	if source_inv.owner_id != job.source_inventory_id:
		return false
	
	var ok: bool = source_inv.remove_resource(job.resource_id, job.amount, "HAUL_PICKUP", true)
	if not ok:
		return false
	
	# The source reservation has now been converted into physical removal from source inventory
	job.status = HaulJob.Status.IN_TRANSIT
	return true

func execute_delivery(job: HaulJob, dest_inv: Inventory) -> bool:
	if job == null or dest_inv == null:
		return false
	if job.status != HaulJob.Status.IN_TRANSIT:
		return false
	if dest_inv.owner_id != job.destination_inventory_id:
		return false
	
	# Delivery resolves destination reservation into actual stock
	var ok: bool = dest_inv.add_resource(job.resource_id, job.amount, "HAUL_DELIVERY", true)
	if not ok:
		return false
	
	job.status = HaulJob.Status.DELIVERED
	job.reserved_amount = 0
	return true

func cancel_job(job: HaulJob, source_inv: Inventory, dest_inv: Inventory, reason: String = "") -> void:
	if job == null:
		return
	if job.status == HaulJob.Status.DELIVERED or job.status == HaulJob.Status.CANCELLED:
		return
	
	# If cancelled before pickup, release both reservations
	if job.status == HaulJob.Status.RESERVED or job.status == HaulJob.Status.ASSIGNED or job.status == HaulJob.Status.REQUESTED:
		if source_inv != null and job.reserved_amount > 0:
			source_inv.release_reserved_out(job.resource_id, job.reserved_amount)
		if dest_inv != null and job.reserved_amount > 0:
			dest_inv.release_reserved_in(job.resource_id, job.reserved_amount)
		job.reserved_amount = 0
	elif job.status == HaulJob.Status.IN_TRANSIT:
		# Cargo has already left the source. Cancelling here would silently destroy it.
		# Keep the job recoverable; LogisticsSystem can reroute it to another inventory.
		job.status = HaulJob.Status.BLOCKED
		job.blocked_reason = "IN_TRANSIT_CANNOT_CANCEL — cargo retained: %s" % reason
		return
	elif job.status == HaulJob.Status.BLOCKED:
		# A blocked pre-pickup job still owns an outgoing reservation; a carried-cargo
		# job no longer does. Never release the latter as if it were still at source.
		var source_reservation: int = source_inv.get_reserved_out(job.resource_id) if source_inv != null else 0
		if source_inv != null and dest_inv != null and job.reserved_amount > 0 and source_reservation >= job.reserved_amount:
			source_inv.release_reserved_out(job.resource_id, job.reserved_amount)
			dest_inv.release_reserved_in(job.resource_id, job.reserved_amount)
			job.reserved_amount = 0
		elif source_inv == null:
			# The source building was removed before pickup. No carrier owns the stock,
			# so release the surviving destination reservation if there is one.
			if dest_inv != null and job.reserved_amount > 0:
				dest_inv.release_reserved_in(job.resource_id, job.reserved_amount)
			job.reserved_amount = 0
		else:
			# Without proof that this is a pre-pickup reservation, preserve job state.
			job.blocked_reason = "BLOCKED_JOB_REQUIRES_CARGO_RECONCILIATION: %s" % reason
			return
	
	job.status = HaulJob.Status.CANCELLED
	job.blocked_reason = reason

func get_pending_jobs() -> Array[HaulJob]:
	var result: Array[HaulJob] = []
	for job: HaulJob in jobs.values():
		if job.status == HaulJob.Status.RESERVED:
			result.append(job)
	return result
