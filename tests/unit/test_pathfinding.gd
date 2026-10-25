extends SceneTree

func _init() -> void:
	print("--- Running TestPathfinding ---")
	test_obstacle_avoidance()
	test_adjacent_routing_for_buildings()
	test_road_path_preference()
	print("--- TestPathfinding PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_obstacle_avoidance() -> void:
	var pf: PathfindingService = PathfindingService.new(20, 20)
	
	# Place a wall blocking direct line from (5,5) to (5,8)
	pf.set_solid(Vector2i(5, 6), true)
	pf.set_solid(Vector2i(4, 6), true)
	pf.set_solid(Vector2i(6, 6), true)
	
	var path: Array[Vector2i] = pf.find_path(Vector2i(5, 5), Vector2i(5, 8))
	assert_true(not path.is_empty(), "Should navigate around wall")
	for pt in path:
		assert_true(pt != Vector2i(5, 6) and pt != Vector2i(4, 6) and pt != Vector2i(6, 6), "Path must not cross solid wall")

func test_adjacent_routing_for_buildings() -> void:
	var pf: PathfindingService = PathfindingService.new(20, 20)
	
	# Place a building at (10, 10) and mark it solid
	var b_pos: Vector2i = Vector2i(10, 10)
	pf.set_solid(b_pos, true)
	
	# Routing directly to solid tile should be empty
	var direct_path: Array[Vector2i] = pf.find_path(Vector2i(5, 10), b_pos)
	assert_true(direct_path.is_empty(), "Direct path to solid building should fail")
	
	# Routing to adjacent should succeed and end next to the building
	var adj_path: Array[Vector2i] = pf.find_path_to_adjacent(Vector2i(5, 10), b_pos)
	assert_true(not adj_path.is_empty(), "Adjacent path must find route")
	var end_pt: Vector2i = adj_path[-1]
	var dist: int = absi(end_pt.x - b_pos.x) + absi(end_pt.y - b_pos.y)
	assert_eq(dist, 1, "Destination of adjacent path must be adjacent to building")

func test_road_path_preference() -> void:
	var pf: PathfindingService = PathfindingService.new(10, 10)
	# Build a road along row y=5 from x=2 to x=8
	for x in range(2, 9):
		pf.set_road(Vector2i(x, 5), true)
		
	var path: Array[Vector2i] = pf.find_path(Vector2i(2, 5), Vector2i(8, 5))
	assert_true(not path.is_empty())
	assert_eq(path.size(), 7, "Direct road corridor of 7 tiles")
