extends SceneTree

func _init() -> void:
	print("--- Running TestCombat ---")
	test_unit_movement_order()
	test_melee_and_ranged_combat()
	test_starvation_debuff_and_upkeep()
	test_raiders_attack_buildings_without_defenders()
	test_move_order_routes_around_blocked_tiles()
	print("--- TestCombat PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_unit_movement_order() -> void:
	var combat: CombatSystem = CombatSystem.new()
	var unit: MilitaryUnitState = combat.spawn_player_unit(&"spearman", Vector2(100, 100))
	unit.set_move_order(Vector2(140, 100)) # 40 pixels to the right
	
	# Spearman speed is 38 px/sec. After 1 second:
	combat.tick_combat([unit], 1.0)
	assert_true(unit.position.x > 135.0, "Unit should have advanced toward destination")
	
	# After another 0.5 sec, reaches destination and switches to HOLD
	combat.tick_combat([unit], 0.5)
	assert_eq(unit.order_type, MilitaryUnitState.OrderType.HOLD)

func test_melee_and_ranged_combat() -> void:
	var combat: CombatSystem = CombatSystem.new()
	var archer: MilitaryUnitState = combat.spawn_player_unit(&"archer", Vector2(100, 100))
	var raider: MilitaryUnitState = combat.spawn_raider_unit(Vector2(160, 100)) # 60 px away
	var units: Array[MilitaryUnitState] = [archer, raider]
	
	# Archer range is 80 px -> Raider is in range without moving!
	# Raider range is 22 px -> Must approach
	archer.set_attack_target_order(raider.id)
	
	# Tick combat by 0.1s
	combat.tick_combat(units, 0.1)
	
	# Archer attacks raider (14 dmg, raider hp 90 -> 76)
	assert_eq(raider.health, 76, "Archer should hit raider from 60px range")
	assert_eq(archer.health, 70, "Raider could not hit archer yet (out of melee range)")

func test_starvation_debuff_and_upkeep() -> void:
	var combat: CombatSystem = CombatSystem.new()
	var spearman: MilitaryUnitState = combat.spawn_player_unit(&"spearman", Vector2(100, 100))
	var dummy_raider: MilitaryUnitState = combat.spawn_raider_unit(Vector2(110, 100)) # 10 px away
	var units: Array[MilitaryUnitState] = [spearman, dummy_raider]
	
	# Normal spearman attack (damage = 18)
	spearman.set_attack_target_order(dummy_raider.id)
	combat.tick_combat(units, 0.1)
	assert_eq(dummy_raider.health, 90 - 18, "Normal attack deals 18 damage")
	
	# Reset cooldown & mark starving
	spearman.attack_timer = 0.0
	spearman.is_starving = true
	var hp_before: int = dummy_raider.health
	combat.tick_combat(units, 0.1)
	var dealt_starving: int = hp_before - dummy_raider.health
	assert_eq(dealt_starving, 9, "Starving soldier deals only 50% damage (9 instead of 18)")
	
	# Upkeep test
	var storehouse_inv: Inventory = Inventory.new(99, 50, [&"bread"])
	storehouse_inv.add_resource(&"bread", 1, "PROVISION")
	combat.apply_military_upkeep([spearman], [storehouse_inv])
	assert_true(not spearman.is_starving, "Soldier is nourished when bread is available")
	assert_eq(storehouse_inv.get_quantity(&"bread"), 0, "Bread consumed for upkeep")

func test_raiders_attack_buildings_without_defenders() -> void:
	var combat: CombatSystem = CombatSystem.new()
	var town_hall: BuildingState = BuildingState.new(7, &"town_hall", 150, [&"coin", &"bread", &"grain", &"timber", &"stone"])
	town_hall.tile_origin = Vector2i(2, 2)
	town_hall.max_health = 300
	town_hall.health = 300
	var raider: MilitaryUnitState = combat.spawn_raider_unit(Vector2(20.0, 20.0))
	var units: Array[MilitaryUnitState] = [raider]
	var before: int = town_hall.health
	for _i in range(12):
		combat.tick_combat(units, 0.5, [town_hall])
	assert_true(town_hall.health < before, "Raiders must damage buildings when the settlement has no defenders")

func test_move_order_routes_around_blocked_tiles() -> void:
	var world := WorldState.new(10, 10, 2026)
	for y in range(world.height):
		for x in range(world.width):
			var coord := Vector2i(x, y)
			world.set_tile(coord, WorldTile.new(coord, &"grass", 0.6))
	var pathfinding := PathfindingService.new(world.width, world.height)
	pathfinding.initialize_from_world(world)
	for y in range(0, 9):
		pathfinding.set_solid(Vector2i(4, y), true)
	var combat := CombatSystem.new()
	var unit := combat.spawn_player_unit(&"spearman", Vector2(40.0, 40.0))
	unit.set_move_order(Vector2(120.0, 40.0))
	var units: Array[MilitaryUnitState] = [unit]
	var lowest_y: float = unit.position.y
	for _i in range(100):
		combat.tick_combat(units, 0.25, [], pathfinding)
		lowest_y = maxf(lowest_y, unit.position.y)
		var tile := Vector2i(floori(unit.position.x / 16.0), floori(unit.position.y / 16.0))
		assert_true(not pathfinding.astar_grid.is_point_solid(tile), "Unit must not cross a blocked tile")
	assert_true(lowest_y > 40.0, "Unit should route around the vertical wall instead of walking straight through")
	assert_true(unit.position.distance_to(Vector2(120.0, 40.0)) < 3.0, "Unit should eventually reach its move destination")
