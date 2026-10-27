class_name TestResidentialLife
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SpeciesCatalog = preload("res://scripts/domain/species_catalog.gd")
const SocialClassCatalog = preload("res://scripts/domain/social_class_catalog.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestResidentialLife (Task 21 Residential) ---")
	print("=======================================================\n")

	test_1_housing_capacity_and_occupancy_calculation()
	test_2_assignment_rejection_and_capacity_limits()
	test_3_dynamic_capacity_changes_lifecycle()
	test_4_homeless_rest_blocker_and_energy_recovery()
	test_5_migration_prerequisites_and_decrees()
	test_6_migration_arrival_and_newcomer_attributes()
	test_7_save_load_round_trip_preservation()
	test_8_scenario_compatibility_and_zero_start_migration()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestResidentialLife: ALL 8 TEST SUITES PASSED ---")
	else:
		print("!! TestResidentialLife FAILED with %d assertion errors" % _tests_failed)
	print("=======================================================\n")
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
		printerr("Assertion FAILED: %s. Expected: %s, Got: %s" % [msg, str(b), str(a)])
	else:
		_tests_passed += 1

func _create_headless_world(scenario_id: StringName = ScenarioCatalog.SCENARIO_FOUNDING) -> WorldScene:
	var w: WorldScene = WorldScene.new()
	var ui: GameUI = GameUI.new()
	w.add_child(ui)
	w.ui = ui
	w._init_simulation(scenario_id)
	return w

func _cleanup_world(w: WorldScene) -> void:
	if w != null and is_instance_valid(w):
		w.queue_free()

func test_1_housing_capacity_and_occupancy_calculation() -> void:
	print(">> Test 1: Residential capacity and occupancy calculation")
	var w: WorldScene = _create_headless_world()

	# Initially founding scenario has Town Hall + Farm, 0 houses
	_assert_eq(w.get_total_housing_capacity(), 0, "Initial housing capacity must be 0")
	_assert_eq(w.get_housed_citizens_count(), 0, "Initial housed count must be 0")
	_assert_eq(w.get_homeless_citizens_count(), w.citizens.size(), "All initial citizens must be homeless")
	_assert_eq(w.get_available_housing_capacity(), 0, "No vacancy initially")

	# Verify catalog definitions
	_assert(BuildingCatalog.is_residential(&"house"), "House must be residential")
	_assert(not BuildingCatalog.is_residential(&"town_hall"), "Town Hall must not be residential")
	_assert(not BuildingCatalog.is_residential(&"farm"), "Farm must not be residential")
	_assert_eq(BuildingCatalog.get_housing_capacity(&"house"), 5, "House capacity must be 5")
	_assert_eq(BuildingCatalog.get_housing_capacity(&"farm"), 0, "Farm capacity must be 0")

	# Place and activate a house
	var house: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	_assert(house != null, "House placement must succeed")
	_assert(house.is_residential(), "House state must be residential")
	_assert_eq(house.get_housing_capacity(), 5, "Active house capacity must be 5")

	_assert_eq(w.get_total_housing_capacity(), 5, "Total capacity must now be 5")
	_assert_eq(w.get_available_housing_capacity(), 5, "Available vacancy must now be 5")

	# Place a second house as PLANNED
	var planned_house: BuildingState = w.place_building(&"house", Vector2i(25, 28), false)
	_assert(planned_house != null, "Planned house placement must succeed")
	_assert_eq(planned_house.get_housing_capacity(), 0, "Planned house must have 0 capacity until active")
	_assert_eq(w.get_total_housing_capacity(), 5, "Total capacity must remain 5 with 1 active house")

	_cleanup_world(w)
	print("✓ Test 1: Residential capacity and occupancy calculation PASSED\n")

func test_2_assignment_rejection_and_capacity_limits() -> void:
	print(">> Test 2: Assignment rejection and capacity limits")
	var w: WorldScene = _create_headless_world()

	var house: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	_assert(house != null, "House placement must succeed")

	# Assign up to capacity (5 citizens)
	for i in range(5):
		var c: CitizenState = w.citizens[i]
		var ok: bool = w.assign_citizen_home(c, house)
		_assert(ok, "Assignment %d to house must succeed" % i)
		_assert_eq(c.home_building_id, house.entity_id, "Citizen %d home must be house ID" % i)

	_assert_eq(w.get_building_occupants(house.entity_id).size(), 5, "House must have 5 occupants")
	_assert_eq(w.get_available_housing_capacity(), 0, "Available capacity must be 0")

	# 6th assignment must be rejected
	var sixth: CitizenState = w.citizens[5]
	var rejected: bool = w.assign_citizen_home(sixth, house)
	_assert(not rejected, "Assignment beyond capacity must be rejected")
	_assert_eq(sixth.home_building_id, 0, "Sixth citizen must remain homeless")

	# Cannot assign to non-residential building
	var town_hall: BuildingState = w.buildings[0]
	var non_res_res: bool = w.assign_citizen_home(sixth, town_hall)
	_assert(not non_res_res, "Assignment to non-residential building must fail")

	# Cannot assign to inactive house
	var planned_house: BuildingState = w.place_building(&"house", Vector2i(25, 28), false)
	var inactive_res: bool = w.assign_citizen_home(sixth, planned_house)
	_assert(not inactive_res, "Assignment to planned house must fail")

	# Eviction on overflow: manually force 6th citizen in and run update
	sixth.home_building_id = house.entity_id
	w._update_housing_and_rest()
	_assert_eq(w.get_building_occupants(house.entity_id).size(), 5, "Occupants must be clamped to 5")
	_assert_eq(sixth.home_building_id, 0, "Excess occupant must be evicted")

	_cleanup_world(w)
	print("✓ Test 2: Assignment rejection and capacity limits PASSED\n")

func test_3_dynamic_capacity_changes_lifecycle() -> void:
	print(">> Test 3: Dynamic capacity changes upon house lifecycle")
	var w: WorldScene = _create_headless_world()

	_assert_eq(w.get_total_housing_capacity(), 0, "Initial capacity is 0")
	var h1: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	_assert_eq(w.get_total_housing_capacity(), 5, "Capacity is 5 after h1")

	# Auto-assignment of homeless citizens
	w._update_housing_and_rest()
	_assert_eq(w.get_housed_citizens_count(), 5, "5 citizens auto-assigned")
	_assert_eq(w.get_homeless_citizens_count(), w.citizens.size() - 5, "Remaining are homeless")

	# Add second house
	var h2: BuildingState = w.place_building(&"house", Vector2i(25, 28), true)
	_assert_eq(w.get_total_housing_capacity(), 10, "Capacity is 10 after h2")
	w._update_housing_and_rest()
	_assert_eq(w.get_housed_citizens_count(), mini(w.citizens.size(), 10), "Auto-assigned up to 10 citizens")

	# Demolish h1 (mark destroyed)
	h1.is_destroyed = true
	_assert_eq(w.get_total_housing_capacity(), 5, "Capacity reduced to 5 after destruction")
	w._update_housing_and_rest()

	# Former h1 occupants must not have h1 as home
	for c: CitizenState in w.citizens:
		_assert(c.home_building_id != h1.entity_id, "Destroyed home must be cleared from citizen")

	_cleanup_world(w)
	print("✓ Test 3: Dynamic capacity changes upon house lifecycle PASSED\n")

func test_4_homeless_rest_blocker_and_energy_recovery() -> void:
	print(">> Test 4: Homeless rest blocker and energy recovery")
	var w: WorldScene = _create_headless_world()

	var c: CitizenState = w.citizens[0]
	c.energy = 10.0 # Exhausted
	_assert(c.is_exhausted(), "Citizen must be exhausted")
	_assert_eq(c.home_building_id, 0, "Citizen is homeless")

	# Tick housing and rest
	w._update_housing_and_rest()
	_assert(c.is_resting, "Exhausted citizen must enter resting state")
	_assert_eq(c.current_block_reason, &"Resting outdoors — no valid home assigned", "Must receive diagnostic blocker")
	_assert_eq(c.energy, 10.5, "Homeless citizen recovers energy through fallback rate (0.5/tick)")

	# Now place and activate a house
	var house: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	# Position citizen adjacent to house entrance
	c.position_tile = house.get_entrance_tile()

	# Tick housing and rest again
	w._update_housing_and_rest()
	_assert_eq(c.home_building_id, house.entity_id, "Citizen must be assigned to new house")
	_assert_eq(c.current_block_reason, &"", "Blocker must clear upon having a home")
	_assert(c.energy > 10.0, "Energy must recover when resting at home")

	_cleanup_world(w)
	print("✓ Test 4: Homeless rest blocker and energy recovery PASSED\n")

func test_5_migration_prerequisites_and_decrees() -> void:
	print(">> Test 5: Migration prerequisites and decrees")
	var w: WorldScene = _create_headless_world()

	var needs_report: Dictionary = {"fed": 10, "hungry": 0, "at_risk": 0}

	# 1. No vacancy -> blocked
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "blocked", "Migration must be blocked without housing")
	_assert_eq(w.migration_block_reason, "No vacant housing available in settlement.", "Correct reason")

	# Add enough housing for all current citizens + extra (3 houses = 15 slots > 10 citizens)
	for i in range(3):
		w.place_building(&"house", Vector2i(25, 20 + i * 3), true)
	w._update_housing_and_rest()
	_assert(w.get_available_housing_capacity() > 0, "Vacancy must exist")

	# 2. Food shortage: empty food inventories
	var town_hall: BuildingState = w.buildings[0]
	town_hall.inventory.quantities.clear()
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "blocked", "Migration must be blocked with food shortage")
	_assert_eq(w.migration_block_reason, "Settlement food supply insufficient or citizens starving.", "Food shortage reason")

	# Add food buffer
	town_hall.inventory.add_resource(&"bread", 50, "TEST")
	town_hall.inventory.add_resource(&"meat", 20, "TEST")

	# 3. Low approval
	w.economy.approval = 40.0
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "blocked", "Migration must be blocked with low approval")
	_assert_eq(w.migration_block_reason, "Settlement approval too low to attract newcomers.", "Approval reason")

	# Raise approval
	w.economy.approval = 75.0

	# 4. Decree: Closed immigration
	w.government.enact_policy(LawCatalog.LAW_IMMIGRATION, &"closed", 0)
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "blocked", "Closed decree must block migration")
	_assert_eq(w.migration_block_reason, "Immigration forbidden by government decree.", "Closed decree reason")

	# 5. Decree: Selective immigration
	w.government.enact_policy(LawCatalog.LAW_IMMIGRATION, &"selective", 0)
	# Selective requires approval >= 65 and food >= 4x pop
	town_hall.inventory.quantities[&"bread"] = 10 # low food for selective
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "blocked", "Selective criteria must fail if food buffer insufficient")
	_assert_eq(w.migration_block_reason, "Settlement conditions do not meet selective immigration criteria.", "Selective fail reason")

	town_hall.inventory.quantities[&"bread"] = 100
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "attracting", "Selective must pass when all conditions met")
	_assert_eq(w.migration_block_reason, "", "No blocker reason")

	# 6. Decree: Open immigration
	w.government.enact_policy(LawCatalog.LAW_IMMIGRATION, &"open", 0)
	w.tick_migration(needs_report)
	_assert_eq(w.migration_status, "attracting", "Open immigration must attract newcomers")
	_assert_eq(w.migration_block_reason, "", "No blocker reason")

	_cleanup_world(w)
	print("✓ Test 5: Migration prerequisites and decrees PASSED\n")

func test_6_migration_arrival_and_newcomer_attributes() -> void:
	print(">> Test 6: Migration arrival and newcomer attributes")
	var w: WorldScene = _create_headless_world()

	# Set up ideal conditions (3 houses = 15 capacity > 10 citizens)
	for i in range(3):
		w.place_building(&"house", Vector2i(25, 20 + i * 3), true)
	w._update_housing_and_rest()
	var town_hall: BuildingState = w.buildings[0]
	town_hall.inventory.add_resource(&"bread", 100, "TEST")
	w.economy.approval = 80.0
	var initial_pop: int = w.citizens.size()

	# Force migration progress to 99.0
	w.migration_progress = 99.0
	var needs_report: Dictionary = {"fed": initial_pop, "hungry": 0, "at_risk": 0}
	w.tick_migration(needs_report)

	# Should have triggered arrival
	_assert_eq(w.citizens.size(), initial_pop + 1, "New citizen must be spawned")
	_assert_eq(w.total_migrants_arrived, 1, "Total migrants must increment")
	_assert_eq(w.migration_status, "arrived", "Status must be arrived")

	var newcomer: CitizenState = w.citizens[w.citizens.size() - 1]
	_assert_eq(newcomer.role_id, &"unassigned", "Newcomer must start unassigned")
	_assert(newcomer.species_id in SpeciesCatalog.SPECIES_IDS, "Newcomer species must be valid")
	_assert_eq(newcomer.social_status_id, SocialClassCatalog.DEFAULT_STATUS_ID, "Newcomer must be commoner")
	_assert(newcomer.home_building_id > 0, "Newcomer must immediately receive an active home")

	var home: BuildingState = w._find_building_by_entity_id(newcomer.home_building_id)
	_assert(home != null and home.is_residential(), "Home must be an active residential building")

	# Chronicle entry must exist
	var found_chronicle: bool = false
	for ev in w.event_log.events:
		if "immigrated to Crownweft" in ev.get("message", ""):
			found_chronicle = true
			break
	_assert(found_chronicle, "Chronicle must record immigration event")

	_cleanup_world(w)
	print("✓ Test 6: Migration arrival and newcomer attributes PASSED\n")

func test_7_save_load_round_trip_preservation() -> void:
	print(">> Test 7: Save/load round-trip determinism")
	var w: WorldScene = _create_headless_world()

	for i in range(3):
		w.place_building(&"house", Vector2i(25, 20 + i * 3), true)
	w._update_housing_and_rest()
	var town_hall: BuildingState = w.buildings[0]
	town_hall.inventory.add_resource(&"bread", 80, "TEST")
	w.migration_progress = 42.5
	w.migration_status = "attracting"
	w.migration_block_reason = ""
	w.total_migrants_arrived = 3

	var save_path: String = "user://test_residential_save.json"
	var saved: bool = w.save_game(save_path)
	_assert(saved, "Save must succeed")

	# Create new world and load
	var w2: WorldScene = _create_headless_world()
	var loaded: bool = w2.load_game(save_path)
	_assert(loaded, "Load must succeed")

	_assert_eq(w2.migration_progress, 42.5, "Migration progress preserved")
	_assert_eq(w2.migration_status, "attracting", "Migration status preserved")
	_assert_eq(w2.migration_block_reason, "", "Block reason preserved")
	_assert_eq(w2.total_migrants_arrived, 3, "Total migrants count preserved")
	_assert_eq(w2.get_total_housing_capacity(), 15, "Housing capacity preserved")
	_assert_eq(w2.get_housed_citizens_count(), w.get_housed_citizens_count(), "Housed count preserved")

	# Invariant checker
	var inv_check: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
		w2.world_state, w2.buildings, w2.citizens, w2.job_board,
		w2.logistics, w2.pathfinding, w2.economy, w2.government,
		w2.diplomacy, w2.regional_world
	)
	_assert(inv_check.passed, "0 invariant violations after save/load: %s" % inv_check.summary())

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	_cleanup_world(w)
	_cleanup_world(w2)
	print("✓ Test 7: Save/load round-trip determinism PASSED\n")

func test_8_scenario_compatibility_and_zero_start_migration() -> void:
	print(">> Test 8: Compatibility across all 3 scenarios")

	var scenarios: Array[StringName] = [
		ScenarioCatalog.SCENARIO_FOUNDING,
		ScenarioCatalog.SCENARIO_BORDER_MARCH,
		ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS
	]

	for scn_id in scenarios:
		var w: WorldScene = _create_headless_world(scn_id)
		# All scenarios must start with 0 housing capacity and 0 migration
		_assert_eq(w.get_total_housing_capacity(), 0, "%s must start with 0 housing capacity" % scn_id)
		_assert_eq(w.migration_status, "blocked", "%s migration must be blocked at start" % scn_id)
		_assert_eq(w.migration_block_reason, "No vacant housing available in settlement.", "%s reason correct" % scn_id)
		_assert_eq(w.total_migrants_arrived, 0, "%s starts with 0 arrivals" % scn_id)

		# Run 20 simulation ticks
		for t in range(20):
			w._simulation_tick()

		# Zero unintended migration
		_assert_eq(w.total_migrants_arrived, 0, "%s must have zero unwanted migration without houses" % scn_id)
		_assert_eq(w.migration_status, "blocked", "%s migration remains blocked" % scn_id)

		var inv_check: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
			w.world_state, w.buildings, w.citizens, w.job_board,
			w.logistics, w.pathfinding, w.economy, w.government,
			w.diplomacy, w.regional_world
		)
		_assert(inv_check.passed, "0 violations for %s post-ticks: %s" % [scn_id, inv_check.summary()])
		_cleanup_world(w)

	print("✓ Test 8: Compatibility across all 3 scenarios PASSED\n")
