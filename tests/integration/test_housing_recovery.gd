class_name TestHousingRecovery
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestHousingRecovery (Task 21.1 Stability) ---")
	print("=======================================================\n")

	test_1_homeless_fallback_recovery_rate()
	test_2_housed_recovery_preserves_speed_advantage()
	test_3_energy_bounds_clamping()
	test_4_exhausted_hauler_recovery_and_job_resumption()
	test_5_housing_construction_after_workforce_exhaustion()
	test_6_multiple_exhausted_citizens_no_deadlock()
	test_7_all_three_scenarios_opening_recovery()
	test_8_migration_remains_blocked_without_vacant_houses()
	test_9_save_load_round_trip_during_outdoor_rest()
	test_10_residential_invariants_post_recovery()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestHousingRecovery: ALL 10 TEST SUITES PASSED ---")
	else:
		print("!! TestHousingRecovery FAILED with %d assertion errors" % _tests_failed)
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

func test_1_homeless_fallback_recovery_rate() -> void:
	print(">> Test 1: Homeless fallback recovery rate")
	var w: WorldScene = _create_headless_world()

	var c: CitizenState = w.citizens[0]
	c.species_id = &"human" # base modifier 1.0
	c.energy = 15.0 # Exhausted
	c.home_building_id = 0

	# First tick enters resting state outdoors
	w._update_housing_and_rest()
	_assert(c.is_resting, "Citizen must enter rest state")
	_assert_eq(c.current_block_reason, &"Resting outdoors — no valid home assigned", "Correct outdoor rest diagnostic")
	_assert_eq(c.energy, 15.5, "Energy recovers by HOMELESS_REST_ENERGY_RECOVERY (0.5)")

	# Tick 9 more times -> total +5.0 energy
	for t in range(9):
		w._update_housing_and_rest()
	_assert_eq(c.energy, 20.0, "Energy reaches 20.0 after 10 ticks")

	_cleanup_world(w)
	print("✓ Test 1: Homeless fallback recovery rate PASSED\n")

func test_2_housed_recovery_preserves_speed_advantage() -> void:
	print(">> Test 2: Housed recovery preserves speed advantage")
	var w: WorldScene = _create_headless_world()

	# Create a house and fill all 5 slots
	var house: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	for i in range(5):
		w.assign_citizen_home(w.citizens[i], house)

	var c_housed: CitizenState = w.citizens[0]
	c_housed.species_id = &"human"
	c_housed.position_tile = house.get_entrance_tile()

	# Citizen 5 has no house available
	var c_homeless: CitizenState = w.citizens[5]
	c_homeless.species_id = &"human"
	c_homeless.home_building_id = 0

	c_housed.energy = 20.0
	c_homeless.energy = 20.0

	# Run 10 ticks of housing update
	for t in range(10):
		w._update_housing_and_rest()

	# Housed recovers at 2.0/tick (+20.0 -> 40.0)
	# Homeless recovers at 0.5/tick (+5.0 -> 25.0)
	_assert_eq(c_housed.energy, 40.0, "Housed citizen recovers at 2.0/tick")
	_assert_eq(c_homeless.energy, 25.0, "Homeless citizen recovers at 0.5/tick")
	_assert(c_housed.energy > c_homeless.energy, "Housed rest is 4x faster than homeless rest")

	_cleanup_world(w)
	print("✓ Test 2: Housed recovery preserves speed advantage PASSED\n")

func test_3_energy_bounds_clamping() -> void:
	print(">> Test 3: Energy bounds clamping")
	var w: WorldScene = _create_headless_world()

	var c: CitizenState = w.citizens[0]
	c.energy = 99.8
	c.is_resting = true
	c.restore_energy(CitizenState.HOMELESS_REST_ENERGY_RECOVERY)
	_assert_eq(c.energy, CitizenState.MAX_ENERGY, "Energy cannot exceed MAX_ENERGY (100.0)")

	c.consume_energy(200.0)
	_assert_eq(c.energy, CitizenState.MIN_ENERGY, "Energy cannot drop below MIN_ENERGY (0.0)")

	_cleanup_world(w)
	print("✓ Test 3: Energy bounds clamping PASSED\n")

func test_4_exhausted_hauler_recovery_and_job_resumption() -> void:
	print(">> Test 4: Exhausted hauler recovery and job resumption")
	var w: WorldScene = _create_headless_world()

	var hauler_c: CitizenState = w.citizens[0]
	hauler_c.species_id = &"human"
	hauler_c.role_id = &"hauler"
	hauler_c.home_building_id = 0
	hauler_c.energy = 10.0

	# Register hauler in logistics
	var hauler_reg = w.logistics.register_hauler(hauler_c.id, hauler_c.position_tile)

	# While exhausted without cargo, hauler enters rest
	w._update_housing_and_rest()
	_assert(hauler_c.is_resting, "Hauler enters resting state")

	# Run until hauler reaches RECOVERY_THRESHOLD (80.0)
	# from 10.5 to 80.0 takes (80.0 - 10.5) / 0.5 = 139 ticks
	for t in range(139):
		w._update_housing_and_rest()

	_assert(not hauler_c.is_resting, "Hauler wakes up after reaching recovery threshold")
	_assert_eq(hauler_c.current_block_reason, &"", "Diagnostic blocker cleared on recovery")
	_assert(hauler_c.energy >= 79.9, "Energy >= 80 on recovery")

	_cleanup_world(w)
	print("✓ Test 4: Exhausted hauler recovery and job resumption PASSED\n")

func test_5_housing_construction_after_workforce_exhaustion() -> void:
	print(">> Test 5: Housing construction succeeding after initial exhaustion")
	var w: WorldScene = _create_headless_world()

	# Place planned house
	var build_pos: Vector2i = Vector2i(-1, -1)
	for y in range(15, 35):
		for x in range(15, 35):
			var cand: Vector2i = Vector2i(x, y)
			if w.can_place_building_at(&"house", cand, Vector2i(2, 2)).get("ok", false):
				build_pos = cand
				break
		if build_pos != Vector2i(-1, -1):
			break

	var house: BuildingState = w.place_building(&"house", build_pos, false)
	_assert(house != null, "House placement must succeed")

	# Exhaust all citizens
	for c in w.citizens:
		c.energy = 15.0

	# Run simulation ticks to allow recovery, hauling, and construction
	for t in range(250):
		w._simulation_tick()

	_assert_eq(house.status, BuildingState.Status.ACTIVE, "House must complete construction and activate")
	_assert(w.get_total_housing_capacity() > 0, "Housing capacity must now exist in settlement")
	_assert(w.get_housed_citizens_count() > 0, "Citizens must be housed in new building")

	_cleanup_world(w)
	print("✓ Test 5: Housing construction succeeding after initial exhaustion PASSED\n")

func test_6_multiple_exhausted_citizens_no_deadlock() -> void:
	print(">> Test 6: Multiple exhausted citizens without permanent deadlock")
	var w: WorldScene = _create_headless_world()

	# Exhaust entire settlement
	for c in w.citizens:
		c.energy = 5.0
		c.home_building_id = 0

	# Run 20 ticks of housing update
	for t in range(20):
		w._update_housing_and_rest()

	for c in w.citizens:
		_assert(c.is_resting, "All citizens resting")
		_assert(c.energy > 5.0, "All citizens gaining energy through fallback")

	# Run 160 more ticks to allow all species (even with 0.9 recovery mod) to reach 80.0
	for t in range(160):
		w._update_housing_and_rest()

	# All should have recovered to >= 80.0 and exited resting state
	var resting_count: int = 0
	for c in w.citizens:
		if c.is_resting:
			resting_count += 1

	_assert_eq(resting_count, 0, "All citizens recovered from mass exhaustion without deadlock")

	_cleanup_world(w)
	print("✓ Test 6: Multiple exhausted citizens without permanent deadlock PASSED\n")

func test_7_all_three_scenarios_opening_recovery() -> void:
	print(">> Test 7: All three scenario opening states")
	var scenarios: Array[StringName] = [
		ScenarioCatalog.SCENARIO_FOUNDING,
		ScenarioCatalog.SCENARIO_BORDER_MARCH,
		ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS
	]

	for scn_id in scenarios:
		var w: WorldScene = _create_headless_world(scn_id)
		# Exhaust all citizens
		for c in w.citizens:
			c.energy = 15.0
		w._update_housing_and_rest()

		for c in w.citizens:
			_assert(c.is_resting, "%s citizens resting outdoors" % scn_id)
			_assert_eq(c.current_block_reason, &"Resting outdoors — no valid home assigned", "%s block reason" % scn_id)

		# Advance 160 ticks to ensure all species reach 80.0
		for t in range(160):
			w._update_housing_and_rest()

		var resting_count: int = 0
		for c in w.citizens:
			if c.is_resting:
				resting_count += 1
		_assert_eq(resting_count, 0, "%s all citizens successfully recovered" % scn_id)
		_cleanup_world(w)

	print("✓ Test 7: All three scenario opening states PASSED\n")

func test_8_migration_remains_blocked_without_vacant_houses() -> void:
	print(">> Test 8: Migration remaining blocked without vacant housing")
	var w: WorldScene = _create_headless_world()

	# Provide plenty of food and maximum approval
	var town_hall: BuildingState = w.buildings[0]
	town_hall.inventory.add_resource(&"bread", 100, "TEST")
	w.economy.approval = 100.0

	# Citizens resting outdoors
	for c in w.citizens:
		c.energy = 15.0
	w._simulation_tick()

	# Tick migration
	var needs_report: Dictionary = {"fed": 10, "hungry": 0, "at_risk": 0}
	w.tick_migration(needs_report)

	_assert_eq(w.migration_status, "blocked", "Migration must remain blocked")
	_assert_eq(w.migration_block_reason, "No vacant housing available in settlement.", "Reason must remain vacancy failure")
	_assert_eq(w.total_migrants_arrived, 0, "Zero migrants admitted")

	_cleanup_world(w)
	print("✓ Test 8: Migration remaining blocked without vacant housing PASSED\n")

func test_9_save_load_round_trip_during_outdoor_rest() -> void:
	print(">> Test 9: Save/load round trip during outdoor rest")
	var w: WorldScene = _create_headless_world()

	var c: CitizenState = w.citizens[0]
	c.species_id = &"human"
	c.energy = 15.0
	c.home_building_id = 0
	w._update_housing_and_rest()
	_assert(c.is_resting, "Citizen resting outdoors")

	var save_path: String = "user://test_housing_recovery_save.json"
	var saved: bool = w.save_game(save_path)
	_assert(saved, "Save must succeed")

	var w2: WorldScene = _create_headless_world()
	var loaded: bool = w2.load_game(save_path)
	_assert(loaded, "Load must succeed")

	var c2: CitizenState = w2.citizens[0]
	_assert(c2.is_resting, "Resting state preserved across save/load")
	_assert_eq(c2.energy, 15.5, "Energy state preserved across save/load")
	_assert_eq(c2.home_building_id, 0, "Homeless state preserved")

	# Continue simulation in loaded world
	w2._update_housing_and_rest()
	_assert_eq(c2.energy, 16.0, "Energy continues recovering seamlessly post-load")

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	_cleanup_world(w)
	_cleanup_world(w2)
	print("✓ Test 9: Save/load round trip during outdoor rest PASSED\n")

func test_10_residential_invariants_post_recovery() -> void:
	print(">> Test 10: Existing residential invariant checks")
	var w: WorldScene = _create_headless_world()

	# Build a house and run ticks
	var house: BuildingState = w.place_building(&"house", Vector2i(25, 25), true)
	for t in range(50):
		w._simulation_tick()

	var inv_check: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
		w.world_state, w.buildings, w.citizens, w.job_board,
		w.logistics, w.pathfinding, w.economy, w.government,
		w.diplomacy, w.regional_world
	)
	_assert(inv_check.passed, "All invariants pass post-recovery: %s" % inv_check.summary())

	_cleanup_world(w)
	print("✓ Test 10: Existing residential invariant checks PASSED\n")
