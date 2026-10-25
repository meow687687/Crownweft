class_name LogisticsSystem
extends RefCounted

var job_board: JobBoard = null

# Simulated hauler record
class Hauler:
	var id: int
	var current_tile: Vector2i
	var active_job: HaulJob = null
	var carried_resource: StringName = &""
	var carried_amount: int = 0
	var is_route_blocked: bool = false
	
	func _init(p_id: int, p_tile: Vector2i = Vector2i.ZERO) -> void:
		id = p_id
		current_tile = p_tile

var haulers: Array[Hauler] = []

func _init(p_job_board: JobBoard = null) -> void:
	if p_job_board == null:
		job_board = JobBoard.new()
	else:
		job_board = p_job_board

func register_hauler(id: int, start_tile: Vector2i = Vector2i.ZERO) -> Hauler:
	var h: Hauler = Hauler.new(id, start_tile)
	haulers.append(h)
	return h

func check_and_create_demand(
	source_building: BuildingState,
	dest_building: BuildingState,
	resource_id: StringName,
	target_batch_size: int,
	current_tick: int,
	priority: int = 1
) -> HaulJob:
	if source_building == null or dest_building == null or target_batch_size <= 0:
		return null
		
	var source_inv: Inventory = source_building.inventory
	var dest_inv: Inventory = dest_building.inventory
	
	# Determine how much can be moved
	var available: int = source_inv.get_available_outgoing(resource_id)
	var free_cap: int = dest_inv.get_free_capacity()
	
	var transfer_amount: int = mini(target_batch_size, mini(available, free_cap))
	if transfer_amount <= 0:
		return null
		
	return job_board.create_job(resource_id, transfer_amount, source_inv, dest_inv, priority, current_tick)

func dispatch_jobs() -> void:
	var pending: Array[HaulJob] = job_board.get_pending_jobs()
	for job: HaulJob in pending:
		for hauler: Hauler in haulers:
			if hauler.active_job == null:
				if job_board.assign_job(job, hauler.id):
					hauler.active_job = job
					break

func tick_haulers(inventories_by_id: Dictionary, current_tick: int) -> void:
	for hauler: Hauler in haulers:
		if hauler.active_job == null:
			continue
			
		var job: HaulJob = hauler.active_job
		var source_inv: Inventory = inventories_by_id.get(job.source_inventory_id, null)
		var dest_inv: Inventory = inventories_by_id.get(job.destination_inventory_id, null)
		
		if hauler.is_route_blocked:
			# Route failure recovery test
			job_board.cancel_job(job, source_inv, dest_inv, "ROUTE_BLOCKED")
			hauler.active_job = null
			hauler.is_route_blocked = false
			continue
			
		match job.status:
			HaulJob.Status.ASSIGNED:
				# Hauler arrives at source to pickup
				var ok: bool = job_board.execute_pickup(job, source_inv)
				if ok:
					hauler.carried_resource = job.resource_id
					hauler.carried_amount = job.amount
				else:
					job_board.cancel_job(job, source_inv, dest_inv, "PICKUP_FAILED")
					hauler.active_job = null
					
			HaulJob.Status.IN_TRANSIT:
				# Hauler delivers at destination
				var ok: bool = job_board.execute_delivery(job, dest_inv)
				if ok:
					hauler.carried_resource = &""
					hauler.carried_amount = 0
					hauler.active_job = null
				else:
					job_board.cancel_job(job, source_inv, dest_inv, "DELIVERY_FAILED")
					hauler.active_job = null
