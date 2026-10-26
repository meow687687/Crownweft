extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestLongRunningSimulation (Task 17) ---")
	print("=======================================================")
	test_long_running_simulation_stability()
	
	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestLongRunningSimulation PASSED ---")
	else:
		print("!! TestLongRunningSimulation FAILED with %d assertion errors" % _tests_failed)
	print("=======================================================")
	quit(_tests_failed)

func _assert(condition: bool, message: String) -> void:
	_tests_run += 1
	if not condition:
		_tests_failed += 1
		printerr("Assertion failed: %s" % message)
	else:
		_tests_passed += 1

func test_long_running_simulation_stability() -> void:
	var world_scene_res = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_scene_res.instantiate()
	world._init_simulation()

	# Ensure base infrastructure
	var town_hall: BuildingState = null
	for b in world.buildings:
		if b.definition_id == &"town_hall":
			town_hall = b
			break
	_assert(town_hall != null, "Town Hall must exist")

	# Add starting supplies to town hall
	town_hall.inventory.add_resource(&"coin", 200, "starting_stock")
	town_hall.inventory.add_resource(&"grain", 100, "starting_stock")
	town_hall.inventory.add_resource(&"bread", 100, "starting_stock")
	town_hall.inventory.add_resource(&"timber", 150, "starting_stock")
	town_hall.inventory.add_resource(&"stone", 100, "starting_stock")

	var origin: Vector2i = world.world_state.start_settlement_pos

	# Place and construct a Farm
	var farm_pos: Vector2i = origin + Vector2i(4, 0)
	var farm: BuildingState = world.place_building(&"farm", farm_pos, true)
	_assert(farm != null, "Farm registered")
	farm.status = BuildingState.Status.ACTIVE

	# Place and construct a Bakery
	var bakery_pos: Vector2i = origin + Vector2i(4, 5)
	var bakery: BuildingState = world.place_building(&"bakery", bakery_pos, true)
	_assert(bakery != null, "Bakery registered")
	bakery.status = BuildingState.Status.ACTIVE

	# Assign workers
	if world.citizens.size() >= 3:
		farm.assigned_workers = 1
		world.citizens[1].workplace_id = farm.entity_id
		world.citizens[1].role_id = &"farmer"

		bakery.assigned_workers = 1
		world.citizens[2].workplace_id = bakery.entity_id
		world.citizens[2].role_id = &"baker"

	# Set rest threshold so workers naturally rest and recover
	for c in world.citizens:
		c.is_resting = false
		c.energy = 90.0

	var total_ticks: int = 2400
	var checkpoint_interval: int = 300
	var checkpoints_passed: int = 0

	print("Beginning 2,400-tick long-running simulation...")

	for tick in range(1, total_ticks + 1):
		world._simulation_tick()

		# Periodic Invariant & Economic Audits every 300 ticks
		if tick % checkpoint_interval == 0:
			var audit: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
				world.world_state,
				world.buildings,
				world.citizens,
				world.job_board,
				world.logistics,
				world.pathfinding,
				world.economy,
				world.government,
				world.diplomacy,
				world.regional_world
			)

			if not audit.passed:
				_assert(false, "Invariant audit failed at tick %d:\n%s" % [tick, audit.format()])
			else:
				checkpoints_passed += 1

			# Economic & Population health checks
			var total_bread: int = 0
			var total_grain: int = 0
			var total_coins: int = 0
			for b in world.buildings:
				total_bread += b.inventory.get_quantity(&"bread")
				total_grain += b.inventory.get_quantity(&"grain")
				total_coins += b.inventory.get_quantity(&"coin")

			var avg_energy: float = 0.0
			for c in world.citizens:
				avg_energy += c.energy
				_assert(c.energy >= 0.0 and c.energy <= 100.0, "Citizen energy in [0, 100] at tick %d" % tick)
				_assert(world.world_state.is_valid_coord(c.position_tile), "Citizen coords valid at tick %d" % tick)
			avg_energy /= maxf(1.0, float(world.citizens.size()))

			print("  [Checkpoint %d/8 @ Tick %d] %s | Bread: %d | Grain: %d | Coins: %d | Avg Energy: %.1f | Jobs: %d" % [
				checkpoints_passed, tick, audit.summary(), total_bread, total_grain, total_coins, avg_energy, world.job_board.jobs.size()
			])

	_assert(checkpoints_passed == 8, "All 8 audit checkpoints (2,400 ticks) passed without violation")
	_assert(world.current_tick >= 2400, "Simulation reached tick 2,400")
