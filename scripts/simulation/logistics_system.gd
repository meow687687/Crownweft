class_name LogisticsSystem
extends RefCounted

var job_board: JobBoard = null
const PATH_RETRY_TICKS: int = 4

class Hauler:
	var id: int
	var current_tile: Vector2i
	var active_job: HaulJob = null
	var carried_resource: StringName = &""
	var carried_amount: int = 0
	var is_route_blocked: bool = false
	var path: Array[Vector2i] = []
	var path_index: int = 0
	var path_target_inventory_id: int = -1
	var next_path_retry_tick: int = 0
	var last_block_reason: String = ""

	func _init(p_id: int, p_tile: Vector2i = Vector2i.ZERO) -> void:
		id = p_id
		current_tile = p_tile

	func clear_path() -> void:
		path.clear()
		path_index = 0
		path_target_inventory_id = -1


var haulers: Array[Hauler] = []

func _init(p_job_board: JobBoard = null) -> void:
	job_board = p_job_board if p_job_board != null else JobBoard.new()

func register_hauler(id: int, start_tile: Vector2i = Vector2i.ZERO) -> Hauler:
	var hauler := Hauler.new(id, start_tile)
	haulers.append(hauler)
	return hauler

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
	if source_building == dest_building:
		return null
	var source_inv: Inventory = source_building.inventory
	var dest_inv: Inventory = dest_building.inventory
	var available: int = source_inv.get_available_outgoing(resource_id)
	var free_cap: int = dest_inv.get_free_capacity()
	var transfer_amount: int = mini(target_batch_size, mini(available, free_cap))
	if transfer_amount <= 0:
		return null
	return job_board.create_job(resource_id, transfer_amount, source_inv, dest_inv, priority, current_tick)

func dispatch_jobs() -> void:
	var pending: Array[HaulJob] = job_board.get_pending_jobs()
	pending.sort_custom(func(a: HaulJob, b: HaulJob) -> bool:
		if a.priority == b.priority:
			return a.created_tick < b.created_tick
		return a.priority > b.priority
	)
	for job: HaulJob in pending:
		for hauler: Hauler in haulers:
			if hauler.active_job == null and not hauler.is_route_blocked:
				if job_board.assign_job(job, hauler.id):
					hauler.active_job = job
					hauler.clear_path()
					hauler.last_block_reason = ""
					break

# Goods only leave a source after a hauler reaches it, and only enter a destination
# after it reaches that destination. Maps are keyed by Inventory.owner_id.
func tick_haulers(
	inventories_by_id: Dictionary,
	current_tick: int,
	pathfinding: PathfindingService = null,
	buildings_by_inventory: Dictionary = {}
) -> void:
	for hauler: Hauler in haulers:
		var job: HaulJob = hauler.active_job
		if job == null:
			continue

		var source_inv: Inventory = inventories_by_id.get(job.source_inventory_id, null)
		var dest_inv: Inventory = inventories_by_id.get(job.destination_inventory_id, null)

		if hauler.is_route_blocked:
			if job.status == HaulJob.Status.RESERVED or job.status == HaulJob.Status.ASSIGNED:
				job_board.cancel_job(job, source_inv, dest_inv, "ROUTE_BLOCKED")
				hauler.active_job = null
				hauler.carried_resource = &""
				hauler.carried_amount = 0
				hauler.clear_path()
			else:
				# Preserve carried cargo and destination reservation while blocked.
				job.blocked_reason = "ROUTE_BLOCKED — cargo retained until route reopens"
				hauler.last_block_reason = "ROUTE_BLOCKED"
			continue

		if pathfinding == null:
			hauler.last_block_reason = "PATHFINDING_UNAVAILABLE"
			job.blocked_reason = "PATHFINDING_UNAVAILABLE"
			continue

		var target_inventory_id: int = -1
		if job.status == HaulJob.Status.ASSIGNED or job.status == HaulJob.Status.RESERVED:
			target_inventory_id = job.source_inventory_id
		elif job.status == HaulJob.Status.IN_TRANSIT:
			target_inventory_id = job.destination_inventory_id
		elif job.status == HaulJob.Status.BLOCKED and hauler.carried_amount > 0:
			# Prefer the original destination if it still exists and is reachable. This
			# preserves its inbound reservation instead of leaking capacity on every retry.
			var original_destination: BuildingState = buildings_by_inventory.get(job.destination_inventory_id, null)
			var original_reachable: bool = false
			if original_destination != null and not original_destination.is_destroyed:
				var original_def: Dictionary = BuildingCatalog.get_all_defs().get(original_destination.definition_id, {})
				var original_footprint: Vector2i = original_def.get("footprint", Vector2i.ONE)
				original_reachable = not pathfinding.find_path_to_adjacent(
					hauler.current_tile, original_destination.tile_origin, original_footprint
				).is_empty()
			if original_reachable:
				job.status = HaulJob.Status.IN_TRANSIT
				job.blocked_reason = ""
				hauler.clear_path()
				target_inventory_id = original_destination.inventory.owner_id
				dest_inv = original_destination.inventory
			else:
				var replacement: BuildingState = _find_alternate_destination(
					hauler, job, buildings_by_inventory, pathfinding
				)
				if replacement == null:
					hauler.last_block_reason = "NO_DESTINATION_CAPACITY_OR_PATH"
					continue
				if not replacement.inventory.reserve_in(job.resource_id, hauler.carried_amount):
					continue
				# Reserve the new destination first; only then release any old reservation.
				if original_destination != null and job.reserved_amount > 0:
					original_destination.inventory.release_reserved_in(job.resource_id, job.reserved_amount)
				job.destination_inventory_id = replacement.inventory.owner_id
				job.reserved_amount = hauler.carried_amount
				job.status = HaulJob.Status.IN_TRANSIT
				job.blocked_reason = ""
				hauler.clear_path()
				target_inventory_id = job.destination_inventory_id
				dest_inv = replacement.inventory
		else:
			# A blocked job without cargo is stale; reservations are released by the
			# owner of the invalidated building/job, never by dropping carried goods.
			if job.status != HaulJob.Status.BLOCKED:
				hauler.active_job = null
				hauler.clear_path()
			else:
				hauler.last_block_reason = job.blocked_reason
			continue

		var target_building: BuildingState = buildings_by_inventory.get(target_inventory_id, null)
		if target_building == null:
			if job.status == HaulJob.Status.IN_TRANSIT and hauler.carried_amount > 0:
				# The destination disappeared. Release its reservation if the inventory
				# object is still reachable, then park the cargo until it can be rerouted.
				if dest_inv != null and job.reserved_amount > 0:
					dest_inv.release_reserved_in(job.resource_id, job.reserved_amount)
				job.reserved_amount = 0
				job.status = HaulJob.Status.BLOCKED
				job.blocked_reason = "DESTINATION_MISSING — cargo retained"
				hauler.clear_path()
			else:
				if source_inv != null or dest_inv != null:
					job_board.cancel_job(job, source_inv, dest_inv, "TARGET_BUILDING_MISSING")
				hauler.active_job = null
				hauler.clear_path()
			hauler.last_block_reason = "TARGET_BUILDING_MISSING"
			continue

		# Ensure a rerouted destination lookup is fresh in this tick.
		dest_inv = inventories_by_id.get(job.destination_inventory_id, dest_inv)
		var arrived: bool = _advance_toward(hauler, target_building, target_inventory_id, pathfinding, current_tick)
		if not arrived:
			continue

		if job.status == HaulJob.Status.ASSIGNED or job.status == HaulJob.Status.RESERVED:
			if source_inv != null and job_board.execute_pickup(job, source_inv):
				hauler.carried_resource = job.resource_id
				hauler.carried_amount = job.amount
				hauler.clear_path()
				hauler.last_block_reason = ""
				job.blocked_reason = ""
			else:
				job_board.cancel_job(job, source_inv, dest_inv, "PICKUP_FAILED")
				hauler.active_job = null
				hauler.carried_resource = &""
				hauler.carried_amount = 0
				hauler.clear_path()
		elif job.status == HaulJob.Status.IN_TRANSIT:
			if dest_inv != null and job_board.execute_delivery(job, dest_inv):
				hauler.carried_resource = &""
				hauler.carried_amount = 0
				hauler.active_job = null
				hauler.clear_path()
				hauler.last_block_reason = ""
			else:
				job.blocked_reason = "DELIVERY_BLOCKED — cargo retained"
				hauler.last_block_reason = "DELIVERY_BLOCKED"
				hauler.clear_path()
				hauler.next_path_retry_tick = current_tick + PATH_RETRY_TICKS

func _find_alternate_destination(
	hauler: Hauler,
	job: HaulJob,
	buildings_by_inventory: Dictionary,
	pathfinding: PathfindingService
) -> BuildingState:
	var candidates: Array[BuildingState] = []
	for candidate: BuildingState in buildings_by_inventory.values():
		if candidate == null or candidate.inventory.owner_id == job.destination_inventory_id:
			continue
		if candidate.is_destroyed or not candidate.inventory.accepts(job.resource_id):
			continue
		if candidate.inventory.get_free_capacity() < hauler.carried_amount:
			continue
		var definition: Dictionary = BuildingCatalog.get_all_defs().get(candidate.definition_id, {})
		var footprint: Vector2i = definition.get("footprint", Vector2i.ONE)
		var candidate_path: Array[Vector2i] = pathfinding.find_path_to_entrance(
			hauler.current_tile, candidate
		)
		if not candidate_path.is_empty():
			candidates.append(candidate)
	candidates.sort_custom(func(a: BuildingState, b: BuildingState) -> bool:
		var dist_a: int = absi(a.tile_origin.x - hauler.current_tile.x) + absi(a.tile_origin.y - hauler.current_tile.y)
		var dist_b: int = absi(b.tile_origin.x - hauler.current_tile.x) + absi(b.tile_origin.y - hauler.current_tile.y)
		return dist_a < dist_b
	)
	return candidates[0] if not candidates.is_empty() else null

func _advance_toward(
	hauler: Hauler,
	target_building: BuildingState,
	target_inventory_id: int,
	pathfinding: PathfindingService,
	current_tick: int
) -> bool:
	var needs_new_path: bool = hauler.path_target_inventory_id != target_inventory_id
	if not needs_new_path and not hauler.path.is_empty() and hauler.path_index < hauler.path.size():
		var next_cell: Vector2i = hauler.path[hauler.path_index]
		if pathfinding.astar_grid.is_point_solid(next_cell):
			needs_new_path = true
	if hauler.path.is_empty() and current_tick >= hauler.next_path_retry_tick:
		needs_new_path = true

	if needs_new_path:
		var new_path: Array[Vector2i] = pathfinding.find_path_to_entrance(
			hauler.current_tile, target_building
		)
		hauler.clear_path()
		if new_path.is_empty():
			# clear_path resets the target; restore it so the retry cooldown is respected.
			hauler.path_target_inventory_id = target_inventory_id
			hauler.last_block_reason = "NO_PATH"
			hauler.active_job.blocked_reason = "NO_PATH — waiting for a reachable route"
			hauler.next_path_retry_tick = current_tick + PATH_RETRY_TICKS
			return false
		hauler.path = new_path
		hauler.path_target_inventory_id = target_inventory_id
		hauler.path_index = 1 # Path includes the current tile; skip it.
		hauler.last_block_reason = ""
		hauler.active_job.blocked_reason = ""
		if new_path.size() == 1:
			return true

	if hauler.path_index >= hauler.path.size():
		return not hauler.path.is_empty()

	var next_tile: Vector2i = hauler.path[hauler.path_index]
	if pathfinding.astar_grid.is_point_solid(next_tile):
		hauler.clear_path()
		hauler.next_path_retry_tick = current_tick + PATH_RETRY_TICKS
		hauler.last_block_reason = "PATH_CHANGED"
		hauler.active_job.blocked_reason = "PATH_CHANGED"
		return false

	hauler.current_tile = next_tile
	hauler.path_index += 1
	return hauler.path_index >= hauler.path.size()

func get_hauler_by_id(hauler_id: int) -> Hauler:
	for hauler: Hauler in haulers:
		if hauler.id == hauler_id:
			return hauler
	return null
