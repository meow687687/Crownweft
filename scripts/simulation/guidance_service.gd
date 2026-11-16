class_name GuidanceService
extends RefCounted

const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")

signal objective_completed(objective_id: StringName, title: String)
signal objective_updated(objective_info: Dictionary)

# Scenario A: Founding Objectives
const OBJ_STAFF_FARM: StringName = &"obj_staff_farm"
const OBJ_PRODUCE_GRAIN: StringName = &"obj_produce_grain"
const OBJ_PLACE_BAKERY: StringName = &"obj_place_bakery"
const OBJ_CONSTRUCT_BAKERY: StringName = &"obj_construct_bakery"
const OBJ_PRODUCE_BREAD: StringName = &"obj_produce_bread"
const OBJ_PROPOSE_TRADE: StringName = &"obj_propose_trade"
const OBJ_SETTLE_TRADE: StringName = &"obj_settle_trade"

# Scenario B: Border March Objectives
const OBJ_STAFF_GARRISON: StringName = &"obj_staff_garrison"
const OBJ_STOCK_RATIONS: StringName = &"obj_stock_rations"
const OBJ_RESUPPLY_ARMY: StringName = &"obj_resupply_army"
const OBJ_PATROL_FRONTIER: StringName = &"obj_patrol_frontier"
const OBJ_SECURE_FRONTIER: StringName = &"obj_secure_frontier"

# Scenario C: Merchant's Crossroads Objectives
const OBJ_INSPECT_STOREHOUSE: StringName = &"obj_inspect_storehouse"
const OBJ_PRODUCE_SURPLUS: StringName = &"obj_produce_surplus"
const OBJ_RATIFY_VALEN_EXPORT: StringName = &"obj_ratify_valen_export"
const OBJ_DISPATCH_COMMUNAL_TRADE: StringName = &"obj_dispatch_communal_trade"
const OBJ_SETTLE_MERCHANT_EMPORIUM: StringName = &"obj_settle_merchant_emporium"

const ALL_OBJECTIVE_IDS: Array[StringName] = [
	OBJ_STAFF_FARM,
	OBJ_PRODUCE_GRAIN,
	OBJ_PLACE_BAKERY,
	OBJ_CONSTRUCT_BAKERY,
	OBJ_PRODUCE_BREAD,
	OBJ_PROPOSE_TRADE,
	OBJ_SETTLE_TRADE
]

var current_scenario_id: StringName = &"crownweft_founding"
var active_objective_ids: Array[StringName] = []
var completed_objectives: Array[StringName] = []
var is_minimized: bool = false
var _cached_info: Dictionary = {}

func setup_for_scenario(scenario_id: StringName) -> void:
	current_scenario_id = scenario_id
	var def: Dictionary = ScenarioCatalog.get_scenario_def(scenario_id)
	active_objective_ids.clear()
	var raw_objs = def.get("objectives", [])
	for obj_id in raw_objs:
		active_objective_ids.append(StringName(obj_id))
	completed_objectives.clear()
	_cached_info = {}

func get_objective_list() -> Array[StringName]:
	if not active_objective_ids.is_empty():
		return active_objective_ids
	return ALL_OBJECTIVE_IDS

func is_objective_completed(obj_id: StringName) -> bool:
	return completed_objectives.has(obj_id)

func get_current_objective_id(world) -> StringName:
	var list: Array[StringName] = get_objective_list()
	for obj_id in list:
		if not completed_objectives.has(obj_id):
			return obj_id
	return &"all_completed"

func update_guidance(world, event_log = null) -> Dictionary:
	if world == null:
		return {}

	var iterations: int = 0
	var max_iterations: int = maxi(1, get_objective_list().size())
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
		# Scenario A: Founding
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

		# Scenario B: Border March
		OBJ_STAFF_GARRISON:
			return _eval_staff_garrison(world)
		OBJ_STOCK_RATIONS:
			return _eval_stock_rations(world)
		OBJ_RESUPPLY_ARMY:
			return _eval_resupply_army(world)
		OBJ_PATROL_FRONTIER:
			return _eval_patrol_frontier(world)
		OBJ_SECURE_FRONTIER:
			return _eval_secure_frontier(world)

		# Scenario C: Merchant's Crossroads
		OBJ_INSPECT_STOREHOUSE:
			return _eval_inspect_storehouse(world)
		OBJ_PRODUCE_SURPLUS:
			return _eval_produce_surplus(world)
		OBJ_RATIFY_VALEN_EXPORT:
			return _eval_ratify_valen_export(world)
		OBJ_DISPATCH_COMMUNAL_TRADE:
			return _eval_dispatch_communal_trade(world)
		OBJ_SETTLE_MERCHANT_EMPORIUM:
			return _eval_settle_merchant_emporium(world)

		&"all_completed":
			match current_scenario_id:
				ScenarioCatalog.SCENARIO_BORDER_MARCH:
					return {
						"id": &"all_completed",
						"stage": "Scenario Complete",
						"title": "Frontier Secured",
						"explanation": "Your garrison is standing guard, the Royal Crown Guard is resupplied, and the borderlands are secure.",
						"action": "The border march is fortified against all threats. You may continue commanding forces and developing your stronghold.",
						"progress_text": "%d / %d Objectives Complete" % [completed_objectives.size(), get_objective_list().size()],
						"is_satisfied": true,
						"is_blocked": false,
						"blocker_reason": "",
						"all_completed": true
					}
				ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS:
					return {
						"id": &"all_completed",
						"stage": "Scenario Complete",
						"title": "Merchant Emporium Flourishing",
						"explanation": "High-capacity warehouses, coordinated haulers, and thriving regional trade have made your crossroads a renowned commercial hub.",
						"action": "Your trade emporium commands unmatched wealth. You may continue signing contracts and expanding across the realm.",
						"progress_text": "%d / %d Objectives Complete" % [completed_objectives.size(), get_objective_list().size()],
						"is_satisfied": true,
						"is_blocked": false,
						"blocker_reason": "",
						"all_completed": true
					}
				_:
					return {
						"id": &"all_completed",
						"stage": "Playable Alpha Complete",
						"title": "Crownweft Foundation Secured",
						"explanation": "Your fields are harvested, your bakery supplies bread, and regional trade connects your realm to the world.",
						"action": "You have mastered settlement stabilization and regional integration. You may now freely expand your realm.",
						"progress_text": "%d / %d Objectives Complete" % [completed_objectives.size(), get_objective_list().size()],
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
		"action": "Select the Farm or press 'P' (Workforce) to assign at least 1 citizen as Farmer.",
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
		"action": "Ensure 10 Grain is stocked in Town Hall, then press 'F' (Diplomacy) to accept Valen's trade offer.",
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

# ------------------------------------------------------------------------------
# Scenario B: Border March Evaluations
# ------------------------------------------------------------------------------
func _eval_staff_garrison(world) -> Dictionary:
	var garrison_count: int = world.military_units.size() if ("military_units" in world) else 0
	var target_garrison: int = 3
	var is_satisfied: bool = garrison_count >= target_garrison
	var is_blocked: bool = false
	var blocker: String = ""

	var barracks = _find_best_building(world, &"barracks")
	if barracks == null or barracks.status != BuildingState.Status.ACTIVE:
		is_blocked = true
		blocker = "Active Barracks required to recruit and house local garrison."
	elif not is_satisfied:
		var th = world.buildings[0] if not world.buildings.is_empty() else null
		var coins = th.inventory.get_quantity(&"coin") if th != null else 0
		if coins < 20:
			is_blocked = true
			blocker = "Need 20 Coin in Town Hall to recruit militia troops (Have: %d Coin)." % coins

	return {
		"id": OBJ_STAFF_GARRISON,
		"stage": "Stage 1: Frontier Readiness",
		"title": "Muster Frontier Garrison",
		"explanation": "The border march sits along dangerous passes. Train and station at least 2 military units in local defense.",
		"action": "Select the Barracks or use recruitment controls (cost: 20 Coin) to muster garrison troops.",
		"progress_text": "Garrison: %d / %d Troops" % [garrison_count, target_garrison],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_stock_rations(world) -> Dictionary:
	var th = world.buildings[0] if not world.buildings.is_empty() else null
	var th_bread: int = th.inventory.get_quantity(&"bread") if th != null else 0
	var target_bread: int = 20
	var is_satisfied: bool = th_bread >= target_bread
	var is_blocked: bool = false
	var blocker: String = ""

	if not is_satisfied:
		var total_bread = _count_settlement_resource(world, &"bread")
		if total_bread >= target_bread:
			blocker = "Haulers transferring bread to Town Hall: %d / %d Bread stocked." % [th_bread, target_bread]
		else:
			var total_grain = _count_settlement_resource(world, &"grain")
			if total_grain < 2:
				blocker = "Awaiting grain harvest. Ensure Farm is producing grain."

	return {
		"id": OBJ_STOCK_RATIONS,
		"stage": "Stage 2: Army Logistics",
		"title": "Stockpile Campaign Rations",
		"explanation": "Marching armies consume physical bread each travel segment. Stockpile rations in Town Hall for military resupply.",
		"action": "Ensure the Farm produces grain and Bakery supplies bread until Town Hall holds 15 Bread.",
		"progress_text": "Rations: %d / %d Bread" % [th_bread, target_bread],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_resupply_army(world) -> Dictionary:
	var reg_world = world.regional_world
	var army: ArmyState = null
	if reg_world != null:
		for a in reg_world.armies.values():
			if a.faction_id == FactionCatalog.FACTION_PLAYER:
				army = a
				break

	var current_supply: float = army.get_supplies(&"grain") if army != null else 0.0
	var target_supply: float = 35.0
	var is_satisfied: bool = current_supply >= target_supply
	var is_blocked: bool = false
	var blocker: String = ""

	if army == null:
		is_blocked = true
		blocker = "No provincial army detected in regional command."
	elif not is_satisfied:
		if army.current_region_id != RegionCatalog.REGION_CROWNWEFT:
			is_blocked = true
			blocker = "Army must return to Crownweft Valley to receive supplies from local stores."
		else:
			var th = world.buildings[0] if not world.buildings.is_empty() else null
			var th_bread = th.inventory.get_quantity(&"bread") if th != null else 0
			if th_bread < 5:
				is_blocked = true
				blocker = "Insufficient bread in Town Hall for resupply (need at least 5 bread)."

	return {
		"id": OBJ_RESUPPLY_ARMY,
		"stage": "Stage 2: Army Logistics",
		"title": "Resupply Royal Crown Guard",
		"explanation": "The Royal Crown Guard is stationed in Crownweft Valley with depleted supplies. Execute an army resupply order to load food rations.",
		"action": "Open World Map (M), select the Royal Crown Guard, and click 'Resupply' to load 20 rations from Town Hall.",
		"progress_text": "Army Supplies: %.0f / %.0f" % [current_supply, target_supply],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_patrol_frontier(world) -> Dictionary:
	var reg_world = world.regional_world
	var army: ArmyState = null
	if reg_world != null:
		for a in reg_world.armies.values():
			if a.faction_id == FactionCatalog.FACTION_PLAYER:
				army = a
				break

	var is_satisfied: bool = false
	var is_blocked: bool = false
	var blocker: String = ""
	var loc_str: String = "Unknown"

	if army == null:
		is_blocked = true
		blocker = "No provincial army detected."
	else:
		loc_str = str(army.current_region_id)
		var dest = army.destination_region_id
		var frontier_regions = [RegionCatalog.REGION_SHATTERED_PASS, RegionCatalog.REGION_GREY_MARCHES]
		if army.current_region_id in frontier_regions or dest in frontier_regions:
			is_satisfied = true
		else:
			if army.get_supplies(&"grain") <= 10.0:
				is_blocked = true
				blocker = "Army supplies too low to safely march. Resupply before departure."

	return {
		"id": OBJ_PATROL_FRONTIER,
		"stage": "Stage 3: Frontier Deployment",
		"title": "Patrol the Mountain Pass",
		"explanation": "Ironpeak warbands threaten the high passes. Dispatch the Royal Crown Guard along the route to Shattered Pass or Grey Marches.",
		"action": "Open World Map (M), select the Royal Crown Guard, and click Shattered Pass to order a military march.",
		"progress_text": "Deployment: %s" % ("ON FRONTIER" if is_satisfied else ("Location: %s" % loc_str)),
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_secure_frontier(world) -> Dictionary:
	var reg_world = world.regional_world
	var dip = world.diplomacy
	var is_satisfied: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	if reg_world != null and dip != null:
		var rel = dip.get_relationship(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_IRONPEAK)
		var iron_army: ArmyState = null
		var crown_guard: ArmyState = null
		for a in reg_world.armies.values():
			if a.faction_id == FactionCatalog.FACTION_IRONPEAK:
				iron_army = a
			elif a.faction_id == FactionCatalog.FACTION_PLAYER:
				crown_guard = a

		# Condition 1: Player maintains strong garrison at frontier
		var at_frontier = crown_guard != null and crown_guard.current_region_id in [RegionCatalog.REGION_SHATTERED_PASS, RegionCatalog.REGION_GREY_MARCHES] and crown_guard.strength >= 10
		# Condition 2: Won battle engagement / war resolved / ceasefire active
		var has_ceasefire: bool = false
		for w in dip.active_wars:
			if (w.initiating_faction == FactionCatalog.FACTION_IRONPEAK or w.target_faction == FactionCatalog.FACTION_IRONPEAK) and w.status == WarState.STATUS_CEASEFIRE:
				has_ceasefire = true
				break
		var war_resolved = dip.war_history.size() > 0 or has_ceasefire
		# Condition 3: Diplomatic equilibrium / reduced threat
		var diplomatic_truce = rel != null and rel.threat <= 40.0

		if at_frontier or war_resolved or diplomatic_truce:
			is_satisfied = true

	return {
		"id": OBJ_SECURE_FRONTIER,
		"stage": "Stage 3: Frontier Deployment",
		"title": "Secure the Border Realm",
		"explanation": "Establish security through armed deterrence, repelling raiders, or negotiating a truce with Ironpeak Clans.",
		"action": "Station forces at Shattered Pass, defeat hostile incursions, or use Diplomacy (D) to negotiate security.",
		"progress_text": "Frontier Status: %s" % ("SECURED" if is_satisfied else "CONTESTED"),
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

# ------------------------------------------------------------------------------
# Scenario C: Merchant's Crossroads Evaluations
# ------------------------------------------------------------------------------
func _eval_inspect_storehouse(world) -> Dictionary:
	var sh = _find_best_building(world, &"storehouse")
	var is_active: bool = sh != null and sh.status == BuildingState.Status.ACTIVE
	var hauler_count: int = 0
	for c in world.citizens:
		if c.role_id == &"hauler":
			hauler_count += 1

	var target_haulers: int = 4
	var is_satisfied: bool = is_active and (hauler_count >= target_haulers)
	var is_blocked: bool = false
	var blocker: String = ""

	if not is_active:
		is_blocked = true
		blocker = "Storehouse must be constructed and active."
	elif hauler_count < target_haulers:
		var unassigned = _count_unassigned_citizens(world)
		if unassigned <= 0:
			blocker = "Open Workforce (W) and reassign citizens to Hauler role (Need 4 Haulers)."

	return {
		"id": OBJ_INSPECT_STOREHOUSE,
		"stage": "Stage 1: Commercial Logistics",
		"title": "Establish High-Capacity Logistics",
		"explanation": "A merchant entrepôt requires robust logistics. Maintain an active Storehouse and 4 dedicated haulers to move goods.",
		"action": "Ensure Storehouse is active and assign 4 citizens as dedicated Haulers in Workforce (W).",
		"progress_text": "Haulers: %d / %d  |  Storehouse: %s" % [hauler_count, target_haulers, "ACTIVE" if is_active else "INACTIVE"],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_produce_surplus(world) -> Dictionary:
	var grain: int = _count_settlement_resource(world, &"grain")
	var timber: int = _count_settlement_resource(world, &"timber")
	var target_grain: int = 20
	var target_timber: int = 15
	var is_satisfied: bool = (grain >= target_grain) and (timber >= target_timber)
	var is_blocked: bool = false
	var blocker: String = ""

	if not is_satisfied:
		if grain < target_grain:
			var farm = _find_best_building(world, &"farm")
			if farm == null or farm.assigned_workers == 0:
				blocker = "Assign a farmer to harvest grain surplus."
		elif timber < target_timber:
			var wc = _find_best_building(world, &"woodcutter")
			if wc == null:
				blocker = "Construct a Woodcutter Camp to accumulate timber."

	return {
		"id": OBJ_PRODUCE_SURPLUS,
		"stage": "Stage 1: Commercial Logistics",
		"title": "Amass Export Surplus",
		"explanation": "Regional merchants demand grain and timber. Build up stockpiles to supply outgoing trade caravans.",
		"action": "Harvest fields and produce timber until settlement holds at least 20 Grain and 15 Timber.",
		"progress_text": "Grain: %d / %d  |  Timber: %d / %d" % [grain, target_grain, timber, target_timber],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_ratify_valen_export(world) -> Dictionary:
	var reg_world = world.regional_world
	var has_contract: bool = false
	var is_blocked: bool = false
	var blocker: String = ""

	if reg_world != null:
		for c in reg_world.contracts.values():
			if (c.buyer_faction_id == FactionCatalog.FACTION_VALEN or c.seller_faction_id == FactionCatalog.FACTION_VALEN):
				if c.status in [TradeContract.STATUS_ACCEPTED, TradeContract.STATUS_RESERVED, TradeContract.STATUS_IN_TRANSIT, TradeContract.STATUS_DELIVERED, TradeContract.STATUS_SETTLED]:
					has_contract = true
					break

		if not has_contract:
			var route = reg_world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN)
			if route != null and not route.is_open:
				is_blocked = true
				blocker = "Trade route to Valen Lowlands is blocked."

	return {
		"id": OBJ_RATIFY_VALEN_EXPORT,
		"stage": "Stage 2: Regional Trade Contracts",
		"title": "Ratify Valen Export Treaty",
		"explanation": "Port Valen offers premium coin for our agricultural surplus. Accept their trade proposal or dispatch a trade convoy.",
		"action": "Open Diplomacy (D) to accept Valen's trade proposal and dispatch an export caravan.",
		"progress_text": "Valen Contract: %s" % ("RATIFIED" if has_contract else "PENDING"),
		"is_satisfied": has_contract,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_dispatch_communal_trade(world) -> Dictionary:
	var reg_world = world.regional_world
	var active_contracts: int = 0
	var is_blocked: bool = false
	var blocker: String = ""

	if reg_world != null:
		for c in reg_world.contracts.values():
			if c.status in [TradeContract.STATUS_ACCEPTED, TradeContract.STATUS_RESERVED, TradeContract.STATUS_IN_TRANSIT, TradeContract.STATUS_DELIVERED, TradeContract.STATUS_SETTLED]:
				active_contracts += 1

	var target_contracts: int = 2
	var is_satisfied: bool = active_contracts >= target_contracts

	return {
		"id": OBJ_DISPATCH_COMMUNAL_TRADE,
		"stage": "Stage 2: Regional Trade Contracts",
		"title": "Expand Multi-Faction Commerce",
		"explanation": "A true crossroads serves multiple realms. Form contracts across factions to maintain at least 2 active trade agreements.",
		"action": "Establish trade with Old Grove Commune or ratify a second commercial agreement with Valen via Diplomacy (D).",
		"progress_text": "Trade Agreements: %d / %d" % [active_contracts, target_contracts],
		"is_satisfied": is_satisfied,
		"is_blocked": is_blocked,
		"blocker_reason": blocker,
		"all_completed": false
	}

func _eval_settle_merchant_emporium(world) -> Dictionary:
	var total_coin: int = _count_settlement_resource(world, &"coin")
	var target_coin: int = 150
	var reg_world = world.regional_world
	var has_settled: bool = false

	if reg_world != null:
		for c in reg_world.contracts.values():
			if c.status in [TradeContract.STATUS_SETTLED, TradeContract.STATUS_DELIVERED]:
				has_settled = true
				break

	var is_satisfied: bool = has_settled and (total_coin >= target_coin)
	var is_blocked: bool = false
	var blocker: String = ""

	return {
		"id": OBJ_SETTLE_MERCHANT_EMPORIUM,
		"stage": "Stage 3: Commercial Prosperity",
		"title": "Crownweft Trade Emporium",
		"explanation": "Caravans have traversed the regional routes. Settle the deliveries and amass at least 150 Coin across settlement reserves.",
		"action": "Allow caravans to deliver cargo, collect trade revenue, and accumulate 150 Coin in settlement stores.",
		"progress_text": "Treasury: %d / %d Coin  |  Delivery: %s" % [total_coin, target_coin, "CONFIRMED" if has_settled else "EN ROUTE"],
		"is_satisfied": is_satisfied,
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
	var active_copy: Array = []
	for id in active_objective_ids:
		active_copy.append(str(id))
	return {
		"current_scenario_id": str(current_scenario_id),
		"active_objective_ids": active_copy,
		"completed_objectives": copy,
		"is_minimized": is_minimized
	}

func deserialize(data: Dictionary) -> void:
	current_scenario_id = StringName(data.get("current_scenario_id", "crownweft_founding"))
	completed_objectives.clear()
	var raw_completed = data.get("completed_objectives", [])
	if raw_completed is Array:
		for id in raw_completed:
			completed_objectives.append(StringName(id))
	active_objective_ids.clear()
	var raw_active = data.get("active_objective_ids", [])
	if raw_active is Array and not raw_active.is_empty():
		for id in raw_active:
			active_objective_ids.append(StringName(id))
	else:
		var def: Dictionary = ScenarioCatalog.get_scenario_def(current_scenario_id)
		for id in def.get("objectives", []):
			active_objective_ids.append(StringName(id))
	is_minimized = bool(data.get("is_minimized", false))
