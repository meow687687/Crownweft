extends SceneTree

const RoadAutotiler = preload("res://scripts/presentation/road_autotiler.gd")

func _init() -> void:
	print("--- Running TestRoadAutotiling ---")
	test_all_16_neighbour_masks()
	test_horizontal_roads_both_directions()
	test_vertical_roads_both_directions()
	test_every_corner_and_t_junction_orientation()
	test_four_way_intersections()
	test_placing_road_updates_affected_neighbour_masks()
	test_removing_road_updates_neighbours()
	test_roads_near_every_map_edge_behave_safely()
	test_rendering_does_not_alter_logical_road_state()
	test_save_load_preserves_road_state_and_masks()
	test_pathfinding_and_entrance_integration_with_roads()
	print("--- TestRoadAutotiling PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

# Helper to build an empty grass world
func _create_empty_world(w: int = 20, h: int = 20) -> WorldState:
	var world := WorldState.new(w, h, 12345)
	for y in range(h):
		for x in range(w):
			var tile := WorldTile.new(Vector2i(x, y), &"grass", 0.5)
			world.set_tile(Vector2i(x, y), tile)
	return world

# Test 1: All 16 neighbour masks
func test_all_16_neighbour_masks() -> void:
	var world := _create_empty_world(10, 10)
	var center := Vector2i(5, 5)
	var north := Vector2i(5, 4)
	var east := Vector2i(6, 5)
	var south := Vector2i(5, 6)
	var west := Vector2i(4, 5)
	
	world.get_tile(center).road_level = 1
	
	# Mapping of bit values to expected combinations
	# North: 1, East: 2, South: 4, West: 8
	var expected_masks: Array[int] = [0, 1, 2, 4, 8, 5, 10, 3, 6, 12, 9, 7, 11, 13, 14, 15]
	
	for m in range(16):
		world.get_tile(north).road_level = 1 if ((m & 1) != 0) else 0
		world.get_tile(east).road_level = 1 if ((m & 2) != 0) else 0
		world.get_tile(south).road_level = 1 if ((m & 4) != 0) else 0
		world.get_tile(west).road_level = 1 if ((m & 8) != 0) else 0
		
		var computed_mask: int = RoadAutotiler.get_road_mask(world, center)
		assert_eq(computed_mask, m, "Mask for neighbours combination %d" % m)
		
		# Verify variant image generation
		var img: Image = RoadAutotiler.get_variant_image(m)
		assert_true(img != null, "Variant image for mask %d must not be null" % m)
		assert_eq(img.get_width(), 16, "Width must be 16")
		assert_eq(img.get_height(), 16, "Height must be 16")
		
	print("✓ Test 1: All 16 neighbour masks verified PASSED")

# Test 2: Horizontal roads built in both directions
func test_horizontal_roads_both_directions() -> void:
	var world := _create_empty_world(20, 20)
	
	# Left-to-right construction: (5, 5) -> (6, 5) -> (7, 5)
	world.get_tile(Vector2i(5, 5)).road_level = 1
	world.get_tile(Vector2i(6, 5)).road_level = 1
	world.get_tile(Vector2i(7, 5)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 5)), 2, "Left-to-right: Start is East endpoint (2)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(6, 5)), 10, "Left-to-right: Middle is Horizontal straight (10)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(7, 5)), 8, "Left-to-right: End is West endpoint (8)")
	
	# Right-to-left construction: (15, 8) -> (14, 8) -> (13, 8)
	world.get_tile(Vector2i(15, 8)).road_level = 1
	world.get_tile(Vector2i(14, 8)).road_level = 1
	world.get_tile(Vector2i(13, 8)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(13, 8)), 2, "Right-to-left: West tile is East endpoint (2)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(14, 8)), 10, "Right-to-left: Middle is Horizontal straight (10)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(15, 8)), 8, "Right-to-left: East tile is West endpoint (8)")
	print("✓ Test 2: Horizontal roads in both directions PASSED")

# Test 3: Vertical roads built in both directions
func test_vertical_roads_both_directions() -> void:
	var world := _create_empty_world(20, 20)
	
	# Top-to-bottom construction: (5, 5) -> (5, 6) -> (5, 7)
	world.get_tile(Vector2i(5, 5)).road_level = 1
	world.get_tile(Vector2i(5, 6)).road_level = 1
	world.get_tile(Vector2i(5, 7)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 5)), 4, "Top-to-bottom: Top tile is South endpoint (4)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 6)), 5, "Top-to-bottom: Middle is Vertical straight (5)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 7)), 1, "Top-to-bottom: Bottom tile is North endpoint (1)")
	
	# Bottom-to-top construction: (12, 15) -> (12, 14) -> (12, 13)
	world.get_tile(Vector2i(12, 15)).road_level = 1
	world.get_tile(Vector2i(12, 14)).road_level = 1
	world.get_tile(Vector2i(12, 13)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(12, 13)), 4, "Bottom-to-top: Top tile is South endpoint (4)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(12, 14)), 5, "Bottom-to-top: Middle is Vertical straight (5)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(12, 15)), 1, "Bottom-to-top: Bottom tile is North endpoint (1)")
	print("✓ Test 3: Vertical roads in both directions PASSED")

# Test 4: Every corner and T-junction orientation
func test_every_corner_and_t_junction_orientation() -> void:
	var world := _create_empty_world(20, 20)
	var c := Vector2i(10, 10)
	world.get_tile(c).road_level = 1
	
	var clear_neighbours := func():
		world.get_tile(Vector2i(10, 9)).road_level = 0
		world.get_tile(Vector2i(11, 10)).road_level = 0
		world.get_tile(Vector2i(10, 11)).road_level = 0
		world.get_tile(Vector2i(9, 10)).road_level = 0
	
	# Corners:
	# NE (North + East = 1 + 2 = 3)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 9)).road_level = 1
	world.get_tile(Vector2i(11, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 3, "NE corner mask must be 3")
	
	# SE (East + South = 2 + 4 = 6)
	clear_neighbours.call()
	world.get_tile(Vector2i(11, 10)).road_level = 1
	world.get_tile(Vector2i(10, 11)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 6, "SE corner mask must be 6")
	
	# SW (South + West = 4 + 8 = 12)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 11)).road_level = 1
	world.get_tile(Vector2i(9, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 12, "SW corner mask must be 12")
	
	# NW (North + West = 1 + 8 = 9)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 9)).road_level = 1
	world.get_tile(Vector2i(9, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 9, "NW corner mask must be 9")
	
	# T-junctions:
	# NES (North + East + South = 1 + 2 + 4 = 7)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 9)).road_level = 1
	world.get_tile(Vector2i(11, 10)).road_level = 1
	world.get_tile(Vector2i(10, 11)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 7, "T-junction NES mask must be 7")
	
	# NEW (North + East + West = 1 + 2 + 8 = 11)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 9)).road_level = 1
	world.get_tile(Vector2i(11, 10)).road_level = 1
	world.get_tile(Vector2i(9, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 11, "T-junction NEW mask must be 11")
	
	# NSW (North + South + West = 1 + 4 + 8 = 13)
	clear_neighbours.call()
	world.get_tile(Vector2i(10, 9)).road_level = 1
	world.get_tile(Vector2i(10, 11)).road_level = 1
	world.get_tile(Vector2i(9, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 13, "T-junction NSW mask must be 13")
	
	# ESW (East + South + West = 2 + 4 + 8 = 14)
	clear_neighbours.call()
	world.get_tile(Vector2i(11, 10)).road_level = 1
	world.get_tile(Vector2i(10, 11)).road_level = 1
	world.get_tile(Vector2i(9, 10)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, c), 14, "T-junction ESW mask must be 14")
	print("✓ Test 4: All 4 corners and 4 T-junctions PASSED")

# Test 5: Four-way intersections
func test_four_way_intersections() -> void:
	var world := _create_empty_world(20, 20)
	var c := Vector2i(10, 10)
	world.get_tile(c).road_level = 1
	world.get_tile(Vector2i(10, 9)).road_level = 1  # North (1)
	world.get_tile(Vector2i(11, 10)).road_level = 1 # East (2)
	world.get_tile(Vector2i(10, 11)).road_level = 1 # South (4)
	world.get_tile(Vector2i(9, 10)).road_level = 1  # West (8)
	
	assert_eq(RoadAutotiler.get_road_mask(world, c), 15, "4-way intersection mask must be 15")
	print("✓ Test 5: Four-way intersection mask PASSED")

# Test 6: Placing a road updates all affected neighbouring masks
func test_placing_road_updates_affected_neighbour_masks() -> void:
	var world := _create_empty_world(20, 20)
	
	# Disconnected roads at (5, 4) and (5, 6)
	world.get_tile(Vector2i(5, 4)).road_level = 1
	world.get_tile(Vector2i(5, 6)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 4)), 0, "Initial (5, 4) is isolated")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 6)), 0, "Initial (5, 6) is isolated")
	
	# Connect them by placing a road at (5, 5)
	var affected: Array[Vector2i] = RoadAutotiler.get_affected_coords(Vector2i(5, 5), world)
	assert_true(Vector2i(5, 5) in affected, "Center in affected")
	assert_true(Vector2i(5, 4) in affected, "North in affected")
	assert_true(Vector2i(5, 6) in affected, "South in affected")
	
	world.get_tile(Vector2i(5, 5)).road_level = 1
	
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 5)), 5, "(5, 5) becomes vertical straight (5)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 4)), 4, "(5, 4) updated to South endpoint (4)")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(5, 6)), 1, "(5, 6) updated to North endpoint (1)")
	print("✓ Test 6: Placing road updates affected neighbours PASSED")

# Test 7: Removing a road updates its neighbours
func test_removing_road_updates_neighbours() -> void:
	var world_scene = load("res://scenes/world/world.tscn").instantiate()
	world_scene._ready()
	world_scene.buildings.clear()
	
	# Clear grass area
	for y in range(4, 8):
		for x in range(4, 8):
			var t: WorldTile = world_scene.world_state.get_tile(Vector2i(x, y))
			t.terrain_id = &"grass"
			t.road_level = 0
			t.is_walkable = true
			t.is_buildable = true
			world_scene.pathfinding.set_solid(Vector2i(x, y), false)
			
	# Build horizontal road: (5, 5) -> (6, 5) -> (7, 5)
	world_scene.build_road(Vector2i(5, 5))
	world_scene.build_road(Vector2i(6, 5))
	world_scene.build_road(Vector2i(7, 5))
	
	assert_eq(RoadAutotiler.get_road_mask(world_scene.world_state, Vector2i(6, 5)), 10, "Middle road is horizontal")
	assert_eq(RoadAutotiler.get_road_mask(world_scene.world_state, Vector2i(5, 5)), 2, "Left road is East endpoint")
	assert_eq(RoadAutotiler.get_road_mask(world_scene.world_state, Vector2i(7, 5)), 8, "Right road is West endpoint")
	
	# Remove the middle road
	var removed_ok: bool = world_scene.remove_road(Vector2i(6, 5))
	assert_true(removed_ok, "remove_road returned true")
	assert_eq(world_scene.world_state.get_tile(Vector2i(6, 5)).road_level, 0, "Middle tile is no longer road")
	
	# Neighbouring tiles revert to isolated endpoints (mask 0)
	assert_eq(RoadAutotiler.get_road_mask(world_scene.world_state, Vector2i(5, 5)), 0, "Left tile reverted to isolated (0)")
	assert_eq(RoadAutotiler.get_road_mask(world_scene.world_state, Vector2i(7, 5)), 0, "Right tile reverted to isolated (0)")
	
	world_scene.free()
	print("✓ Test 7: Removing road updates neighbours PASSED")

# Test 8: Roads near every map edge behave safely
func test_roads_near_every_map_edge_behave_safely() -> void:
	var world := _create_empty_world(20, 20)
	
	# Top-left corner (0, 0)
	world.get_tile(Vector2i(0, 0)).road_level = 1
	var affected_tl: Array[Vector2i] = RoadAutotiler.get_affected_coords(Vector2i(0, 0), world)
	assert_true(not Vector2i(-1, 0) in affected_tl, "Out of bounds West coordinate filtered")
	assert_true(not Vector2i(0, -1) in affected_tl, "Out of bounds North coordinate filtered")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(0, 0)), 0, "Top-left isolated corner is mask 0")
	
	# Connect East neighbor (1, 0)
	world.get_tile(Vector2i(1, 0)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(0, 0)), 2, "Top-left connected East is mask 2")
	
	# Bottom-right corner (19, 19)
	world.get_tile(Vector2i(19, 19)).road_level = 1
	var affected_br: Array[Vector2i] = RoadAutotiler.get_affected_coords(Vector2i(19, 19), world)
	assert_true(not Vector2i(20, 19) in affected_br, "Out of bounds East filtered")
	assert_true(not Vector2i(19, 20) in affected_br, "Out of bounds South filtered")
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(19, 19)), 0, "Bottom-right isolated is mask 0")
	
	# Connect North neighbor (19, 18)
	world.get_tile(Vector2i(19, 18)).road_level = 1
	assert_eq(RoadAutotiler.get_road_mask(world, Vector2i(19, 19)), 1, "Bottom-right connected North is mask 1")
	print("✓ Test 8: Map edge road safety PASSED")

# Test 9: Rendering does not alter logical road state
func test_rendering_does_not_alter_logical_road_state() -> void:
	var world_scene = load("res://scenes/world/world.tscn").instantiate()
	world_scene._ready()
	
	world_scene.build_road(Vector2i(10, 10))
	world_scene.build_road(Vector2i(10, 11))
	
	var r_level_before: int = world_scene.world_state.get_tile(Vector2i(10, 10)).road_level
	var walk_before: bool = world_scene.world_state.get_tile(Vector2i(10, 10)).is_walkable
	var build_before: bool = world_scene.world_state.get_tile(Vector2i(10, 10)).is_buildable
	
	# Trigger rendering cache rebuilds
	world_scene.renderer.invalidate_world_visuals()
	world_scene.renderer._rebuild_road_cache()
	
	var r_level_after: int = world_scene.world_state.get_tile(Vector2i(10, 10)).road_level
	var walk_after: bool = world_scene.world_state.get_tile(Vector2i(10, 10)).is_walkable
	var build_after: bool = world_scene.world_state.get_tile(Vector2i(10, 10)).is_buildable
	
	assert_eq(r_level_before, r_level_after, "road_level unchanged by rendering")
	assert_eq(walk_before, walk_after, "is_walkable unchanged by rendering")
	assert_eq(build_before, build_after, "is_buildable unchanged by rendering")
	
	world_scene.free()
	print("✓ Test 9: Visual rendering does not alter logical state PASSED")

# Test 10: Save/load preserves road state and reconstructs correct visual masks
func test_save_load_preserves_road_state_and_masks() -> void:
	var world := _create_empty_world(20, 20)
	
	# Create T-junction at (8, 8) and corner at (8, 9) -> (9, 9)
	world.get_tile(Vector2i(8, 7)).road_level = 1
	world.get_tile(Vector2i(8, 8)).road_level = 1
	world.get_tile(Vector2i(7, 8)).road_level = 1
	world.get_tile(Vector2i(8, 9)).road_level = 1
	world.get_tile(Vector2i(9, 9)).road_level = 1
	
	var mask_8_8_orig: int = RoadAutotiler.get_road_mask(world, Vector2i(8, 8)) # NSW = 13
	var mask_8_9_orig: int = RoadAutotiler.get_road_mask(world, Vector2i(8, 9)) # NE = 3
	assert_eq(mask_8_8_orig, 13, "Original mask for T-junction is 13")
	assert_eq(mask_8_9_orig, 3, "Original mask for NE corner is 3")
	
	# Serialize
	var buildings: Array[BuildingState] = []
	var citizens: Array[CitizenState] = []
	var units: Array[MilitaryUnitState] = []
	var serialized: Dictionary = SaveSchema.serialize(
		world,
		EconomyState.new(),
		buildings,
		citizens,
		units,
		JobBoard.new(),
		100,
		1.0
	)
	
	# Deserialize
	var deserialized: Dictionary = SaveSchema.deserialize(serialized)
	var loaded_world: WorldState = deserialized["world_state"]
	
	var mask_8_8_loaded: int = RoadAutotiler.get_road_mask(loaded_world, Vector2i(8, 8))
	var mask_8_9_loaded: int = RoadAutotiler.get_road_mask(loaded_world, Vector2i(8, 9))
	
	assert_eq(mask_8_8_loaded, 13, "Loaded mask for T-junction matches 13")
	assert_eq(mask_8_9_loaded, 3, "Loaded mask for NE corner matches 3")
	print("✓ Test 10: Save/load preserves road state and visual masks PASSED")

# Test 11: Existing pathfinding and entrance behaviour remains correct with roads
func test_pathfinding_and_entrance_integration_with_roads() -> void:
	var pathfinding := PathfindingService.new(20, 20)
	var world := _create_empty_world(20, 20)
	
	# Create bakery at (10, 10) with entrance at (11, 12)
	var bakery := BuildingState.new(1, &"bakery", 30, [&"grain", &"bread"])
	bakery.tile_origin = Vector2i(10, 10)
	for dy in range(2):
		for dx in range(2):
			pathfinding.set_solid(Vector2i(10 + dx, 10 + dy), true)
			
	var ent: Vector2i = bakery.get_entrance_tile() # (11, 12)
	
	# Build road corridor from (5, 12) to (11, 12)
	for x in range(5, 12):
		world.get_tile(Vector2i(x, 12)).road_level = 1
		pathfinding.set_road(Vector2i(x, 12), true)
		
	var route_res: Dictionary = pathfinding.find_path_to_entrance(Vector2i(5, 12), bakery, 0, [])
	assert_true(route_res.get("ok", false), "Route along road to entrance must succeed")
	var route: Array[Vector2i] = route_res.get("path", [])
	assert_eq(route[route.size() - 1], ent, "Route terminates at entrance (11, 12)")
	
	# Verify that path precisely traverses along the road corridor
	for pt in route:
		assert_eq(pt.y, 12, "Path strictly follows the road along y=12")
	print("✓ Test 11: Pathfinding and entrance routing along roads PASSED")
