extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

const TEST_SAVE_PATH: String = "user://saves/test_determinism.json"

func _init() -> void:
	print("\n==========================================================")
	print("--- Running TestSaveLoadDeterminism (Task 17) ---")
	print("==========================================================")

	test_save_load_determinism()

	print("\n==========================================================")
	if _tests_failed == 0:
		print("--- TestSaveLoadDeterminism PASSED ---")
	else:
		print("!! TestSaveLoadDeterminism FAILED with %d assertion errors" % _tests_failed)
	print("==========================================================")
	quit(_tests_failed)

func _assert(cond: bool, msg: String) -> void:
	_tests_run += 1
	if not cond:
		_tests_failed += 1
		printerr("Assertion failed: ", msg)
	else:
		_tests_passed += 1

func _assert_eq(a, b, msg: String) -> void:
	_tests_run += 1
	if a != b:
		_tests_failed += 1
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
	else:
		_tests_passed += 1

func _take_world_snapshot(world: WorldScene) -> Dictionary:
	var snap: Dictionary = {}
	snap["current_tick"] = world.current_tick

	# Inventories
	var inv_summary: Dictionary = {}
	for b in world.buildings:
		var counts: Dictionary = {}
		for res in [&"coin", &"grain", &"bread", &"timber", &"stone"]:
			counts[res] = b.inventory.get_quantity(res)
		inv_summary[b.entity_id] = counts
	snap["inventories"] = inv_summary

	# Citizens
	var cit_summary: Dictionary = {}
	for c in world.citizens:
		cit_summary[c.id] = {
			"role": c.role_id,
			"workplace": c.workplace_id,
			"energy": snappedf(c.energy, 0.01),
			"pos": c.position_tile
		}
	snap["citizens"] = cit_summary

	# Economy
	snap["approval"] = snappedf(world.economy.approval, 0.01)
	snap["tax_level"] = world.economy.tax_level

	# Government
	snap["policies"] = world.government.enacted_policies.duplicate()

	# Regional Armies
	var army_summary: Dictionary = {}
	if world.regional_world != null:
		for a in world.regional_world.armies.values():
			army_summary[a.id] = {
				"region": a.current_region_id,
				"status": a.status,
				"grain": snappedf(a.supplies.get(&"grain", 0.0), 0.01)
			}
	snap["armies"] = army_summary

	return snap

func test_save_load_determinism() -> void:
	print("Phase 1: Setting up initial settlement for continuous Run A...")
	var world_a_res = load("res://scenes/world/world.tscn")
	var world_a: WorldScene = world_a_res.instantiate()
	world_a._init_simulation()

	var origin: Vector2i = world_a.world_state.start_settlement_pos
	var th: BuildingState = world_a.buildings[0]
	th.inventory.add_resource(&"coin", 200, "init")
	th.inventory.add_resource(&"grain", 50, "init")
	th.inventory.add_resource(&"timber", 60, "init")
	th.inventory.add_resource(&"stone", 40, "init")

	var farm: BuildingState = world_a.place_building(&"farm", origin + Vector2i(4, 0), true)
	farm.status = BuildingState.Status.ACTIVE
	farm.assigned_workers = 1
	world_a.citizens[2].workplace_id = farm.entity_id
	world_a.citizens[2].role_id = &"farmer"

	print("Phase 2: Advancing Run A from Tick 0 to Tick 100...")
	for t in range(100):
		world_a._simulation_tick()

	_assert_eq(world_a.current_tick, 100, "Run A reached Tick 100")

	print("Phase 3: Saving state at Tick 100 to %s..." % TEST_SAVE_PATH)
	var save_ok: bool = world_a.save_game(TEST_SAVE_PATH)
	_assert(save_ok, "Save file written successfully at Tick 100")

	print("Phase 4: Continuing Run A uninterrupted from Tick 100 to Tick 250...")
	for t in range(150):
		world_a._simulation_tick()

	_assert_eq(world_a.current_tick, 250, "Run A reached Tick 250")
	var snap_a: Dictionary = _take_world_snapshot(world_a)

	var audit_a = SimulationInvariantChecker.audit(
		world_a.world_state, world_a.buildings, world_a.citizens, world_a.job_board,
		world_a.logistics, world_a.pathfinding, world_a.economy, world_a.government,
		world_a.diplomacy, world_a.regional_world
	)
	_assert(audit_a.passed, "Run A passes all invariants at Tick 250: " + audit_a.summary())

	print("Phase 5: Instantiating Run B and loading state from Tick 100 save...")
	var world_b_res = load("res://scenes/world/world.tscn")
	var world_b: WorldScene = world_b_res.instantiate()
	world_b._init_simulation()

	var load_ok: bool = world_b.load_game(TEST_SAVE_PATH)
	_assert(load_ok, "Run B loaded state successfully")
	_assert_eq(world_b.current_tick, 100, "Run B resumed exactly at Tick 100")

	print("Phase 6: Advancing Run B from Tick 100 to Tick 250 (150 ticks)...")
	for t in range(150):
		world_b._simulation_tick()

	_assert_eq(world_b.current_tick, 250, "Run B reached Tick 250")
	var snap_b: Dictionary = _take_world_snapshot(world_b)

	var audit_b = SimulationInvariantChecker.audit(
		world_b.world_state, world_b.buildings, world_b.citizens, world_b.job_board,
		world_b.logistics, world_b.pathfinding, world_b.economy, world_b.government,
		world_b.diplomacy, world_b.regional_world
	)
	_assert(audit_b.passed, "Run B passes all invariants at Tick 250: " + audit_b.summary())

	print("Phase 7: Verifying Deterministic Equivalence between Run A and Run B...")
	_assert_eq(snap_a["current_tick"], snap_b["current_tick"], "Current tick matches")
	_assert_eq(snap_a["approval"], snap_b["approval"], "Communal approval matches: %s vs %s" % [str(snap_a["approval"]), str(snap_b["approval"])])
	_assert_eq(snap_a["tax_level"], snap_b["tax_level"], "Tax level matches")
	_assert_eq(snap_a["policies"], snap_b["policies"], "Enacted policies match")

	# Compare inventories
	var inv_a: Dictionary = snap_a["inventories"]
	var inv_b: Dictionary = snap_b["inventories"]
	_assert_eq(inv_a.keys().size(), inv_b.keys().size(), "Same number of building inventories")
	for b_id in inv_a:
		_assert(inv_b.has(b_id), "Building %s present in both runs" % str(b_id))
		_assert_eq(inv_a[b_id], inv_b.get(b_id, {}), "Inventory stock identical for building %s" % str(b_id))

	# Compare citizens
	var cit_a: Dictionary = snap_a["citizens"]
	var cit_b: Dictionary = snap_b["citizens"]
	_assert_eq(cit_a.keys().size(), cit_b.keys().size(), "Same number of citizens")
	for c_id in cit_a:
		_assert(cit_b.has(c_id), "Citizen %s present in both runs" % str(c_id))
		_assert_eq(cit_a[c_id]["role"], cit_b[c_id]["role"], "Citizen %s role matches" % str(c_id))
		_assert_eq(cit_a[c_id]["workplace"], cit_b[c_id]["workplace"], "Citizen %s workplace matches" % str(c_id))
		_assert_eq(cit_a[c_id]["energy"], cit_b[c_id]["energy"], "Citizen %s energy matches: %s vs %s" % [str(c_id), str(cit_a[c_id]["energy"]), str(cit_b[c_id]["energy"])])

	# Compare regional armies
	_assert_eq(snap_a["armies"], snap_b["armies"], "Regional armies state identical")

	print("Deterministic equivalence verified between continuous run and reload continuation!")
