extends SceneTree

func _init() -> void:
	print("--- Running TestEntrances ---")
	test_catalog_entrance_definitions()
	test_placement_entrance_validation()
	test_worker_doorway_routing()
	test_hauler_doorway_routing()
	test_multi_worker_staging_and_deoverlap()
	test_route_invalidation_when_entrance_blocked()
	test_staged_construction_entrance_compatibility()
	print("--- TestEntrances PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

# Test 1: Entrance definitions in catalog and BuildingState initialization
func test_catalog_entrance_definitions() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var test_keys: Array[StringName] = [&"town_hall", &"house", &"farm", &"woodcutter", &"quarry", &"bakery", &"storehouse", &"barracks", &"ground_pile"]
	
	for key in test_keys:
		var d: Dictionary = defs.get(key, {})
		assert_true(not d.is_empty(), "Definition for %s must exist" % str(key))
		assert_true(d.has("entrance_offset"), "%s must have entrance_offset" % str(key))
		assert_true(d.has("doorway_tile"), "%s must have doorway_tile" % str(key))
		assert_true(d.has("staging_offsets"), "%s must have staging_offsets" % str(key))
		
		var footprint: Vector2i = d.get("footprint", Vector2i(2, 2))
		var ent_offset: Vector2i = d.get("entrance_offset")
		var door_offset: Vector2i = d.get("doorway_tile")
		var stagings: Array = d.get("staging_offsets")
		
		# Doorway must be inside or on the perimeter edge of the building
		assert_true(door_offset.x >= 0 and door_offset.x < footprint.x, "Doorway x inside footprint for %s" % str(key))
		assert_true(door_offset.y >= 0 and door_offset.y < footprint.y, "Doorway y inside footprint for %s" % str(key))
		
		# Entrance offset must be OUTSIDE the solid footprint (so it is traversable)
		var in_footprint: bool = (ent_offset.x >= 0 and ent_offset.x < footprint.x and ent_offset.y >= 0 and ent_offset.y < footprint.y)
		assert_true(not in_footprint, "Entrance exterior tile must be outside solid footprint for %s" % str(key))
		assert_true(not stagings.is_empty(), "Staging offsets must not be empty for %s" % str(key))
		assert_true(ent_offset in stagings, "Primary entrance must be included in staging offsets for %s" % str(key))

	# Test BuildingState initialization
	var b := BuildingState.new(101, &"farm", 30, [&"grain"])
	b.tile_origin = Vector2i(10, 10)
	assert_eq(b.entrance_offset, Vector2i(1, 3), "Farm entrance_offset")
	assert_eq(b.doorway_tile, Vector2i(1, 2), "Farm doorway_tile")
	assert_eq(b.get_entrance_tile(), Vector2i(11, 13), "Farm world entrance tile at (10, 10)")
	assert_eq(b.get_doorway_world_tile(), Vector2i(11, 12), "Farm doorway world tile at (10, 10)")
	assert_true(b.is_at_entrance_or_staging(Vector2i(11, 13)), "Must be at entrance")
	assert_true(b.is_at_entrance_or_staging(Vector2i(10, 13)), "Must be at staging")
	assert_true(not b.is_at_entrance_or_staging(Vector2i(10, 10)), "Footprint tile is not entrance")
	print("✓ Test 1: Building entrance definitions and coordinate calculations PASSED")

# Test 2: Placement entrance validation
func test_placement_entrance_validation() -> void:
	var world_scene: WorldScene = load("res://scenes/world/world.tscn").instantiate()
	world_scene._ready()
	world_scene.buildings.clear()
	
	var set_grass_patch := func(origin: Vector2i, size: Vector2i):
		for dy in range(size.y):
			for dx in range(size.x):
				var coord := origin + Vector2i(dx, dy)
				if world_scene.world_state.is_valid_coord(coord):
					var t: WorldTile = world_scene.world_state.get_tile(coord)
					t.terrain_id = &"grass"
					t.is_walkable = true
					t.is_buildable = true
					t.building_id = 0
					t.resource_deposit_id = &""
					t.resource_amount = 0
					world_scene.pathfinding.set_solid(coord, false)
	
	# Out of bounds entrance validation: Farm is 3x3 with entrance_offset (1, 3).
	# At y = height - 3, entrance is at y = height (out of bounds).
	var oob_y: int = world_scene.world_state.height - 3
	set_grass_patch.call(Vector2i(10, oob_y), Vector2i(3, 3))
	var check_oob: Dictionary = world_scene.can_place_building_at(&"farm", Vector2i(10, oob_y))
	assert_true(not check_oob.get("ok", true), "Farm with entrance out of bounds must be rejected")
	assert_eq(check_oob.get("reason", ""), "Entrance is outside map boundary", "Reason must identify entrance out of bounds")
	
	# Blocked by water
	set_grass_patch.call(Vector2i(14, 15), Vector2i(4, 5))
	var water_coord := Vector2i(15, 18)
	var wt_water := world_scene.world_state.get_tile(water_coord)
	wt_water.terrain_id = &"water"
	wt_water.is_walkable = false
	wt_water.is_buildable = false
	# Farm at (14, 15) has footprint (14..16, 15..17) and entrance at (14+1, 15+3) = (15, 18)
	var check_water: Dictionary = world_scene.can_place_building_at(&"farm", Vector2i(14, 15))
	assert_true(not check_water.get("ok", true), "Placement with entrance on water must be rejected")
	assert_eq(check_water.get("reason", ""), "Entrance blocked by water", "Reason must identify water")
	
	# Blocked by rocky terrain
	set_grass_patch.call(Vector2i(24, 25), Vector2i(4, 5))
	var rock_coord := Vector2i(25, 28)
	var wt_rock := world_scene.world_state.get_tile(rock_coord)
	wt_rock.terrain_id = &"rock"
	wt_rock.is_walkable = false
	wt_rock.is_buildable = false
	var check_rock: Dictionary = world_scene.can_place_building_at(&"farm", Vector2i(24, 25))
	assert_true(not check_rock.get("ok", true), "Placement with entrance on rock must be rejected")
	assert_eq(check_rock.get("reason", ""), "Entrance blocked by rocky terrain", "Reason must identify rock")
	
	# Blocked by another building
	set_grass_patch.call(Vector2i(29, 30), Vector2i(6, 6))
	var blocker := world_scene.place_building(&"house", Vector2i(30, 33), true)
	# Farm placed at (29, 30) has entrance at (29+1, 30+3) = (30, 33), which is inside the house!
	var check_occupied: Dictionary = world_scene.can_place_building_at(&"farm", Vector2i(29, 30))
	assert_true(not check_occupied.get("ok", true), "Placement with entrance in another building must be rejected")
	assert_eq(check_occupied.get("reason", ""), "Entrance is occupied or blocked", "Reason must identify blocked entrance")
	
	# Valid placement with clear entrance succeeds
	set_grass_patch.call(Vector2i(5, 5), Vector2i(4, 4))
	var check_valid: Dictionary = world_scene.can_place_building_at(&"house", Vector2i(5, 5))
	assert_true(check_valid.get("ok", false), "Valid placement must succeed")
	
	world_scene.free()
	print("✓ Test 2: Placement entrance validation PASSED")

# Test 3: Worker doorway routing
func test_worker_doorway_routing() -> void:
	var pathfinding := PathfindingService.new(40, 40)
	
	var b := BuildingState.new(1, &"bakery", 30, [&"grain", &"bread"])
	b.tile_origin = Vector2i(10, 10) # 2x2 building at (10, 10), footprint (10..11, 10..11)
	pathfinding.set_solid(Vector2i(10, 10), true)
	pathfinding.set_solid(Vector2i(11, 10), true)
	pathfinding.set_solid(Vector2i(10, 11), true)
	pathfinding.set_solid(Vector2i(11, 11), true)
	
	var ent_tile: Vector2i = b.get_entrance_tile() # (10+1, 10+2) = (11, 12)
	assert_eq(ent_tile, Vector2i(11, 12), "Bakery entrance tile should be (11, 12)")
	
	var worker_start := Vector2i(2, 2)
	var route: Array[Vector2i] = pathfinding.find_path_to_entrance(worker_start, b, 0, [])
	assert_true(not route.is_empty(), "Worker must find path to entrance")
	assert_eq(route[route.size() - 1], ent_tile, "Worker path must terminate directly at designated entrance tile (11, 12)")
	assert_true(not route.has(Vector2i(10, 10)), "Path must not walk through solid building")
	print("✓ Test 3: Worker doorway routing terminates at entrance PASSED")

# Test 4: Physical hauler routing to designated entrances
func test_hauler_doorway_routing() -> void:
	var pathfinding := PathfindingService.new(40, 40)
	var job_board := JobBoard.new()
	var logistics := LogisticsSystem.new(job_board)
	
	# Setup Source (Woodcutter at 5, 5; entrance at 6, 7)
	var src_b := BuildingState.new(1, &"woodcutter", 30, [&"timber"])
	src_b.tile_origin = Vector2i(5, 5)
	src_b.status = BuildingState.Status.ACTIVE
	src_b.inventory.add_resource(&"timber", 10, "SETUP")
	for dy in range(2):
		for dx in range(2):
			pathfinding.set_solid(Vector2i(5 + dx, 5 + dy), true)
			
	# Setup Destination (Storehouse at 15, 15; entrance at 16, 17)
	var dest_b := BuildingState.new(2, &"storehouse", 150, [&"timber"])
	dest_b.tile_origin = Vector2i(15, 15)
	dest_b.status = BuildingState.Status.ACTIVE
	for dy in range(2):
		for dx in range(3):
			pathfinding.set_solid(Vector2i(15 + dx, 15 + dy), true)
			
	var hauler: LogisticsSystem.Hauler = logistics.register_hauler(10, Vector2i(0, 0))
	var job: HaulJob = job_board.create_job(&"timber", 5, src_b.inventory, dest_b.inventory, 1, 0)
	
	var inv_map := {1: src_b.inventory, 2: dest_b.inventory}
	var building_by_inv := {1: src_b, 2: dest_b}
	
	logistics.dispatch_jobs()
	assert_eq(hauler.active_job, job, "Hauler must be assigned job")
	
	# Hauler travels to source
	var max_ticks := 50
	var tick := 0
	while hauler.active_job != null and hauler.carried_amount == 0 and tick < max_ticks:
		tick += 1
		logistics.tick_haulers(inv_map, tick, pathfinding, building_by_inv)
		
	assert_true(hauler.carried_amount > 0, "Hauler must have picked up cargo")
	assert_eq(hauler.current_tile, src_b.get_entrance_tile(), "Hauler picked up cargo at source entrance (6, 7)")
	assert_eq(hauler.carried_amount, 5, "Hauler is carrying 5 timber")
	assert_eq(job.status, HaulJob.Status.IN_TRANSIT, "Job is now IN_TRANSIT")
	
	# Hauler travels to destination
	while hauler.active_job != null and tick < max_ticks:
		tick += 1
		logistics.tick_haulers(inv_map, tick, pathfinding, building_by_inv)
		
	assert_true(hauler.active_job == null, "Hauler must have completed job")
	assert_eq(hauler.current_tile, dest_b.get_entrance_tile(), "Hauler delivered cargo at destination entrance (16, 17)")
	assert_eq(dest_b.inventory.get_total_quantity(), 5, "Storehouse received 5 timber")
	print("✓ Test 4: Physical hauler doorway pickup and delivery PASSED")

# Test 5: Multi-worker staging and de-overlap
func test_multi_worker_staging_and_deoverlap() -> void:
	var pathfinding := PathfindingService.new(40, 40)
	
	# Barracks is 3x3 at (10, 10). Entrance offset: (1, 3) -> (11, 13).
	# Staging offsets: (1, 3) -> (11, 13), (0, 3) -> (10, 13), (2, 3) -> (12, 13), (1, 4) -> (11, 14).
	var barracks := BuildingState.new(5, &"barracks", 40, [&"bread"])
	barracks.tile_origin = Vector2i(10, 10)
	for dy in range(3):
		for dx in range(3):
			pathfinding.set_solid(Vector2i(10 + dx, 10 + dy), true)
			
	var occupied: Array[Vector2i] = []
	
	# Worker 1 routes to slot 0
	var route_w1: Array[Vector2i] = pathfinding.find_path_to_entrance(Vector2i(0, 10), barracks, 0, occupied)
	assert_true(not route_w1.is_empty(), "Route 1 must exist")
	var dest_w1: Vector2i = route_w1[route_w1.size() - 1]
	assert_eq(dest_w1, Vector2i(11, 13), "Worker 1 should target primary doorway entrance")
	occupied.append(dest_w1)
	
	# Worker 2 routes to slot 1 (dest_w1 occupied)
	var route_w2: Array[Vector2i] = pathfinding.find_path_to_entrance(Vector2i(0, 10), barracks, 1, occupied)
	assert_true(not route_w2.is_empty(), "Route 2 must exist")
	var dest_w2: Vector2i = route_w2[route_w2.size() - 1]
	assert_true(dest_w2 != dest_w1, "Worker 2 must not target occupied worker 1 tile")
	assert_eq(dest_w2, Vector2i(10, 13), "Worker 2 should target staging slot 1 (10, 13)")
	occupied.append(dest_w2)
	
	# Worker 3 routes to slot 2 (slots 0 and 1 occupied)
	var route_w3: Array[Vector2i] = pathfinding.find_path_to_entrance(Vector2i(0, 10), barracks, 2, occupied)
	assert_true(not route_w3.is_empty(), "Route 3 must exist")
	var dest_w3: Vector2i = route_w3[route_w3.size() - 1]
	assert_true(dest_w3 != dest_w1 and dest_w3 != dest_w2, "Worker 3 must target distinct tile")
	assert_eq(dest_w3, Vector2i(12, 13), "Worker 3 should target staging slot 2 (12, 13)")
	occupied.append(dest_w3)
	
	# Worker 4 routes to slot 3
	var route_w4: Array[Vector2i] = pathfinding.find_path_to_entrance(Vector2i(0, 10), barracks, 3, occupied)
	assert_true(not route_w4.is_empty(), "Route 4 must exist")
	var dest_w4: Vector2i = route_w4[route_w4.size() - 1]
	assert_eq(dest_w4, Vector2i(11, 14), "Worker 4 should target queue staging slot 3 (11, 14)")
	
	# Verify that all 4 destinations count as valid interaction positions for production
	assert_true(barracks.is_at_entrance_or_staging(dest_w1), "Dest 1 is valid interaction tile")
	assert_true(barracks.is_at_entrance_or_staging(dest_w2), "Dest 2 is valid interaction tile")
	assert_true(barracks.is_at_entrance_or_staging(dest_w3), "Dest 3 is valid interaction tile")
	assert_true(barracks.is_at_entrance_or_staging(dest_w4), "Dest 4 is valid interaction tile")
	print("✓ Test 5: Multi-worker staging, de-overlap and queuing PASSED")

# Test 6: Route invalidation when entrance is blocked
func test_route_invalidation_when_entrance_blocked() -> void:
	var pathfinding := PathfindingService.new(30, 30)
	
	var quarry := BuildingState.new(8, &"quarry", 30, [&"stone"])
	quarry.tile_origin = Vector2i(15, 15)
	for dy in range(2):
		for dx in range(2):
			pathfinding.set_solid(Vector2i(15 + dx, 15 + dy), true)
			
	var ent: Vector2i = quarry.get_entrance_tile() # (16, 17)
	assert_true(pathfinding.is_entrance_walkable(quarry), "Entrance must initially be walkable")
	
	# Block the entrance
	pathfinding.set_solid(ent, true)
	assert_true(not pathfinding.is_entrance_walkable(quarry), "Entrance must now be reported as not walkable")
	
	# Finding path with slot 0 should cleanly use alternative staging or perimeter fallback without crash
	var route: Array[Vector2i] = pathfinding.find_path_to_entrance(Vector2i(5, 5), quarry, 0, [])
	assert_true(not route.is_empty(), "Should find route to alternative staging/perimeter")
	var target_tile: Vector2i = route[route.size() - 1]
	assert_true(target_tile != ent, "Target tile must not be the blocked entrance")
	assert_true(not pathfinding.astar_grid.is_point_solid(target_tile), "Target tile must be traversable")
	print("✓ Test 6: Route invalidation and fallback when entrance blocked PASSED")

# Test 7: Staged construction lifecycle compatibility with explicit entrances
func test_staged_construction_entrance_compatibility() -> void:
	var const_sys := ConstructionSystem.new()
	var site := const_sys.create_construction_site(
		20,
		&"farm",
		Vector2i(20, 20),
		{&"timber": 5},
		6,
		21,
		30,
		[&"grain"]
	)
	
	# Entrance should be defined immediately on construction site
	assert_eq(site.entrance_offset, Vector2i(1, 3), "Site inherits entrance offset")
	assert_eq(site.get_entrance_tile(), Vector2i(21, 23), "Site entrance tile is (21, 23)")
	assert_true(site.is_at_entrance_or_staging(Vector2i(21, 23)), "Entrance is valid site interaction tile")
	
	# Supply materials to site construction inventory
	site.construction_inventory.add_resource(&"timber", 5, "DELIVERY")
	assert_true(site.has_all_construction_materials(), "Site has all materials")
	
	# Workers present at entrance advance construction
	var workers_at_entrance := 2
	for t in range(6):
		const_sys.tick_building(site, workers_at_entrance, t + 1)
		
	assert_eq(site.status, BuildingState.Status.ACTIVE, "Site activates after build ticks complete")
	assert_eq(site.get_entrance_tile(), Vector2i(21, 23), "Active building retains same entrance tile")
	print("✓ Test 7: Staged construction lifecycle compatibility PASSED")
