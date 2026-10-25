extends SceneTree

func _init() -> void:
	print("--- Running TestWorldGen ---")
	test_seed_determinism()
	test_starter_area_guarantees_and_connectivity()
	print("--- TestWorldGen PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_seed_determinism() -> void:
	var gen: WorldGenerationService = WorldGenerationService.new()
	var w1: WorldState = gen.generate_world(4242)
	var w2: WorldState = gen.generate_world(4242)
	
	assert_eq(w1.width, 96)
	assert_eq(w1.height, 96)
	assert_eq(w1.seed_val, w2.seed_val)
	assert_eq(w1.start_settlement_pos, w2.start_settlement_pos)
	assert_eq(w1.raider_camp_pos, w2.raider_camp_pos)
	
	# Sample tiles across map
	var sample_coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(10, 10), Vector2i(28, 48), Vector2i(50, 50), Vector2i(78, 20), Vector2i(95, 95)
	]
	for c in sample_coords:
		var t1: WorldTile = w1.get_tile(c)
		var t2: WorldTile = w2.get_tile(c)
		assert_eq(t1.terrain_id, t2.terrain_id, "Tiles at %s must match exactly for same seed" % str(c))
		assert_eq(t1.fertility, t2.fertility, "Fertility at %s must match exactly" % str(c))

func test_starter_area_guarantees_and_connectivity() -> void:
	var gen: WorldGenerationService = WorldGenerationService.new()
	var seeds_to_test: Array[int] = [123, 777, 9999]
	
	for s in seeds_to_test:
		var w: WorldState = gen.generate_world(s)
		
		# Start tile must be buildable grass
		var start_tile: WorldTile = w.get_tile(w.start_settlement_pos)
		assert_true(start_tile.is_buildable, "Settlement start must be buildable")
		assert_eq(start_tile.terrain_id, &"grass")
		
		# Pathfinding connectivity between settlement and raider camp
		var pf: PathfindingService = PathfindingService.new(w.width, w.height)
		pf.initialize_from_world(w)
		var path: Array[Vector2i] = pf.find_path(w.start_settlement_pos, w.raider_camp_pos)
		assert_true(not path.is_empty(), "Raider camp must be reachable from settlement for seed %d" % s)
		assert_true(path.size() >= 15, "Raider camp should be sufficiently far from start")
