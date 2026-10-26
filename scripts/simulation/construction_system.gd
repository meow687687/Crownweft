class_name ConstructionSystem
extends RefCounted

signal building_completed(building: BuildingState)
signal construction_blocked(building: BuildingState, reason: StringName)

const DEFAULT_BUILD_TICKS: int = 8

func create_construction_site(
	entity_id: int,
	def_id: StringName,
	origin: Vector2i,
	cost: Dictionary,
	build_time: int,
	construction_inv_id: int,
	operational_capacity: int = 30,
	operational_accepted: Array = []
) -> BuildingState:
	var b := BuildingState.new(entity_id, def_id, operational_capacity, operational_accepted)
	b.tile_origin = origin
	b.status = BuildingState.Status.PLANNED
	b.construction_progress = 0.0
	b.construction_ticks = 0
	b.construction_required_ticks = build_time if build_time > 0 else DEFAULT_BUILD_TICKS
	b.construction_cost = cost.duplicate()
	b.construction_block_reason = &"WAITING_FOR_MATERIALS"
	
	var total_cost: int = 0
	for res_id in cost:
		total_cost += cost[res_id]
	var inv_cap: int = maxi(20, total_cost * 2)
	b.construction_inventory = Inventory.new(construction_inv_id, inv_cap, cost.keys())
	return b

func tick_building(building: BuildingState, workers_present: int, current_tick: int) -> void:
	if building == null or building.is_destroyed:
		return
	if building.status == BuildingState.Status.ACTIVE:
		return
		
	# 1. Verify materials
	if not building.has_all_construction_materials():
		building.status = BuildingState.Status.PLANNED
		var missing := building.get_outstanding_materials()
		var reason_str: String = "WAITING_FOR_MATERIALS"
		building.construction_block_reason = StringName(reason_str)
		construction_blocked.emit(building, building.construction_block_reason)
		return
		
	# 2. Materials are present: site is actively ready for construction labor
	building.status = BuildingState.Status.UNDER_CONSTRUCTION
	
	if workers_present <= 0:
		building.construction_block_reason = &"NO_BUILDERS"
		construction_blocked.emit(building, &"NO_BUILDERS")
		return
		
	building.construction_block_reason = &""
	
	# 3. Advance construction progress through explicit simulation ticks
	var labor_advance: int = mini(workers_present, 4)
	building.construction_ticks += labor_advance
	building.construction_progress = clampf(
		float(building.construction_ticks) / float(maxi(1, building.construction_required_ticks)),
		0.0,
		1.0
	)
	
	# 4. Check for completion
	if building.construction_ticks >= building.construction_required_ticks:
		complete_construction(building)

func complete_construction(building: BuildingState) -> void:
	if building == null or building.status == BuildingState.Status.ACTIVE:
		return
		
	# Consume construction materials from the dedicated construction inventory
	if building.construction_inventory != null:
		for res_id: StringName in building.construction_cost:
			var req: int = building.construction_cost[res_id]
			building.construction_inventory.remove_resource(res_id, req, "CONSTRUCTION_SPENT", false)
			
	building.status = BuildingState.Status.ACTIVE
	building.construction_progress = 1.0
	building.construction_ticks = building.construction_required_ticks
	building.construction_block_reason = &""
	building_completed.emit(building)

func cancel_construction_site(
	building: BuildingState,
	job_board: JobBoard,
	refund_inventory: Inventory,
	inventories_by_id: Dictionary,
	fallback_inventories: Array[Inventory] = []
) -> Dictionary:
	var refund_summary: Dictionary = {}
	if building == null:
		return refund_summary
		
	# 1. Invalidate or reroute any in-flight / pending haul jobs targeting this construction inventory
	var const_inv_id: int = building.construction_inventory.owner_id if building.construction_inventory != null else -1
	if job_board != null and const_inv_id > 0:
		for job: HaulJob in job_board.jobs.values():
			if job.destination_inventory_id != const_inv_id:
				continue
			if job.status in [HaulJob.Status.DELIVERED, HaulJob.Status.CANCELLED]:
				continue
				
			var src_inv: Inventory = inventories_by_id.get(job.source_inventory_id, null)
			var dst_inv: Inventory = building.construction_inventory
			
			if job.status == HaulJob.Status.IN_TRANSIT:
				# Cargo already picked up: do not destroy it! Release destination reservation and clear destination for rerouting
				if dst_inv != null and job.reserved_amount > 0:
					dst_inv.release_reserved_in(job.resource_id, job.reserved_amount)
				job.destination_inventory_id = -1
				job.reserved_amount = 0
				job.status = HaulJob.Status.BLOCKED
				job.blocked_reason = "CONSTRUCTION_CANCELLED_CARGO_REROUTED"
			else:
				# Pre-pickup: cancel job and release source/destination reservations cleanly
				job_board.cancel_job(job, src_inv, dst_inv, "CONSTRUCTION_CANCELLED")
				
	# 2. Refund delivered materials to refund_inventory (Town Hall), fallback storages, or an explicit ground pile
	if building.construction_inventory != null:
		var candidate_inventories: Array[Inventory] = []
		if refund_inventory != null:
			candidate_inventories.append(refund_inventory)
		for fb_inv: Inventory in fallback_inventories:
			if fb_inv != null and fb_inv != refund_inventory and not fb_inv in candidate_inventories:
				candidate_inventories.append(fb_inv)
				
		for res_id: StringName in building.construction_inventory.quantities.keys():
			var rem_qty: int = building.construction_inventory.get_quantity(res_id)
			if rem_qty <= 0:
				continue
				
			var total_refunded_for_res: int = 0
			# Step 2a: Try refunding into candidate inventories
			for target_inv: Inventory in candidate_inventories:
				if rem_qty <= 0:
					break
				if not target_inv.accepts(res_id):
					continue
				var free_cap: int = target_inv.get_free_capacity()
				if free_cap <= 0:
					continue
				var transfer: int = mini(rem_qty, free_cap)
				target_inv.add_resource(res_id, transfer, "CONSTRUCTION_SALVAGE", false)
				building.construction_inventory.remove_resource(res_id, transfer, "CONSTRUCTION_SALVAGE", false)
				rem_qty -= transfer
				total_refunded_for_res += transfer
				
			# Step 2b: Overflow handling: if storages are full, preserve 100% of resources in an explicit ground pile
			if rem_qty > 0:
				var ground_pile: Inventory = refund_summary.get("ground_pile", null)
				if ground_pile == null:
					var pile_id: int = building.entity_id + 90000
					ground_pile = Inventory.new(pile_id, 500, [])
					refund_summary["ground_pile"] = ground_pile
				ground_pile.add_resource(res_id, rem_qty, "CONSTRUCTION_SALVAGE_OVERFLOW_GROUND_PILE", false)
				building.construction_inventory.remove_resource(res_id, rem_qty, "CONSTRUCTION_SALVAGE_OVERFLOW_GROUND_PILE", false)
				total_refunded_for_res += rem_qty
				rem_qty = 0
				
			if total_refunded_for_res > 0:
				refund_summary[res_id] = total_refunded_for_res
					
	building.status = BuildingState.Status.DESTROYED
	building.is_destroyed = true
	return refund_summary
