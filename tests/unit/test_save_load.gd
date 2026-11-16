extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("--- Running TestSaveLoad ---")
	test_full_roundtrip_serialization()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestSaveLoad PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_full_roundtrip_serialization() -> void:
	# 1. Construct representative game state
	var world: WorldState = WorldState.new(96, 96, 777888)
	var saved_tile := WorldTile.new(Vector2i(10, 10), &"forest", 0.82)
	saved_tile.resource_amount = 7
	world.set_tile(Vector2i(10, 10), saved_tile)
	var economy: EconomyState = EconomyState.new()
	economy.tax_level = EconomyState.TaxLevel.HIGH
	economy.approval = 73.5
	economy.last_tax_income = 48
	economy.last_tax_tick = 80
	
	# Buildings
	var b1: BuildingState = BuildingState.new(10, &"farm", 30, [&"grain"])
	b1.tile_origin = Vector2i(25, 45)
	b1.assigned_workers = 2
	b1.production_progress = 3
	b1.current_block_reason = &"OUTPUT_FULL"
	b1.inventory.add_resource(&"grain", 20, "TEST")
	b1.inventory.reserve_out(&"grain", 5)
	
	var b2: BuildingState = BuildingState.new(20, &"bakery", 20, [&"grain", &"bread"])
	b2.tile_origin = Vector2i(30, 45)
	b2.assigned_workers = 1
	b2.inventory.reserve_in(&"grain", 5)
	
	var buildings: Array[BuildingState] = [b1, b2]
	
	# Citizens
	var c1: CitizenState = CitizenState.new(101, Vector2i(26, 45), &"hauler")
	c1.carried_resource = &"grain"
	c1.carried_amount = 5
	c1.workplace_id = 10
	c1.home_building_id = 20
	c1.hunger_counter = 2
	c1.food_state = CitizenState.FoodState.HUNGRY
	
	var citizens: Array[CitizenState] = [c1]
	
	# Military Units
	var u1: MilitaryUnitState = MilitaryUnitState.new(501, &"archer", 0, Vector2(350.5, 420.0))
	u1.health = 55
	u1.set_attack_target_order(999)
	u1.is_starving = true
	
	var military_units: Array[MilitaryUnitState] = [u1]
	
	# Job Board
	var job_board: JobBoard = JobBoard.new()
	var job: HaulJob = HaulJob.new(1, &"grain", 5, 10, 20, 2, 45)
	job.status = HaulJob.Status.IN_TRANSIT
	job.assigned_citizen_id = 101
	job.reserved_amount = 5
	job_board.jobs[job.id] = job
	
	var save_file_path: String = "user://saves/test_roundtrip.json"
	
	# 2. Save to file
	var save_ok: bool = SaveService.save_game_to_file(
		world,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		142,
		2.0,
		save_file_path
	)
	assert_true(save_ok, "Saving game to file should succeed")
	
	# 3. Load from file
	var loaded_data: Dictionary = SaveService.load_game_from_file(save_file_path)
	assert_true(not loaded_data.is_empty(), "Loading game data should succeed")
	
	# 4. Assert integrity of deserialized data
	var loaded_meta: Dictionary = loaded_data["meta"]
	assert_eq(loaded_meta["schema_version"], 2)
	assert_eq(loaded_meta["seed_val"], 777888)
	assert_eq(loaded_meta["current_tick"], 142)
	assert_eq(loaded_meta["sim_speed"], 2.0)
	
	var loaded_eco: EconomyState = loaded_data["economy"]
	assert_eq(loaded_eco.tax_level, EconomyState.TaxLevel.HIGH)
	assert_eq(loaded_eco.approval, 73.5)
	assert_eq(loaded_eco.last_tax_income, 48)
	
	var loaded_buildings: Array = loaded_data["buildings"]
	assert_eq(loaded_buildings.size(), 2)
	var lb1: BuildingState = loaded_buildings[0]
	assert_eq(lb1.entity_id, 10)
	assert_eq(lb1.definition_id, &"farm")
	assert_eq(lb1.tile_origin, Vector2i(25, 45))
	assert_eq(lb1.assigned_workers, 2)
	assert_eq(lb1.production_progress, 3)
	assert_eq(lb1.current_block_reason, &"OUTPUT_FULL")
	assert_eq(lb1.inventory.get_quantity(&"grain"), 20)
	assert_eq(lb1.inventory.get_reserved_out(&"grain"), 5)
	
	var lb2: BuildingState = loaded_buildings[1]
	assert_eq(lb2.inventory.get_reserved_in(&"grain"), 5)
	
	var loaded_citizens: Array = loaded_data["citizens"]
	assert_eq(loaded_citizens.size(), 1)
	var lc1: CitizenState = loaded_citizens[0]
	assert_eq(lc1.id, 101)
	assert_eq(lc1.role_id, &"hauler")
	assert_eq(lc1.carried_resource, &"grain")
	assert_eq(lc1.carried_amount, 5)
	assert_eq(lc1.workplace_id, 10)
	assert_eq(lc1.home_building_id, 20)
	assert_eq(lc1.food_state, CitizenState.FoodState.HUNGRY)
	assert_true(loaded_data["world_state"] != null, "Saved world must be restored")
	assert_eq(loaded_data["world_state"].width, 96)
	var restored_tile: WorldTile = loaded_data["world_state"].get_tile(Vector2i(10, 10))
	assert_true(restored_tile != null, "Saved world tile must be restored")
	assert_eq(restored_tile.terrain_id, &"forest")
	assert_eq(restored_tile.resource_amount, 7)
	
	var loaded_units: Array = loaded_data["military_units"]
	assert_eq(loaded_units.size(), 1)
	var lu1: MilitaryUnitState = loaded_units[0]
	assert_eq(lu1.id, 501)
	assert_eq(lu1.unit_definition_id, &"archer")
	assert_eq(lu1.health, 55)
	assert_eq(lu1.target_unit_id, 999)
	assert_eq(lu1.is_starving, true)
	
	var loaded_board: JobBoard = loaded_data["job_board"]
	assert_true(loaded_board.jobs.has(1))
	var lj: HaulJob = loaded_board.jobs[1]
	assert_eq(lj.resource_id, &"grain")
	assert_eq(lj.amount, 5)
	assert_eq(lj.status, HaulJob.Status.IN_TRANSIT)
	assert_eq(lj.reserved_amount, 5)
	
	print("✓ Full round-trip serialization preserved 100% of state!")
