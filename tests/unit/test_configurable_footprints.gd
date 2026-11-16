extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

const RoadAutotiler = preload("res://scripts/presentation/road_autotiler.gd")

func _init() -> void:
	print("--- Running TestConfigurableFootprints ---")
	test_min_max_dimensions()
	test_clamping_and_validation()
	test_overlap_rejection_across_large_footprint()
	test_cost_scaling_and_rounding()
	test_capacity_scaling()
	test_worker_slots_scaling()
	test_dynamic_entrance_and_staging()
	test_construction_material_delivery_and_activation()
	test_cancellation_and_refund_overflow()
	test_road_autotiling_adjacent_to_variable_footprints()
	test_save_load_round_trip()
	test_backward_compatibility_legacy_saves()
	test_non_regression_existing_systems()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestConfigurableFootprints PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

# Helper to create an isolated world instance for testing
func _create_test_world() -> Node:
	var world = load("res://scenes/world/world.tscn").instantiate()
	world._ready()
	return world

func _cleanup_test_world(world: Node) -> void:
	if world != null and is_instance_valid(world):
		world.free()

# 1. Min and max dimensions
func test_min_max_dimensions() -> void:
	assert_true(BuildingCatalog.is_building_resizable(&"farm"), "Farm must be resizable")
	assert_true(BuildingCatalog.is_building_resizable(&"storehouse"), "Storehouse must be resizable")
	assert_true(not BuildingCatalog.is_building_resizable(&"house"), "House must not be resizable")
	assert_true(not BuildingCatalog.is_building_resizable(&"quarry"), "Quarry must not be resizable")
	assert_true(not BuildingCatalog.is_building_resizable(&"town_hall"), "Town Hall must not be resizable")

	assert_eq(BuildingCatalog.get_min_footprint(&"farm"), Vector2i(2, 2), "Farm min footprint is 2x2")
	assert_eq(BuildingCatalog.get_max_footprint(&"farm"), Vector2i(6, 6), "Farm max footprint is 6x6")

	assert_eq(BuildingCatalog.get_min_footprint(&"storehouse"), Vector2i(2, 2), "Storehouse min footprint is 2x2")
	assert_eq(BuildingCatalog.get_max_footprint(&"storehouse"), Vector2i(5, 4), "Storehouse max footprint is 5x4")

	print("✓ Test 1: Min and max dimensions verified")

# 2. Clamping and validation
func test_clamping_and_validation() -> void:
	# Undersized clamping
	assert_eq(BuildingCatalog.clamp_footprint(&"farm", Vector2i(1, 1)), Vector2i(2, 2), "Under-min farm clamped to 2x2")
	assert_eq(BuildingCatalog.clamp_footprint(&"storehouse", Vector2i(1, 5)), Vector2i(2, 4), "Under-width / over-height storehouse clamped to (2, 4)")

	# Oversized clamping
	assert_eq(BuildingCatalog.clamp_footprint(&"farm", Vector2i(8, 7)), Vector2i(6, 6), "Over-max farm clamped to 6x6")
	assert_eq(BuildingCatalog.clamp_footprint(&"storehouse", Vector2i(7, 6)), Vector2i(5, 4), "Over-max storehouse clamped to 5x4")

	# Non-resizable buildings ignore custom footprint and clamp to default
	var house_base: Vector2i = BuildingCatalog.get_all_defs().get(&"house", {}).get("footprint", Vector2i(2, 2))
	assert_eq(BuildingCatalog.clamp_footprint(&"house", Vector2i(5, 5)), house_base, "Non-resizable house clamps to fixed base")

	print("✓ Test 2: Footprint clamping and validation verified")

# 3. Overlap rejection across large footprint
func test_overlap_rejection_across_large_footprint() -> void:
	var world = _create_test_world()

	# Clear out any natural obstacles around (15, 15) to (30, 30)
	for y in range(10, 35):
		for x in range(10, 35):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	# Place a 5x4 storehouse at (15, 15)
	var b1 = world.place_building(&"storehouse", Vector2i(15, 15), true, Vector2i(5, 4))
	assert_true(b1 != null, "5x4 storehouse placed successfully")
	assert_eq(b1.get_footprint(), Vector2i(5, 4), "Storehouse has 5x4 footprint")

	# Attempt to place a building overlapping the bottom-right corner at (19, 18)
	var check1 = world.can_place_building_at(&"house", Vector2i(19, 18), Vector2i(2, 2))
	assert_true(not check1["ok"], "Overlapping placement at bottom-right corner must fail")
	assert_eq(check1["reason"], "Tile is occupied or blocked", "Failure reason is tile blocked")

	# Attempt to place a 6x6 farm overlapping (13, 13)
	var check2 = world.can_place_building_at(&"farm", Vector2i(13, 13), Vector2i(6, 6))
	assert_true(not check2["ok"], "6x6 farm overlapping storehouse must fail")

	# Attempt to place outside map boundaries (world size is 48x48)
	var check_oob = world.can_place_building_at(&"farm", Vector2i(-2, -2), Vector2i(6, 6))
	assert_true(not check_oob["ok"], "6x6 farm extending outside boundary must fail")
	assert_eq(check_oob["reason"], "Location is outside map boundary")

	# Attempt to place where a citizen is standing
	var c_tile = Vector2i(25, 25)
	world.citizens[0].position_tile = c_tile
	var check_citizen = world.can_place_building_at(&"farm", Vector2i(24, 24), Vector2i(3, 3))
	assert_true(not check_citizen["ok"], "Building on top of citizen must fail")
	assert_eq(check_citizen["reason"], "A citizen is standing here")

	_cleanup_test_world(world)
	print("✓ Test 3: Overlap rejection across large footprint verified")

# 4. Cost scaling and rounding
func test_cost_scaling_and_rounding() -> void:
	# Farm base 3x3 (area 9) cost is 5 timber
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"farm", Vector2i(3, 3)), {&"timber": 5}, "Base farm cost is 5 timber")

	# Farm 2x2 (area 4): max(3, round(5 * 4 / 9)) = max(3, 2) = 3 timber
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"farm", Vector2i(2, 2)), {&"timber": 3}, "2x2 farm cost is 3 timber")

	# Farm 4x4 (area 16): round(5 * 16 / 9) = round(8.888) = 9 timber
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"farm", Vector2i(4, 4)), {&"timber": 9}, "4x4 farm cost is 9 timber")

	# Farm 6x6 (area 36): round(5 * 36 / 9) = 20 timber
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"farm", Vector2i(6, 6)), {&"timber": 20}, "6x6 farm cost is 20 timber")

	# Storehouse base 3x2 (area 6): 8 timber, 4 stone
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"storehouse", Vector2i(3, 2)), {&"timber": 8, &"stone": 4}, "Base storehouse cost is 8 timber, 4 stone")

	# Storehouse 2x2 (area 4): timber max(4, round(8*4/6)) = 5, stone max(2, round(4*4/6)) = 3
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"storehouse", Vector2i(2, 2)), {&"timber": 5, &"stone": 3}, "2x2 storehouse cost is 5 timber, 3 stone")

	# Storehouse 5x4 (area 20): timber round(8*20/6) = 27, stone round(4*20/6) = 13
	assert_eq(BuildingCatalog.get_cost_for_footprint(&"storehouse", Vector2i(5, 4)), {&"timber": 27, &"stone": 13}, "5x4 storehouse cost is 27 timber, 13 stone")

	print("✓ Test 4: Cost scaling and rounding verified")

# 5. Capacity scaling
func test_capacity_scaling() -> void:
	# Farm capacity: base 3x3 is 30. Formula: round(30 * area / 9)
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"farm", Vector2i(2, 2)), 13, "2x2 farm cap is 13")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"farm", Vector2i(3, 3)), 30, "3x3 farm cap is 30")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"farm", Vector2i(4, 4)), 53, "4x4 farm cap is 53")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"farm", Vector2i(6, 6)), 120, "6x6 farm cap is 120")

	# Storehouse capacity: base 3x2 is 150. Formula: round(150 * area / 6)
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"storehouse", Vector2i(2, 2)), 100, "2x2 storehouse cap is 100")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"storehouse", Vector2i(3, 2)), 150, "3x2 storehouse cap is 150")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"storehouse", Vector2i(4, 3)), 300, "4x3 storehouse cap is 300")
	assert_eq(BuildingCatalog.get_capacity_for_footprint(&"storehouse", Vector2i(5, 4)), 500, "5x4 storehouse cap is 500")

	print("✓ Test 5: Capacity scaling verified")

# 6. Worker slots scaling
func test_worker_slots_scaling() -> void:
	# Farm slots: 1 + int(area / 6), clamped 1..6
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(2, 2)), 1, "2x2 farm has 1 worker slot")
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(3, 3)), 2, "3x3 farm has 2 worker slots")
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(4, 4)), 3, "4x4 farm has 3 worker slots")
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(6, 6)), 6, "6x6 farm has 6 worker slots (clamped)")

	# Storehouse slots: 2 + int(max(0, area - 6) / 8), clamped to [2, 4] (evaluates to 2..3 across supported footprints 2x2 to 5x4)
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"storehouse", Vector2i(2, 2)), 2, "2x2 storehouse has 2 worker slots")
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"storehouse", Vector2i(3, 2)), 2, "3x2 storehouse has 2 worker slots")
	assert_eq(BuildingCatalog.get_worker_slots_for_footprint(&"storehouse", Vector2i(5, 4)), 3, "5x4 storehouse has 3 worker slots")

	print("✓ Test 6: Worker slots scaling verified")

# 7. Dynamic entrance and staging recalculation
func test_dynamic_entrance_and_staging() -> void:
	var b := BuildingState.new(1, &"farm", 30, [], Vector2i(5, 4))
	b.tile_origin = Vector2i(10, 10)

	# Footprint is 5 wide, 4 high
	# Doorway tile is Vector2i(5/2, 4-1) = Vector2i(2, 3) relative to origin -> (12, 13)
	assert_eq(b.doorway_tile, Vector2i(2, 3), "Doorway tile relative offset is (2, 3)")
	assert_eq(b.get_doorway_world_tile(), Vector2i(12, 13), "Doorway absolute tile is (12, 13)")

	# Entrance offset is Vector2i(5/2, 4) = Vector2i(2, 4) relative to origin -> (12, 14)
	assert_eq(b.entrance_offset, Vector2i(2, 4), "Entrance offset relative is (2, 4)")
	assert_eq(b.get_entrance_tile(), Vector2i(12, 14), "Entrance absolute tile is (12, 14)")

	# Ensure entrance is strictly OUTSIDE the solid footprint [10..14, 10..13]
	var fp: Vector2i = b.get_footprint()
	var rect := Rect2i(b.tile_origin, fp)
	assert_true(rect.has_point(b.get_doorway_world_tile()), "Doorway is inside solid footprint")
	assert_true(not rect.has_point(b.get_entrance_tile()), "Entrance exterior tile is outside solid footprint")

	# Check staging offsets
	var stagings = b.staging_offsets
	assert_true(b.entrance_offset in stagings, "Primary entrance in staging offsets")
	assert_true(Vector2i(1, 4) in stagings, "Left staging offset present")
	assert_true(Vector2i(3, 4) in stagings, "Right staging offset present")
	assert_true(Vector2i(2, 5) in stagings, "Queuing staging offset present")

	# Check is_at_entrance_or_staging
	assert_true(b.is_at_entrance_or_staging(Vector2i(12, 14)), "Entrance tile recognised as staging")
	assert_true(b.is_at_entrance_or_staging(Vector2i(11, 14)), "Left staging tile recognised")
	assert_true(not b.is_at_entrance_or_staging(Vector2i(12, 12)), "Interior tile not recognised as staging")

	print("✓ Test 7: Dynamic entrance and staging recalculation verified")

# 8. Construction material delivery and activation
func test_construction_material_delivery_and_activation() -> void:
	var world = _create_test_world()

	# Clear an area at (15, 15) for a 4x4 farm
	for y in range(14, 21):
		for x in range(14, 21):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	# Put timber in Town Hall
	var th = world.buildings[0]
	th.inventory.add_resource(&"timber", 50, "INITIAL_STOCK")

	# Place 4x4 farm at (15, 15)
	var farm_site = world.place_building(&"farm", Vector2i(15, 15), false, Vector2i(4, 4))
	assert_true(farm_site != null, "Farm site placed successfully")
	assert_true(farm_site.is_under_construction(), "Farm site is under construction")
	assert_eq(farm_site.get_footprint(), Vector2i(4, 4), "Site has 4x4 footprint")

	# Verify cost is 9 timber
	assert_eq(farm_site.construction_cost, {&"timber": 9}, "Construction cost scaled to 9 timber")

	# Simulate hauler delivering 9 timber
	farm_site.construction_inventory.add_resource(&"timber", 9, "HAUL_DELIVERY", false)
	assert_true(farm_site.has_all_construction_materials(), "Farm site received all 9 timber")

	# Advance construction ticks until complete
	var req_ticks: int = farm_site.construction_required_ticks
	for t in range(req_ticks):
		world.construction.tick_building(farm_site, 1, t)

	assert_true(farm_site.status == BuildingState.Status.ACTIVE, "Farm is now ACTIVE")
	assert_eq(farm_site.inventory.capacity, 53, "Active farm has scaled 53 capacity")

	# Verify entire 4x4 area is solid
	for dy in range(4):
		for dx in range(4):
			var c = Vector2i(15 + dx, 15 + dy)
			assert_true(world.pathfinding.astar_grid.is_point_solid(c), "Tile %s is solid" % str(c))

	# Verify entrance at (15 + 2, 15 + 4) = (17, 19) is walkable
	assert_true(not world.pathfinding.astar_grid.is_point_solid(Vector2i(17, 19)), "Entrance tile is walkable")

	_cleanup_test_world(world)
	print("✓ Test 8: Construction material delivery and activation verified")

# 9. Cancellation, refund overflow, and ground pile integrity
func test_cancellation_and_refund_overflow() -> void:
	var world = _create_test_world()

	# Clear area for a 5x4 storehouse
	for y in range(15, 22):
		for x in range(15, 22):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	var th = world.buildings[0]
	th.inventory.quantities.clear()
	# Fill Town Hall almost to capacity (145/150)
	th.inventory.add_resource(&"timber", 145, "SETUP")

	# Place 5x4 storehouse site with cost 27 timber, 13 stone
	var site = world.place_building(&"storehouse", Vector2i(15, 15), false, Vector2i(5, 4))
	assert_true(site != null, "5x4 storehouse site created")
	assert_eq(site.get_footprint(), Vector2i(5, 4), "Footprint is 5x4")

	# Simulate delivered 27 timber and 13 stone into construction inventory
	site.construction_inventory.add_resource(&"timber", 27, "DELIVERY", false)
	site.construction_inventory.add_resource(&"stone", 13, "DELIVERY", false)

	# Cancel site - Town Hall has only 5 free capacity, so 5 will go to Town Hall and 35 to ground pile
	world.cancel_construction_site(site)

	# Verify site removed
	assert_true(not (site in world.buildings), "Cancelled site removed from world")

	# Verify ground pile exists
	var pile: BuildingState = null
	for b in world.buildings:
		if b.definition_id == &"ground_pile":
			pile = b
			break
	assert_true(pile != null, "Ground pile created for refund overflow")
	var total_refunded: int = th.inventory.get_total_quantity() + pile.inventory.get_total_quantity()
	assert_eq(total_refunded, 145 + 40, "All 40 refunded resources preserved (145 existing + 40 delivered)")

	# Verify all 20 tiles (5x4) restored to walkable in pathfinder
	for dy in range(4):
		for dx in range(5):
			var c = Vector2i(15 + dx, 15 + dy)
			# Only ground pile tile at origin is solid
			if c == Vector2i(15, 15):
				assert_true(world.pathfinding.astar_grid.is_point_solid(c), "Ground pile origin remains solid")
			else:
				assert_true(not world.pathfinding.astar_grid.is_point_solid(c), "Tile %s is restored to walkable" % str(c))

	_cleanup_test_world(world)
	print("✓ Test 9: Cancellation and refund overflow integrity verified")

# 10. Road autotiling adjacent to variable footprints
func test_road_autotiling_adjacent_to_variable_footprints() -> void:
	var world = _create_test_world()

	# Clear area at (10, 10)
	for y in range(8, 18):
		for x in range(8, 18):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.road_level = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	# Place 4x4 farm at (10, 10). Entrance tile is at (12, 14)
	var farm = world.place_building(&"farm", Vector2i(10, 10), true, Vector2i(4, 4))
	assert_true(farm != null, "4x4 farm placed")
	assert_eq(farm.get_entrance_tile(), Vector2i(12, 14), "Entrance at (12, 14)")

	# Build a road leading to the entrance: (12, 14), (12, 15), (12, 16)
	assert_true(world.build_road(Vector2i(12, 14)), "Road built at entrance")
	assert_true(world.build_road(Vector2i(12, 15)), "Road built leading south")
	assert_true(world.build_road(Vector2i(12, 16)), "Road built further south")

	# Test autotiling mask for middle road at (12, 15): North (1) + South (4) = 5
	var mask_mid: int = RoadAutotiler.get_road_mask(world.world_state, Vector2i(12, 15))
	assert_eq(mask_mid, 5, "Middle road tile has vertical mask 5")

	# Test pathfinding along the road to the entrance
	var route = world.pathfinding.find_path(Vector2i(12, 16), farm.get_entrance_tile())
	assert_true(not route.is_empty(), "Path to entrance along road exists")
	assert_eq(route[route.size() - 1], Vector2i(12, 14), "Route terminates at entrance")

	_cleanup_test_world(world)
	print("✓ Test 10: Road autotiling adjacent to variable footprints verified")

# 11. Save/load round-trip
func test_save_load_round_trip() -> void:
	var world = _create_test_world()

	# Clear area for buildings
	for y in range(8, 25):
		for x in range(8, 25):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.road_level = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	# Place custom 4x4 farm at (10, 10) and custom 5x3 storehouse at (18, 10)
	var farm = world.place_building(&"farm", Vector2i(10, 10), true, Vector2i(4, 4))
	var store = world.place_building(&"storehouse", Vector2i(18, 10), true, Vector2i(5, 3))
	assert_true(farm != null and store != null, "Buildings placed")

	# Serialize
	var save_data: Dictionary = SaveSchema.serialize(
		world.world_state,
		world.economy,
		world.buildings,
		world.citizens,
		world.military_units,
		world.job_board,
		world.current_tick,
		world.sim_speed_multiplier
	)

	# Check that footprint is preserved in serialized JSON
	var found_farm_fp := false
	var found_store_fp := false
	for b_dict in save_data["buildings"]:
		# The scenario now seeds its own default-size buildings, so match the ones this test placed.
		if int(b_dict["entity_id"]) == farm.entity_id:
			assert_eq(b_dict["footprint"], [4, 4], "Farm footprint serialized as [4, 4]")
			found_farm_fp = true
		elif int(b_dict["entity_id"]) == store.entity_id:
			assert_eq(b_dict["footprint"], [5, 3], "Storehouse footprint serialized as [5, 3]")
			found_store_fp = true
	assert_true(found_farm_fp and found_store_fp, "Both custom footprints found in serialized data")

	# Deserialize
	var loaded_data: Dictionary = SaveSchema.deserialize(save_data)
	var loaded_buildings: Array = loaded_data["buildings"]

	# Find loaded buildings
	var loaded_farm: BuildingState = null
	var loaded_store: BuildingState = null
	for b in loaded_buildings:
		if b.definition_id == &"farm":
			loaded_farm = b
		elif b.definition_id == &"storehouse":
			loaded_store = b

	assert_true(loaded_farm != null, "Loaded farm found")
	assert_eq(loaded_farm.get_footprint(), Vector2i(4, 4), "Loaded farm restored 4x4 footprint")
	assert_eq(loaded_farm.inventory.capacity, 53, "Loaded farm restored 53 capacity")
	assert_eq(loaded_farm.get_doorway_world_tile(), Vector2i(12, 13), "Loaded farm doorway restored")
	assert_eq(loaded_farm.get_entrance_tile(), Vector2i(12, 14), "Loaded farm entrance restored")

	assert_true(loaded_store != null, "Loaded storehouse found")
	assert_eq(loaded_store.get_footprint(), Vector2i(5, 3), "Loaded storehouse restored 5x3 footprint")
	assert_eq(loaded_store.inventory.capacity, 375, "Loaded storehouse restored 375 capacity")

	_cleanup_test_world(world)
	print("✓ Test 11: Save/load round-trip preserving custom footprints verified")

# 12. Backward compatibility with legacy saves lacking footprint
func test_backward_compatibility_legacy_saves() -> void:
	# Create legacy save dict with a farm without the "footprint" property
	var legacy_save: Dictionary = {
		"meta": {
			"schema_version": 1,
			"generator_version": 1,
			"seed_val": 42,
			"current_tick": 100,
			"sim_speed": 1.0
		},
		"economy": {
			"tax_level": 1,
			"approval": 60.0,
			"last_tax_income": 0,
			"last_tax_tick": 0
		},
		"world": {
			"width": 10,
			"height": 10,
			"start_settlement_pos": [0, 0],
			"raider_camp_pos": [0, 0],
			"tiles": []
		},
		"buildings": [
			{
				"entity_id": 1,
				"definition_id": "town_hall",
				"tile_origin": [0, 0],
				"status": 1,
				"health": 500,
				"max_health": 500,
				"inventory": { "owner_id": 1, "capacity": 100, "quantities": {}, "reserved_out": {}, "reserved_in": {} },
				"assigned_workers": 0,
				"production_progress": 0.0,
				"construction_progress": 1.0,
				"construction_ticks": 0,
				"construction_required_ticks": 0,
				"construction_cost": {}
			},
			{
				"entity_id": 2,
				"definition_id": "farm",
				"tile_origin": [4, 4],
				"status": 1,
				"health": 100,
				"max_health": 100,
				"inventory": { "owner_id": 2, "capacity": 30, "quantities": {}, "reserved_out": {}, "reserved_in": {} },
				"assigned_workers": 0,
				"production_progress": 0.0,
				"construction_progress": 1.0,
				"construction_ticks": 0,
				"construction_required_ticks": 0,
				"construction_cost": {}
				# NOTE: "footprint" omitted!
			}
		],
		"citizens": [],
		"jobs": [],
		"military_units": []
	}

	for y in range(10):
		for x in range(10):
			legacy_save["world"]["tiles"].append({
				"terrain_id": "grass",
				"elevation": 0.0,
				"moisture": 0.5,
				"temperature": 0.5,
				"road_level": 0,
				"building_id": 0,
				"resource_deposit_id": "",
				"resource_amount": 0,
				"is_walkable": true,
				"is_buildable": true
			})

	var loaded: Dictionary = SaveSchema.deserialize(legacy_save)
	assert_true(not loaded.is_empty(), "Legacy save loaded cleanly")

	var farm: BuildingState = loaded["buildings"][1]
	assert_eq(farm.get_footprint(), Vector2i(3, 3), "Legacy farm defaulted to base 3x3 footprint")
	assert_eq(farm.get_entrance_tile(), Vector2i(4 + 1, 4 + 3), "Legacy farm entrance computed correctly")

	print("✓ Test 12: Backward compatibility with legacy saves verified")

# 13. Non-regression of existing systems
func test_non_regression_existing_systems() -> void:
	var world = _create_test_world()

	# Clear area around (10, 10)
	for y in range(8, 18):
		for x in range(8, 18):
			var tile: WorldTile = world.world_state.get_tile(Vector2i(x, y))
			if tile != null:
				tile.terrain_id = &"grass"
				tile.is_walkable = true
				tile.is_buildable = true
				tile.building_id = 0
				tile.road_level = 0
				tile.resource_deposit_id = &""
				tile.resource_amount = 0
				world.pathfinding.set_solid(Vector2i(x, y), false)

	# Verify skills system interacts properly with a custom 4x4 farm
	var farm = world.place_building(&"farm", Vector2i(10, 10), true, Vector2i(4, 4))
	var citizen: CitizenState = world.citizens[0]
	citizen.skills[&"farming"] = 80
	citizen.workplace_id = farm.entity_id
	citizen.role_id = &"farmer"

	# Skill factor for farming 80: 0.75 + 80 / 200.0 = 1.15
	var mult: float = citizen.get_skill_factor(&"farming")
	assert_true(is_equal_approx(mult, 1.15), "Farmer skill factor is 1.15")

	# Doorway routing to custom farm
	var route_res = world.pathfinding.find_path_to_entrance(citizen.position_tile, farm)
	assert_true(route_res.get("ok", false), "Find path to custom farm entrance succeeded")

	_cleanup_test_world(world)
	print("✓ Test 13: Non-regression of existing systems verified")
