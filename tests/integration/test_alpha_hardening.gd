class_name TestAlphaHardening
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GuidanceService = preload("res://scripts/simulation/guidance_service.gd")
const EventLogService = preload("res://scripts/simulation/event_log_service.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestAlphaHardening (Task 19 Hardening) ---")
	print("=======================================================")

	test_1_out_of_order_execution_and_cascading()
	test_2_multi_building_selection_and_assignment()
	test_3_bread_consumption_decoupling()
	test_4_false_blocker_suppression_on_rest_and_commute()
	test_5_town_hall_trade_stock_diagnostic()
	test_6_material_shortage_and_recovery()
	test_7_save_load_round_trip_lifetime_produced()
	test_8_canonical_data_consistency_audit()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestAlphaHardening: ALL 8 TEST SUITES PASSED ---")
	else:
		print("!! TestAlphaHardening FAILED with %d assertion errors" % _tests_failed)
	print("=======================================================")
	quit(_tests_failed)

func _assert(cond: bool, msg: String) -> void:
	_tests_run += 1
	if not cond:
		_tests_failed += 1
		printerr("Assertion FAILED: ", msg)
	else:
		_tests_passed += 1

func _assert_eq(a, b, msg: String) -> void:
	_tests_run += 1
	if a != b:
		_tests_failed += 1
		printerr("Assertion FAILED: expected %s, got %s. %s" % [str(b), str(a), msg])
	else:
		_tests_passed += 1

func _create_world() -> WorldScene:
	var world_scene_res = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_scene_res.instantiate()
	world._init_simulation()
	return world

func _assign_citizen_to_building(citizen: CitizenState, building: BuildingState, role: StringName) -> void:
	building.assigned_workers += 1
	citizen.workplace_id = building.entity_id
	citizen.role_id = role

func _unassign_citizen(citizen: CitizenState, building: BuildingState) -> void:
	if building != null:
		building.assigned_workers = maxi(0, building.assigned_workers - 1)
	citizen.workplace_id = 0
	citizen.role_id = &"unassigned"

func _find_valid_placement(world: WorldScene, b_id: StringName, center: Vector2i, radius: int = 6) -> Vector2i:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var test_pos: Vector2i = center + Vector2i(dx, dy)
			if world.can_place_building_at(b_id, test_pos).get("ok", false):
				return test_pos
	return Vector2i(-1, -1)

# ------------------------------------------------------------------------------
# Test 1: Out-of-Order Execution & Cascading Objectives
# ------------------------------------------------------------------------------
func test_1_out_of_order_execution_and_cascading() -> void:
	print("\n[Test 1] Testing Out-of-Order Execution & Cascading Objectives...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance
	var th_pos: Vector2i = world.world_state.start_settlement_pos

	# Start: Objective 1 (Staff Farm) is active
	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_STAFF_FARM, "Initial objective is OBJ_STAFF_FARM")

	# Player builds Bakery BEFORE completing farming
	var bakery_pos: Vector2i = _find_valid_placement(world, &"bakery", th_pos)
	_assert(bakery_pos != Vector2i(-1, -1), "Found valid bakery placement")
	var bakery = world.place_building(&"bakery", bakery_pos, false)
	_assert(bakery != null, "Bakery placed before farm is staffed")

	# Objective 1 should still be OBJ_STAFF_FARM
	info = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_STAFF_FARM, "Objective remains OBJ_STAFF_FARM")

	# Supply construction materials and activate bakery
	if bakery.construction_inventory != null:
		bakery.construction_inventory.quantities[&"timber"] = 4
		bakery.construction_inventory.quantities[&"stone"] = 4
	bakery.construction_progress = 1.0
	bakery.status = BuildingState.Status.ACTIVE

	# Objective 1 should still be OBJ_STAFF_FARM
	info = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_STAFF_FARM, "Objective remains OBJ_STAFF_FARM after bakery active")

	# Now staff the farm
	var farm: BuildingState = world.buildings[1]
	_assign_citizen_to_building(world.citizens[2], farm, &"farmer")
	_assert_eq(farm.assigned_workers, 1, "Farm staffed")

	# Step: Objective 1 completes, transitions to OBJ_PRODUCE_GRAIN
	info = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PRODUCE_GRAIN, "Objective transitioned to OBJ_PRODUCE_GRAIN")

	# Satisfy grain production
	farm.lifetime_produced[&"grain"] = 10
	farm.inventory.quantities[&"grain"] = 10

	# Because Bakery is ALREADY placed and constructed, updating guidance should CASCADE:
	# OBJ_PRODUCE_GRAIN -> completed
	# OBJ_PLACE_BAKERY -> automatically satisfied & completed
	# OBJ_CONSTRUCT_BAKERY -> automatically satisfied & completed
	# Lands on OBJ_PRODUCE_BREAD!
	info = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PRODUCE_BREAD, "Cascading loop jumped directly to OBJ_PRODUCE_BREAD")
	_assert(guidance.is_objective_completed(GuidanceService.OBJ_PLACE_BAKERY), "OBJ_PLACE_BAKERY marked completed in cascade")
	_assert(guidance.is_objective_completed(GuidanceService.OBJ_CONSTRUCT_BAKERY), "OBJ_CONSTRUCT_BAKERY marked completed in cascade")
	print("✓ Out-of-order execution and cascading verified")

# ------------------------------------------------------------------------------
# Test 2: Multi-Building Selection & Assignment
# ------------------------------------------------------------------------------
func test_2_multi_building_selection_and_assignment() -> void:
	print("\n[Test 2] Testing Multi-Building Selection & Assignment...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance
	var th_pos: Vector2i = world.world_state.start_settlement_pos

	# The initial farm is at index 1 and unstaffed.
	# Player places a second farm near settlement
	var farm2_pos: Vector2i = _find_valid_placement(world, &"farm", th_pos)
	_assert(farm2_pos != Vector2i(-1, -1), "Found valid secondary farm placement")
	var farm2 = world.place_building(&"farm", farm2_pos, true)
	_assert(farm2 != null, "Second farm placed")
	farm2.status = BuildingState.Status.ACTIVE

	# Assign worker to the SECOND farm only
	_assign_citizen_to_building(world.citizens[2], farm2, &"farmer")
	_assert_eq(farm2.assigned_workers, 1, "Farm 2 is staffed")

	var farm1 = world.buildings[1]
	_assert_eq(farm1.assigned_workers, 0, "Farm 1 remains unstaffed")

	# GuidanceService._find_best_building should choose Farm 2 because it is active and staffed
	var best_farm = guidance._find_best_building(world, &"farm")
	_assert_eq(best_farm.entity_id, farm2.entity_id, "_find_best_building picked the staffed farm")

	# Objective 1 should be satisfied because at least one farm is staffed
	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PRODUCE_GRAIN, "Objective 1 completed via secondary farm assignment")
	print("✓ Multi-building selection and assignment verified")

# ------------------------------------------------------------------------------
# Test 3: Bread Consumption Decoupling (Lifetime Produced)
# ------------------------------------------------------------------------------
func test_3_bread_consumption_decoupling() -> void:
	print("\n[Test 3] Testing Bread Consumption Decoupling (Lifetime Produced)...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance

	# Fast-forward to OBJ_PRODUCE_BREAD
	guidance.completed_objectives.append(GuidanceService.OBJ_STAFF_FARM)
	guidance.completed_objectives.append(GuidanceService.OBJ_PRODUCE_GRAIN)
	guidance.completed_objectives.append(GuidanceService.OBJ_PLACE_BAKERY)
	guidance.completed_objectives.append(GuidanceService.OBJ_CONSTRUCT_BAKERY)

	var th_pos: Vector2i = world.world_state.start_settlement_pos
	var b_pos: Vector2i = _find_valid_placement(world, &"bakery", th_pos)
	_assert(b_pos != Vector2i(-1, -1), "Found valid bakery placement")
	var bakery = world.place_building(&"bakery", b_pos, true)
	_assert(bakery != null, "Bakery placed")
	bakery.status = BuildingState.Status.ACTIVE
	_assign_citizen_to_building(world.citizens[3], bakery, &"baker")

	# Simulate bakery producing 1 bread into lifetime_produced
	bakery.lifetime_produced[&"bread"] = 1
	bakery.inventory.quantities[&"bread"] = 0 # Stock is 0 (eaten or moved)
	
	# Settlement has only starting bread in Town Hall, but bakery produced bread in its lifetime
	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PROPOSE_TRADE, "OBJ_PRODUCE_BREAD completed despite 0 bread in bakery inventory")
	_assert(guidance.is_objective_completed(GuidanceService.OBJ_PRODUCE_BREAD), "Bread objective completed via lifetime_produced")
	print("✓ Bread consumption decoupling verified")

# ------------------------------------------------------------------------------
# Test 4: False Blocker Suppression on Worker Rest & Commute
# ------------------------------------------------------------------------------
func test_4_false_blocker_suppression_on_rest_and_commute() -> void:
	print("\n[Test 4] Testing False Blocker Suppression on Worker Rest & Commute...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance
	var farm = world.buildings[1]

	# Assign citizen 2 to farm
	var worker = world.citizens[2]
	_assign_citizen_to_building(worker, farm, &"farmer")
	guidance.completed_objectives.append(GuidanceService.OBJ_STAFF_FARM)

	# Simulate ProductionSystem setting NO_WORKERS while citizen is resting
	worker.is_resting = true
	farm.current_block_reason = &"NO_WORKERS"

	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PRODUCE_GRAIN, "Current objective is OBJ_PRODUCE_GRAIN")
	_assert(not info.get("is_blocked", true), "is_blocked is FALSE when assigned worker is resting")
	_assert("resting" in info.get("blocker_reason", "").to_lower(), "Informative resting message present")

	# Simulate worker commuting (moving)
	worker.is_resting = false
	worker.move_state = CitizenState.MoveState.MOVING
	farm.current_block_reason = &"NO_WORKERS"

	info = guidance.update_guidance(world)
	_assert(not info.get("is_blocked", true), "is_blocked is FALSE when assigned worker is commuting")
	_assert("commuting" in info.get("blocker_reason", "").to_lower(), "Informative commuting message present")

	# When genuine lack of workers: unassign worker
	_unassign_citizen(worker, farm)
	worker.move_state = CitizenState.MoveState.IDLE
	farm.assigned_workers = 0
	farm.current_block_reason = &"NO_WORKERS"

	info = guidance.update_guidance(world)
	_assert(info.get("is_blocked", false), "is_blocked is TRUE when farm is genuinely unstaffed")
	print("✓ False blocker suppression on rest and commute verified")

# ------------------------------------------------------------------------------
# Test 5: Town Hall Trade Stock Diagnostic
# ------------------------------------------------------------------------------
func test_5_town_hall_trade_stock_diagnostic() -> void:
	print("\n[Test 5] Testing Town Hall Trade Stock Diagnostic...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance

	# Fast-forward to OBJ_PROPOSE_TRADE
	for obj in [GuidanceService.OBJ_STAFF_FARM, GuidanceService.OBJ_PRODUCE_GRAIN, GuidanceService.OBJ_PLACE_BAKERY, GuidanceService.OBJ_CONSTRUCT_BAKERY, GuidanceService.OBJ_PRODUCE_BREAD]:
		guidance.completed_objectives.append(obj)

	var th = world.buildings[0]
	var farm = world.buildings[1]

	# Farm has 10 grain, Town Hall only has 3 grain
	th.inventory.quantities[&"grain"] = 3
	farm.inventory.quantities[&"grain"] = 7

	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PROPOSE_TRADE, "Active objective is OBJ_PROPOSE_TRADE")
	_assert("Storage: 3 / 10 Grain in Town Hall" in info.get("progress_text", ""), "Progress text clearly reports Town Hall storage")
	_assert("in transit" in info.get("blocker_reason", "").to_lower(), "Clarifies that haulers are moving grain to Town Hall")
	print("✓ Town Hall trade stock diagnostic verified")

# ------------------------------------------------------------------------------
# Test 6: Material Shortage & Recovery via Woodcutter Camp
# ------------------------------------------------------------------------------
func test_6_material_shortage_and_recovery() -> void:
	print("\n[Test 6] Testing Material Shortage & Recovery via Woodcutter Camp...")
	var world = _create_world()
	var guidance: GuidanceService = world.guidance

	guidance.completed_objectives.append(GuidanceService.OBJ_STAFF_FARM)
	guidance.completed_objectives.append(GuidanceService.OBJ_PRODUCE_GRAIN)

	var th = world.buildings[0]
	# Deplete timber so bakery cannot be placed
	th.inventory.quantities[&"timber"] = 1

	var info: Dictionary = guidance.update_guidance(world)
	_assert_eq(info.get("id"), GuidanceService.OBJ_PLACE_BAKERY, "Active objective is OBJ_PLACE_BAKERY")
	_assert(info.get("is_blocked", false), "is_blocked is TRUE due to material shortage")
	_assert("woodcutter camp" in info.get("blocker_reason", "").to_lower(), "Recommends Woodcutter Camp to recover from shortage")

	# Build Woodcutter Camp and produce timber
	var th_pos: Vector2i = world.world_state.start_settlement_pos
	var wc_pos: Vector2i = _find_valid_placement(world, &"woodcutter", th_pos)
	_assert(wc_pos != Vector2i(-1, -1), "Found valid woodcutter placement")
	var wc = world.place_building(&"woodcutter", wc_pos, true)
	_assert(wc != null, "Woodcutter placed")
	wc.status = BuildingState.Status.ACTIVE
	th.inventory.quantities[&"timber"] = 10

	info = guidance.update_guidance(world)
	_assert(not info.get("is_blocked", true), "is_blocked is FALSE once timber is replenished")
	print("✓ Material shortage and recovery verified")

# ------------------------------------------------------------------------------
# Test 7: Save/Load Round-Trip for Lifetime Produced
# ------------------------------------------------------------------------------
func test_7_save_load_round_trip_lifetime_produced() -> void:
	print("\n[Test 7] Testing Save/Load Round-Trip for Lifetime Produced...")
	var world = _create_world()
	var farm = world.buildings[1]

	farm.lifetime_produced[&"grain"] = 42
	farm.lifetime_produced[&"seeds"] = 5

	var save_path := "user://saves/test_hardening_lifetime.json"
	var save_ok = world.save_game(save_path)
	_assert(save_ok, "World saved successfully")

	var world2 = _create_world()
	var load_ok = world2.load_game(save_path)
	_assert(load_ok, "World loaded successfully")

	var farm2 = world2.buildings[1]
	_assert_eq(farm2.lifetime_produced.get(&"grain", 0), 42, "Lifetime grain production preserved across save/load")
	_assert_eq(farm2.lifetime_produced.get(&"seeds", 0), 5, "Lifetime seeds production preserved across save/load")
	print("✓ Save/load round-trip for lifetime produced verified")

# ------------------------------------------------------------------------------
# Test 8: Canonical Data Consistency Audit
# ------------------------------------------------------------------------------
func test_8_canonical_data_consistency_audit() -> void:
	print("\n[Test 8] Testing Canonical Data Consistency Audit...")
	var world = _create_world()

	var valid_species = SpeciesCatalog.SPECIES_IDS
	_assert(valid_species.has(&"human"), "SpeciesCatalog has human")
	_assert(valid_species.has(&"stoneborn"), "SpeciesCatalog has stoneborn")
	_assert(valid_species.has(&"greenwarden"), "SpeciesCatalog has greenwarden")
	_assert(not valid_species.has(&"frostkin"), "SpeciesCatalog does NOT contain frostkin")

	for c in world.citizens:
		_assert(valid_species.has(c.species_id), "Citizen %d has valid canonical species (%s)" % [c.id, str(c.species_id)])
		_assert(SocialClassCatalog.STATUS_IDS.has(c.social_status_id), "Citizen %d has valid canonical class (%s)" % [c.id, str(c.social_status_id)])
		_assert(CultureCatalog.CULTURE_IDS.has(c.culture_id), "Citizen %d has valid canonical culture (%s)" % [c.id, str(c.culture_id)])

	# Verify starting factions
	for f in world.diplomacy.factions.values():
		_assert(FactionCatalog.FACTION_IDS.has(f.id), "Faction %s has valid canonical ID" % str(f.id))

	print("✓ Canonical data consistency audit verified")
