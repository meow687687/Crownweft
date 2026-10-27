class_name GuidanceService
extends RefCounted

signal objective_completed(objective_id: StringName, title: String)
signal objective_updated(objective_info: Dictionary)

const OBJ_STAFF_FARM: StringName = &"obj_staff_farm"
const OBJ_PRODUCE_GRAIN: StringName = &"obj_produce_grain"
const OBJ_PLACE_BAKERY: StringName = &"obj_place_bakery"
const OBJ_CONSTRUCT_BAKERY: StringName = &"obj_construct_bakery"
const OBJ_PRODUCE_BREAD: StringName = &"obj_produce_bread"
const OBJ_PROPOSE_TRADE: StringName = &"obj_propose_trade"
const OBJ_SETTLE_TRADE: StringName = &"obj_settle_trade"

const ALL_OBJECTIVE_IDS: Array[StringName] = [
	OBJ_STAFF_FARM,
	OBJ_PRODUCE_GRAIN,
	OBJ_PLACE_BAKERY,
	OBJ_CONSTRUCT_BAKERY,
	OBJ_PRODUCE_BREAD,
	OBJ_PROPOSE_TRADE,
	OBJ_SETTLE_TRADE
]

var completed_objectives: Array[StringName] = []
var is_minimized: bool = false
var _cached_info: Dictionary = {}

func is_objective_completed(obj_id: StringName) -> bool:
	return completed_objectives.has(obj_id)

func get_current_objective_id(world) -> StringName:
	for obj_id in ALL_OBJECTIVE_IDS:
		if not completed_objectives.has(obj_id):
			return obj_id
	return &"all_completed"

func update_guidance(world, event_log = null) -> Dictionary:
	if world == null:
		return {}

	var iterations: int = 0
	var max_iterations: int = ALL_OBJECTIVE_IDS.size()
	while iterations < max_iterations:
		iterations += 1
		var cur_id: StringName = get_current_objective_id(world)
		var info: Dictionary = _evaluate_objective(cur_id, world)

		# Check if newly completed
		if cur_id != &"all_completed" and info.get("is_satisfied", false):
			completed_objectives.append(cur_id)
			var obj_title: String = info.get("title", str(cur_id))
			objective_completed.emit(cur_id, obj_title)
			if event_log != null:
				event_log.add_event(&"objective", "Objective Complete: %s" % obj_title, &"success", world.current_tick)
			# Continue loop to immediately cascade into newly satisfied subsequent objectives
		else:
			_cached_info = info
			objective_updated.emit(info)
			return info

	var final_id: StringName = get_current_objective_id(world)
	var final_info: Dictionary = _evaluate_objective(final_id, world)
	_cached_info = final_info
	objective_updated.emit(final_info)
	return final_info

func _evaluate_objective(obj_id: StringName, world) -> Dictionary:
	match obj_id:
		OBJ_STAFF_FARM:
			return _eval_staff_farm(world)
		OBJ_PRODUCE_GRAIN:
			return _eval_produce_grain(world)
		OBJ_PLACE_BAKERY:
			return _eval_place_bakery(world)
		OBJ_CONSTRUCT_BAKERY:
			return _eval_construct_bakery(world)
		OBJ_PRODUCE_BREAD:
			return _eval_produce_bread(world)
		OBJ_PROPOSE_TRADE:
			return _eval_propose_trade(world)
		OBJ_SETTLE_TRADE:
			return _eval_settle_trade(world)
		&"all_completed":
			return {
				"id": &"all_completed",
				"stage": "Playable Alpha Complete",
				"title": "Crownweft Foundation Secured",
				"explanation": "Your fields are harvested, your bakery supplies bread, and regional trade connects your realm to the world.",
				"action": "You have mastered settlement stabilization and regional integration. You may now freely expand your realm.",
				"progress_text": "7 / 7 Objectives Complete",
				"is_satisfied": true,
				"is_blocked": false,
				"blocker_reason": "",
				"all_completed": true
			}
		_:
			return {}

func _eval_staff_farm(world) -> Dictionary:
	var farm = _find_best_building(world, &"farm")
	var is_staffed: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	if farm == null:
		is_blocked = true
		blocker = "No farm detected in settlement."
	else:
		is_staffed = farm.assigned_workers >= 1
		if not is_staffed:
			var unassigned: int = _count_unassigned_citizens(world)
			if unassigned <= 0:
				is_blocked = true
				blocker = "All citizens are currently assigned to other roles. Open Workforce (W) to reassign a citizen."

	return {
		"id": OBJ_STAFF_FARM,
		"stage": "Stage A: Stabilize Settlement",
		"title": "Assign a Farmer to the Fields",
		"explanation": "Our citizens require food to avoid hunger. The settlement has a farm ready for planting, but no hands in the field.",
		"action": "Select the Farm or press 'W' (Workforce) to assign at least 1 citizen as Farmer.",
		"progress_text": "Workers: %d / 1" % (farm.assigned_workers if farm != null else 0),
		"is_satisfied": is_staffed,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_produce_grain(world) -> Dictionary:
	var target_grain: int = 6
	var total_lifetime_grain: int = 0
	for b in world.buildings:
		if b.definition_id == &"farm" and not b.is_destroyed:
			total_lifetime_grain += b.lifetime_produced.get(&"grain", 0)
	var total_grain: int = _count_settlement_resource(world, &"grain")
	var is_satisfied: bool = (total_lifetime_grain >= target_grain) or (total_grain >= target_grain)
	var is_blocked: bool = false
	var blocker: String = ""

	var farm = _find_best_building(world, &"farm")
	if not is_satisfied:
		if farm == null or farm.assigned_workers == 0:
			is_blocked = true
			blocker = "The farm has no workers assigned. Assign a farmer in Workforce (W)."
		elif farm.current_block_reason != &"":
			if farm.current_block_reason == &"NO_WORKERS":
				var diag: Dictionary = _diagnose_building_workers(world, farm, "Farmer")
				if diag.get("has_assigned", false):
					is_blocked = false
					blocker = diag.get("status_note", "Worker resting or commuting")
				else:
					is_blocked = true
					blocker = "Farm is unstaffed. Assign a farmer in Workforce (W)."
			else:
				is_blocked = true
				blocker = "Farm is blocked: %s" % str(farm.current_block_reason)

	return {
		"id": OBJ_PRODUCE_GRAIN,
		"stage": "Stage A: Stabilize Settlement",
		"title": "Harvest the First Grain Crop",
		"explanation": "With the farmer tending the crop, raw grain will accumulate in the farm inventory.",
		"action": "Run the simulation (1x/2x/3x speed) until the farm produces at least 6 grain.",
		"progress_text": "Grain: %d / %d" % [maxi(total_lifetime_grain, total_grain), target_grain],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_place_bakery(world) -> Dictionary:
	var bakery = _find_best_building(world, &"bakery")
	var is_placed: bool = bakery != null
	var is_blocked: bool = false
	var blocker: String = ""

	var timber: int = _count_settlement_resource(world, &"timber")
	var stone: int = _count_settlement_resource(world, &"stone")
	if not is_placed:
		if timber < 4 or stone < 4:
			is_blocked = true
			blocker = "Shortage of building supplies (Need: 4 Timber, 4 Stone. Have: %d Timber, %d Stone). Construct a Woodcutter Camp to replenish." % [timber, stone]

	return {
		"id": OBJ_PLACE_BAKERY,
		"stage": "Stage B: Expand Production",
		"title": "Commission a Bakery",
		"explanation": "Raw grain cannot be eaten directly by citizens. A Bakery is needed to mill and bake grain into hearty bread.",
		"action": "Click BAKERY in the build menu at the bottom (cost: 4 Timber, 4 Stone) and place it near the Town Hall.",
		"progress_text": "Bakery Placed: %s" % ("YES" if is_placed else "NO"),
		"is_satisfied": is_placed,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_construct_bakery(world) -> Dictionary:
	var bakery = _find_best_building(world, &"bakery")
	var is_active: bool = false
	var is_blocked: bool = false
	var blocker: String = ""
	var progress_pct: int = 0

	if bakery == null:
		is_blocked = true
		blocker = "Bakery has not been placed yet."
	else:
		is_active = (bakery.status == BuildingState.Status.ACTIVE)
		progress_pct = int(bakery.construction_progress * 100.0)
		if not is_active:
			if bakery.construction_block_reason != &"":
				is_blocked = true
				blocker = "Construction blocked: %s" % str(bakery.construction_block_reason)
			elif bakery.construction_inventory != null and not bakery.has_all_construction_materials():
				var needed_timber = maxi(0, 4 - bakery.construction_inventory.get_quantity(&"timber"))
				var needed_stone = maxi(0, 4 - bakery.construction_inventory.get_quantity(&"stone"))
				if needed_timber > 0 or needed_stone > 0:
					var total_timber = _count_settlement_resource(world, &"timber")
					var total_stone = _count_settlement_resource(world, &"stone")
					if total_timber < needed_timber or total_stone < needed_stone:
						is_blocked = true
						blocker = "Material shortage: Need %d Timber, %d Stone. Construct Woodcutter Camp or quarry." % [needed_timber, needed_stone]
					else:
						is_blocked = false
						blocker = "Awaiting materials: %d Timber, %d Stone in transit by haulers." % [needed_timber, needed_stone]

	return {
		"id": OBJ_CONSTRUCT_BAKERY,
		"stage": "Stage B: Expand Production",
		"title": "Deliver Materials & Complete Bakery",
		"explanation": "Dedicated haulers are transporting timber and stone to the site. Once materials arrive, construction will finish.",
		"action": "Ensure haulers can reach the site. Allow time for material delivery and construction completion.",
		"progress_text": "Construction: %d%%" % progress_pct,
		"is_satisfied": is_active,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_produce_bread(world) -> Dictionary:
	var bakery = _find_best_building(world, &"bakery")
	var is_staffed: bool = false
	var total_bread: int = _count_settlement_resource(world, &"bread")
	var is_satisfied: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	var total_lifetime_bread: int = 0
	for b in world.buildings:
		if b.definition_id == &"bakery" and not b.is_destroyed:
			total_lifetime_bread += b.lifetime_produced.get(&"bread", 0)
	var bakery_stock: int = 0
	for b in world.buildings:
		if b.definition_id == &"bakery" and not b.is_destroyed:
			bakery_stock += b.inventory.get_quantity(&"bread")

	if bakery == null or bakery.status != BuildingState.Status.ACTIVE:
		is_blocked = true
		blocker = "Bakery is not yet active."
	else:
		is_staffed = bakery.assigned_workers >= 1
		var grain_avail: int = _count_settlement_resource(world, &"grain")

		if is_staffed and (total_lifetime_bread >= 1 or bakery_stock >= 1 or total_bread >= 30):
			is_satisfied = true

		if not is_satisfied:
			if not is_staffed:
				is_blocked = true
				blocker = "No baker assigned to Bakery. Open Workforce (W) to assign worker."
			elif grain_avail < 2 and bakery.inventory.get_quantity(&"grain") < 2:
				is_blocked = true
				blocker = "No grain available for baking. Ensure Farm is producing grain."
			elif bakery.current_block_reason != &"":
				if bakery.current_block_reason == &"NO_WORKERS":
					var diag: Dictionary = _diagnose_building_workers(world, bakery, "Baker")
					if diag.get("has_assigned", false):
						is_blocked = false
						blocker = diag.get("status_note", "Baker resting or commuting")
					else:
						is_blocked = true
						blocker = "No baker present at Bakery."
				else:
					is_blocked = true
					blocker = "Bakery blocked: %s" % str(bakery.current_block_reason)

	return {
		"id": OBJ_PRODUCE_BREAD,
		"stage": "Stage B: Expand Production",
		"title": "Staff Bakery & Bake Bread",
		"explanation": "The oven is built and ready. Assign a Baker to begin transforming harvested grain into fresh bread.",
		"action": "Assign 1 Baker to the active Bakery and allow them to bake bread.",
		"progress_text": "Workers: %d / 1  |  Bread: %d" % [bakery.assigned_workers if bakery != null else 0, maxi(total_bread, total_lifetime_bread)],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_propose_trade(world) -> Dictionary:
	var reg_world = world.regional_world
	var has_contract: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	if reg_world == null:
		is_blocked = true
		blocker = "Regional world not initialized."
	else:
		for c in reg_world.contracts.values():
			if (c.buyer_faction_id == FactionCatalog.FACTION_VALEN or c.seller_faction_id == FactionCatalog.FACTION_VALEN):
				if c.status in [TradeContract.STATUS_ACCEPTED, TradeContract.STATUS_RESERVED, TradeContract.STATUS_IN_TRANSIT, TradeContract.STATUS_DELIVERED, TradeContract.STATUS_SETTLED]:
					has_contract = true
					break

		if not has_contract:
			var route = reg_world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN)
			if route != null and not route.is_open:
				is_blocked = true
				blocker = "Route to Valen Lowlands is currently closed or blocked."
			else:
				var main_inv: Inventory = world.buildings[0].inventory if not world.buildings.is_empty() else null
				var town_hall_grain: int = main_inv.get_quantity(&"grain") if main_inv != null else 0
				var total_grain: int = _count_settlement_resource(world, &"grain")
				if town_hall_grain < 10:
					if total_grain >= 10:
						blocker = "Grain in transit: %d / 10 Grain in Town Hall (Haulers moving grain from farm)." % town_hall_grain
					else:
						blocker = "Awaiting trade stock: %d / 10 Grain in Town Hall." % town_hall_grain

	var main_inv: Inventory = world.buildings[0].inventory if not world.buildings.is_empty() else null
	var th_grain: int = main_inv.get_quantity(&"grain") if main_inv != null else 0
	var progress_str: String = "Trade Agreement: ACCEPTED" if has_contract else ("Storage: %d / 10 Grain in Town Hall" % th_grain)

	return {
		"id": OBJ_PROPOSE_TRADE,
		"stage": "Stage C: Realm-Level Decision",
		"title": "Establish Regional Trade with Valen",
		"explanation": "Our local food chain is functioning. The realm beyond Crownweft offers trade with the Valen Trade Compact.",
		"action": "Ensure 10 Grain is stocked in Town Hall, then press 'D' (Diplomacy) to accept Valen's trade offer.",
		"progress_text": progress_str,
		"is_satisfied": has_contract,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_settle_trade(world) -> Dictionary:
	var reg_world = world.regional_world
	var is_settled: bool = false
	var in_transit: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	if reg_world != null:
		for c in reg_world.contracts.values():
			if (c.buyer_faction_id == FactionCatalog.FACTION_VALEN or c.seller_faction_id == FactionCatalog.FACTION_VALEN):
				if c.status in [TradeContract.STATUS_SETTLED, TradeContract.STATUS_DELIVERED]:
					is_settled = true
					break
				elif c.status in [TradeContract.STATUS_IN_TRANSIT, TradeContract.STATUS_RESERVED, TradeContract.STATUS_ACCEPTED]:
					in_transit = true

		if not is_settled and not in_transit:
			is_blocked = true
			blocker = "No active trade shipment en route."

	return {
		"id": OBJ_SETTLE_TRADE,
		"stage": "Stage C: Realm-Level Decision",
		"title": "Deliver Cargo & Collect Payment",
		"explanation": "A trade caravan is carrying regional cargo along the route to Valen Lowlands.",
		"action": "Monitor caravan progress on the World Map (M) until the contract is delivered and settled.",
		"progress_text": "Caravan Status: %s" % ("SETTLED" if is_settled else ("IN TRANSIT" if in_transit else "PENDING")),
		"is_satisfied": is_settled,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

# Helper queries
func _find_best_building(world, def_id: StringName):
	if world == null or not ("buildings" in world):
		return null
	var candidates: Array = []
	for b in world.buildings:
		if b.definition_id == def_id and not b.is_destroyed:
			candidates.append(b)
	if candidates.is_empty():
		return null
	var best = candidates[0]
	var best_score: int = -1
	for b in candidates:
		var score: int = 0
		if b.status == BuildingState.Status.ACTIVE:
			score += 10
		if b.assigned_workers > 0:
			score += 5
		if b.lifetime_produced.size() > 0:
			score += 2
		if score > best_score:
			best_score = score
			best = b
	return best

func _find_first_building(world, def_id: StringName):
	return _find_best_building(world, def_id)

func _diagnose_building_workers(world, building: BuildingState, worker_role_label: String = "Worker") -> Dictionary:
	if world == null or building == null or not ("citizens" in world):
		return {"has_assigned": false, "status_note": ""}
	var assigned: Array = []
	for c in world.citizens:
		if c.workplace_id == building.entity_id and c.role_id != &"hauler":
			assigned.append(c)
	if assigned.is_empty():
		return {"has_assigned": false, "status_note": ""}

	var all_resting: bool = true
	var all_moving: bool = true
	for c in assigned:
		if not c.is_resting:
			all_resting = false
		if c.move_state != CitizenState.MoveState.MOVING:
			all_moving = false

	var note: String = ""
	if all_resting:
		note = "%s is resting; production will resume upon wake." % worker_role_label
	elif all_moving:
		note = "%s is commuting to workplace." % worker_role_label
	else:
		note = "%s is active or transitioning." % worker_role_label

	return {
		"has_assigned": true,
		"all_resting": all_resting,
		"all_moving": all_moving,
		"status_note": note
	}

func _count_unassigned_citizens(world) -> int:
	var count: int = 0
	for c in world.citizens:
		if c.role_id == &"unassigned" and c.workplace_id <= 0:
			count += 1
	return count

func _count_settlement_resource(world, res_id: StringName) -> int:
	var total: int = 0
	for b in world.buildings:
		if not b.is_destroyed:
			total += b.inventory.get_quantity(res_id)
	return total

func serialize() -> Dictionary:
	var copy: Array = []
	for id in completed_objectives:
		copy.append(str(id))
	return {
		"completed_objectives": copy,
		"is_minimized": is_minimized
	}

func deserialize(data: Dictionary) -> void:
	completed_objectives.clear()
	var raw_completed = data.get("completed_objectives", [])
	if raw_completed is Array:
		for id in raw_completed:
			completed_objectives.append(StringName(id))
	is_minimized = bool(data.get("is_minimized", false))
