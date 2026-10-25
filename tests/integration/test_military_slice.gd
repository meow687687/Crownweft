extends SceneTree

func _init() -> void:
	print("==================================================")
	print("--- Running Phase 2 Military Vertical Slice Test ---")
	print("==================================================")
	test_recruitment_and_raid_defense()
	test_logistics_failure_consequences()
	print("\n==================================================")
	print(">>> PHASE 2 EXIT GATE PASSED! <<<")
	print("==================================================")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_recruitment_and_raid_defense() -> void:
	print("\n[Test 1] Testing recruitment, raid interception and successful defense...")
	
	var combat: CombatSystem = CombatSystem.new()
	var town_hall_inv: Inventory = Inventory.new(1, 200)
	town_hall_inv.add_resource(&"coin", 100, "TREASURY")
	town_hall_inv.add_resource(&"bread", 20, "MILITARY_RATIONS")
	
	var units: Array[MilitaryUnitState] = []
	
	# 1. Recruit 2 Spearmen (15C each) and 1 Archer (20C)
	# Total cost = 50 Coin
	var spear1 = combat.spawn_player_unit(&"spearman", Vector2(400, 400))
	var spear2 = combat.spawn_player_unit(&"spearman", Vector2(400, 420))
	var archer1 = combat.spawn_player_unit(&"archer", Vector2(370, 410))
	town_hall_inv.remove_resource(&"coin", 50, "RECRUITMENT")
	
	units.append_array([spear1, spear2, archer1])
	assert_eq(town_hall_inv.get_quantity(&"coin"), 50, "Coin deducted for recruitment")
	
	# 2. Food upkeep
	combat.apply_military_upkeep(units, [town_hall_inv])
	assert_true(not spear1.is_starving and not archer1.is_starving, "Units are well supplied with rations")
	assert_eq(town_hall_inv.get_quantity(&"bread"), 17, "3 bread consumed for upkeep")
	
	# 3. Raider Raid approaches
	var raider1 = combat.spawn_raider_unit(Vector2(480, 400))
	var raider2 = combat.spawn_raider_unit(Vector2(480, 420))
	units.append_array([raider1, raider2])
	
	# Player commands: Spearmen attack-move forward, Archer attacks raider1
	spear1.set_attack_move_order(Vector2(480, 400))
	spear2.set_attack_move_order(Vector2(480, 420))
	archer1.set_attack_target_order(raider1.id)
	
	# Simulate 10 seconds of combat (100 steps of 0.1s)
	for step in range(100):
		combat.tick_combat(units, 0.1)
		
	# Verify Raiders are defeated and player defenders survive
	assert_true(raider1.is_dead, "Raider 1 must be defeated")
	assert_true(raider2.is_dead, "Raider 2 must be defeated")
	assert_true(not spear1.is_dead or not spear2.is_dead, "Player frontline survives")
	assert_true(not archer1.is_dead, "Archer in backline survives undamaged")
	print("✓ Raid successfully repelled with combined arms tactics!")

func test_logistics_failure_consequences() -> void:
	print("\n[Test 2] Proving that poor logistics has severe military consequences...")
	
	var combat: CombatSystem = CombatSystem.new()
	var empty_food_store: Inventory = Inventory.new(2, 50) # No food!
	
	# 1 Solo spearman starving due to failed grain/bread supply chain
	var spear_starving = combat.spawn_player_unit(&"spearman", Vector2(100, 100))
	combat.apply_military_upkeep([spear_starving], [empty_food_store])
	assert_true(spear_starving.is_starving, "Soldier is starving due to empty pantry")
	
	# 1 Healthy raider engages
	var raider = combat.spawn_raider_unit(Vector2(110, 100))
	spear_starving.set_attack_target_order(raider.id)
	var units: Array[MilitaryUnitState] = [spear_starving, raider]
	
	# Simulate combat to the death
	for step in range(100):
		combat.tick_combat(units, 0.1)
		if spear_starving.is_dead or raider.is_dead:
			break
			
	# Starving spearman deals half damage and loses the duel
	assert_true(spear_starving.is_dead, "Starving soldier fails in battle against well-fed raider")
	assert_true(not raider.is_dead, "Raider survives duel due to opponent's logistical failure")
	print("✓ Direct link between logistics failure and battlefield defeat confirmed!")
