class_name TestScenarioVariety
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GuidanceService = preload("res://scripts/simulation/guidance_service.gd")
const EventLogService = preload("res://scripts/simulation/event_log_service.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")
const ArmyState = preload("res://scripts/domain/army_state.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestScenarioVariety (Task 20 Scenarios) ---")
	print("=======================================================")

	test_1_independent_initialization_all_scenarios()
	test_2_simulation_invariant_audit_post_init()
	test_3_deterministic_initialization_with_seed()
	test_4_zero_leakage_on_scenario_switch()
	test_5_border_march_objective_progression()
	test_6_merchants_crossroads_objective_progression()
	test_7_save_load_round_trip_scenario_preservation()
	test_8_legacy_save_compatibility()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestScenarioVariety: ALL 8 TEST SUITES PASSED ---")
	else:
		print("!! TestScenarioVariety FAILED with %d assertion errors" % _tests_failed)
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

func _create_world(scenario_id: StringName = ScenarioCatalog.SCENARIO_FOUNDING, seed_val: int = 12345) -> WorldScene:
	var world_scene_res = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_scene_res.instantiate()
	world._init_simulation(scenario_id, seed_val)
	return world

# ------------------------------------------------------------------------------
# Test 1: Independent Initialization of All 3 Scenarios
# ------------------------------------------------------------------------------
func test_1_independent_initialization_all_scenarios() -> void:
	print("\n>> Test 1: Independent initialization of all 3 scenarios")
	
	# Scenario A: Founding
	var world_a = _create_world(ScenarioCatalog.SCENARIO_FOUNDING)
	_assert_eq(world_a.current_scenario_id, ScenarioCatalog.SCENARIO_FOUNDING, "Scenario A ID matches")
	_assert(world_a.buildings.size() == 2, "Scenario A starts with 2 buildings (TH, Farm)")
	_assert(world_a.citizens.size() == 10, "Scenario A starts with 10 citizens")
	_assert(world_a.military_units.is_empty(), "Scenario A has no local military units")
	var th_a = world_a.buildings[0]
	_assert_eq(th_a.inventory.get_quantity(&"coin"), 60, "Scenario A has 60 starting coin")
	_assert_eq(th_a.inventory.get_quantity(&"timber"), 30, "Scenario A has 30 timber")
	_assert_eq(world_a.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_FOUNDING, "Guidance set to Founding")
	_assert(world_a.guidance.get_objective_list().size() == 7, "Scenario A has 7 guidance objectives")

	# Scenario B: Border March
	var world_b = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	_assert_eq(world_b.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Scenario B ID matches")
	_assert(world_b.buildings.size() == 3, "Scenario B starts with 3 buildings (TH, Barracks, Farm)")
	_assert(world_b.citizens.size() == 10, "Scenario B starts with 10 citizens")
	_assert(world_b.military_units.size() == 2, "Scenario B starts with 2 local standing military units")
	var barracks_found: bool = false
	for b in world_b.buildings:
		if b.definition_id == &"barracks":
			barracks_found = true
			break
	_assert(barracks_found, "Scenario B has a standing Barracks building")
	var ironpeak_rel = world_b.diplomacy.get_relationship(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_IRONPEAK)
	_assert(ironpeak_rel != null and ironpeak_rel.threat >= 50.0, "Scenario B has elevated Ironpeak threat")
	_assert_eq(world_b.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Guidance set to Border March")
	_assert(world_b.guidance.get_objective_list().size() == 5, "Scenario B has 5 guidance objectives")

	# Scenario C: Merchant's Crossroads
	var world_c = _create_world(ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS)
	_assert_eq(world_c.current_scenario_id, ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS, "Scenario C ID matches")
	_assert(world_c.buildings.size() == 3, "Scenario C starts with 3 buildings (TH, Storehouse, Farm)")
	_assert(world_c.citizens.size() == 12, "Scenario C starts with 12 citizens (including 4 dedicated haulers)")
	var storehouse_found: bool = false
	for b in world_c.buildings:
		if b.definition_id == &"storehouse":
			storehouse_found = true
			_assert(b.inventory.capacity == 150, "Storehouse has 150 capacity")
			break
	_assert(storehouse_found, "Scenario C has an operational Storehouse")
	var hauler_count: int = 0
	for c in world_c.citizens:
		if c.role_id == &"hauler":
			hauler_count += 1
	_assert(hauler_count == 4, "Scenario C starts with exactly 4 active haulers")
	var th_c = world_c.buildings[0]
	_assert_eq(th_c.inventory.get_quantity(&"coin"), 120, "Scenario C starts with 120 coin")
	var valen_rel = world_c.diplomacy.get_relationship(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN)
	_assert(valen_rel != null and valen_rel.trust >= 60.0, "Scenario C starts with warm Valen trust")
	_assert_eq(world_c.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS, "Guidance set to Merchant's Crossroads")
	_assert(world_c.guidance.get_objective_list().size() == 5, "Scenario C has 5 guidance objectives")

	print("✓ Test 1: Independent initialization of all 3 scenarios PASSED")

# ------------------------------------------------------------------------------
# Test 2: Invariant Audit Immediately Post-Init
# ------------------------------------------------------------------------------
func test_2_simulation_invariant_audit_post_init() -> void:
	print("\n>> Test 2: Simulation invariant audit post-init")
	
	var scenario_ids = [
		ScenarioCatalog.SCENARIO_FOUNDING,
		ScenarioCatalog.SCENARIO_BORDER_MARCH,
		ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS
	]

	for s_id in scenario_ids:
		var world = _create_world(s_id)
		var inv_check: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
			world.world_state, world.buildings, world.citizens, world.job_board,
			world.logistics, world.pathfinding, world.economy, world.government,
			world.diplomacy, world.regional_world
		)
		_assert(inv_check.passed, "Scenario %s passes invariants: %s" % [s_id, inv_check.summary()])
	
	print("✓ Test 2: Invariant audit immediately post-init PASSED")

# ------------------------------------------------------------------------------
# Test 3: Deterministic Initialization with Seed
# ------------------------------------------------------------------------------
func test_3_deterministic_initialization_with_seed() -> void:
	print("\n>> Test 3: Deterministic initialization with seed")

	var world1 = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH, 9999)
	var world2 = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH, 9999)

	_assert_eq(world1.buildings.size(), world2.buildings.size(), "Identical building counts")
	_assert_eq(world1.citizens.size(), world2.citizens.size(), "Identical citizen counts")
	_assert_eq(world1.military_units.size(), world2.military_units.size(), "Identical military unit counts")

	for i in range(world1.citizens.size()):
		var c1 = world1.citizens[i]
		var c2 = world2.citizens[i]
		_assert_eq(c1.role_id, c2.role_id, "Citizen %d role matches" % i)
		_assert_eq(c1.species_id, c2.species_id, "Citizen %d species matches" % i)
		_assert_eq(c1.culture_id, c2.culture_id, "Citizen %d culture matches" % i)
		_assert_eq(c1.social_status_id, c2.social_status_id, "Citizen %d status matches" % i)

	print("✓ Test 3: Deterministic initialization with seed PASSED")

# ------------------------------------------------------------------------------
# Test 4: Zero State Leakage on Scenario Switch
# ------------------------------------------------------------------------------
func test_4_zero_leakage_on_scenario_switch() -> void:
	print("\n>> Test 4: Zero state leakage on scenario switch")

	var world = _create_world(ScenarioCatalog.SCENARIO_FOUNDING)
	# Advance 20 simulation ticks
	for t in range(20):
		world._simulation_tick()
	_assert(world.current_tick == 20, "Advanced 20 ticks")
	_assert(world.event_log.events.size() > 0, "Event log populated during run")

	# Switch to Border March in the same instance
	world._on_scenario_selected(ScenarioCatalog.SCENARIO_BORDER_MARCH)

	_assert_eq(world.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Active scenario is Border March")
	_assert_eq(world.current_tick, 0, "Simulation tick cleanly reset to 0")
	_assert_eq(world.buildings.size(), 3, "Building list cleanly reset to exactly 3")
	_assert_eq(world.citizens.size(), 10, "Citizen list cleanly reset to exactly 10")
	_assert_eq(world.military_units.size(), 2, "Military units cleanly reset to exactly 2")
	_assert(world.selected_building == null, "Selected building cleared")
	_assert(world.selected_citizen == null, "Selected citizen cleared")
	_assert(world.selected_units.is_empty(), "Selected units cleared")
	_assert_eq(world.event_log.events.size(), 1, "Event log cleared and fresh scenario entry recorded")

	# Verify guidance service reset
	_assert_eq(world.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Guidance scenario updated")
	_assert(world.guidance.completed_objectives.is_empty(), "Completed objectives cleared")
	_assert_eq(world.guidance.get_current_objective_id(world), GuidanceService.OBJ_STAFF_GARRISON, "First Border March objective active")

	print("✓ Test 4: Zero state leakage on scenario switch PASSED")

# ------------------------------------------------------------------------------
# Test 5: Border March Objective Progression
# ------------------------------------------------------------------------------
func test_5_border_march_objective_progression() -> void:
	print("\n>> Test 5: Border March objective progression")

	var world = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	var gs = world.guidance

	# Objective 1: Staff Garrison (Barracks)
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_STAFF_GARRISON, "Stage 1 is Staff Garrison")
	var unit = world.combat.spawn_player_unit(&"warrior", Vector2(100, 100))
	world.military_units.append(unit)
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_STAFF_GARRISON), "Staff garrison now satisfied (3 units)")

	# Objective 2: Stock Rations
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_STOCK_RATIONS, "Stage 2 is Stock Rations")
	var th = world.buildings[0]
	th.inventory.add_resource(&"bread", 25, "TEST_RESUPPLY")
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_STOCK_RATIONS), "Stock rations satisfied with bread in stockpile")

	# Objective 3: Resupply Royal Crown Guard
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_RESUPPLY_ARMY, "Stage 3 is Resupply Royal Crown Guard")
	var army: ArmyState = world.regional_world.armies.values()[0]
	_assert(army != null, "Found army")
	army.add_supplies(&"grain", 25, world.current_tick)
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_RESUPPLY_ARMY), "Resupply army satisfied (supplies >= 35)")

	# Objective 4 & 5: Patrol Mountain Pass & Secure Frontier
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_PATROL_FRONTIER, "Stage 4 is Patrol Mountain Pass")
	army.current_region_id = RegionCatalog.REGION_SHATTERED_PASS
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_PATROL_FRONTIER), "Patrol satisfied when army is stationed at Shattered Pass")
	_assert(gs.is_objective_completed(GuidanceService.OBJ_SECURE_FRONTIER), "Secure frontier satisfied via frontier garrison deterrence")

	# All completed
	_assert_eq(gs.get_current_objective_id(world), &"all_completed", "All Border March objectives completed")
	var final_info = gs.update_guidance(world, world.event_log)
	_assert(final_info.get("all_completed", false), "Border March scenario complete")
	_assert_eq(final_info["title"], "Frontier Secured", "Completion title matches")

	print("✓ Test 5: Border March objective progression PASSED")

# ------------------------------------------------------------------------------
# Test 6: Merchant's Crossroads Objective Progression
# ------------------------------------------------------------------------------
func test_6_merchants_crossroads_objective_progression() -> void:
	print("\n>> Test 6: Merchant's Crossroads objective progression")

	var world = _create_world(ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS)
	var gs = world.guidance

	# Objective 1: Inspect Storehouse Logistics (already satisfied on init due to storehouse & 4 haulers)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_INSPECT_STOREHOUSE), "Storehouse logistics satisfied immediately with 4 haulers and Storehouse")

	var storehouse: BuildingState = null
	for b in world.buildings:
		if b.definition_id == &"storehouse":
			storehouse = b
			break
	_assert(storehouse != null, "Found operational Storehouse")

	# Objective 2: Produce Export Surplus
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_PRODUCE_SURPLUS, "Stage 2 is Produce Export Surplus")
	storehouse.inventory.add_resource(&"grain", 20, "TEST_SURPLUS")
	storehouse.inventory.add_resource(&"timber", 15, "TEST_SURPLUS")
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_PRODUCE_SURPLUS), "Produce surplus satisfied with sufficient grain & timber")

	# Objective 3: Ratify Valen Export Contract
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_RATIFY_VALEN_EXPORT, "Stage 3 is Ratify Valen Export")
	var contract1 = TradeContract.new(1, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, &"grain", 10, 25, RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 0)
	contract1.status = TradeContract.STATUS_ACCEPTED
	world.regional_world.contracts[1] = contract1
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_RATIFY_VALEN_EXPORT), "Ratify export satisfied with active contract")

	# Objective 4: Expand Multi-Faction Commerce
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_DISPATCH_COMMUNAL_TRADE, "Stage 4 is Multi-Faction Commerce")
	var contract2 = TradeContract.new(2, FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER, &"timber", 10, 20, RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_OLD_GROVE, 0)
	contract2.status = TradeContract.STATUS_ACCEPTED
	world.regional_world.contracts[2] = contract2
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_DISPATCH_COMMUNAL_TRADE), "Multi-faction commerce satisfied with 2 active contracts")

	# Objective 5: Settle Regional Emporium
	_assert_eq(gs.get_current_objective_id(world), GuidanceService.OBJ_SETTLE_MERCHANT_EMPORIUM, "Stage 5 is Settle Regional Emporium")
	contract1.status = TradeContract.STATUS_SETTLED
	storehouse.inventory.add_resource(&"coin", 100, "TEST_COIN")
	gs.update_guidance(world, world.event_log)
	_assert(gs.is_objective_completed(GuidanceService.OBJ_SETTLE_MERCHANT_EMPORIUM), "Settle emporium satisfied (contract settled and coin >= 150)")

	# All completed
	_assert_eq(gs.get_current_objective_id(world), &"all_completed", "All Merchant Crossroads objectives completed")
	var final_info = gs.update_guidance(world, world.event_log)
	_assert(final_info.get("all_completed", false), "Merchant's Crossroads scenario complete")
	_assert_eq(final_info["title"], "Merchant Emporium Flourishing", "Completion title matches")

	print("✓ Test 6: Merchant's Crossroads objective progression PASSED")

# ------------------------------------------------------------------------------
# Test 7: Save/Load Round-Trip Scenario Preservation
# ------------------------------------------------------------------------------
func test_7_save_load_round_trip_scenario_preservation() -> void:
	print("\n>> Test 7: Save/load round-trip scenario preservation")

	var world = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	world.guidance.completed_objectives.append(GuidanceService.OBJ_STAFF_GARRISON)
	world.current_tick = 42

	var test_path: String = "user://test_save_scenario_border_march.json"
	var ok: bool = world.save_game(test_path)
	_assert(ok, "Saved border march game successfully")

	# Create new world and load
	var loaded_world = _create_world(ScenarioCatalog.SCENARIO_FOUNDING) # initially founding
	var load_ok: bool = loaded_world.load_game(test_path)
	_assert(load_ok, "Loaded border march save successfully")

	_assert_eq(loaded_world.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Restored scenario ID is Border March")
	_assert_eq(loaded_world.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_BORDER_MARCH, "Guidance service scenario ID restored")
	_assert(loaded_world.guidance.completed_objectives.has(GuidanceService.OBJ_STAFF_GARRISON), "Completed objective preserved")
	_assert_eq(loaded_world.current_tick, 42, "Tick preserved")
	_assert_eq(loaded_world.buildings.size(), 3, "Building count preserved")
	_assert_eq(loaded_world.military_units.size(), 2, "Military units preserved")

	# Clean up file
	DirAccess.remove_absolute(test_path)
	print("✓ Test 7: Save/load round-trip scenario preservation PASSED")

# ------------------------------------------------------------------------------
# Test 8: Legacy Save Compatibility
# ------------------------------------------------------------------------------
func test_8_legacy_save_compatibility() -> void:
	print("\n>> Test 8: Legacy save compatibility")

	var world = _create_world(ScenarioCatalog.SCENARIO_FOUNDING)
	var test_path: String = "user://test_legacy_save.json"
	world.save_game(test_path)

	# Read save file and delete meta.scenario_id to simulate legacy save
	var file = FileAccess.open(test_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var data: Dictionary = JSON.parse_string(text)
	if data.has("meta") and data["meta"].has("scenario_id"):
		data["meta"].erase("scenario_id")

	var out_file = FileAccess.open(test_path, FileAccess.WRITE)
	out_file.store_string(JSON.stringify(data))
	out_file.close()

	# Load into fresh instance
	var loaded_world = _create_world(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	var load_ok: bool = loaded_world.load_game(test_path)
	_assert(load_ok, "Loaded legacy save without crashing")

	# Should safely default to Founding
	_assert_eq(loaded_world.current_scenario_id, ScenarioCatalog.SCENARIO_FOUNDING, "Legacy save defaults safely to crownweft_founding")
	_assert_eq(loaded_world.guidance.current_scenario_id, ScenarioCatalog.SCENARIO_FOUNDING, "Guidance defaults safely to crownweft_founding")

	DirAccess.remove_absolute(test_path)
	print("✓ Test 8: Legacy save compatibility PASSED")
