extends SceneTree

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const ProductionSystem = preload("res://scripts/simulation/production_system.gd")
const ConstructionSystem = preload("res://scripts/simulation/construction_system.gd")
const LogisticsSystem = preload("res://scripts/simulation/logistics_system.gd")
const PathfindingService = preload("res://scripts/simulation/pathfinding_service.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
const RecipeDef = preload("res://scripts/domain/recipe_def.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldTile = preload("res://scripts/domain/world_tile.gd")

func _init() -> void:
	print("--- Running TestCitizenSkillsNeeds ---")
	test_1_starting_skills()
	test_2_skill_clamping_and_bounded_formula()
	test_3_farming_skill_affects_farming()
	test_4_forestry_skill_affects_harvesting_and_output()
	test_5_masonry_skill_affects_construction_labor()
	test_6_crafting_and_hauling_effects()
	test_7_and_11_experience_gains_and_blocked_prevention()
	test_8_energy_decrease_and_recovery()
	test_9_exhausted_citizen_seeks_rest_and_resumes_job()
	test_10_homeless_citizen_cannot_rest_diagnostic()
	test_12_save_load_preserves_skills_energy_and_handles_legacy()
	print("--- TestCitizenSkillsNeeds PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_1_starting_skills() -> void:
	var c1 := CitizenState.new(1)
	var c2 := CitizenState.new(2)
	
	for s in CitizenState.SKILL_NAMES:
		assert_true(c1.skills.has(s), "Citizen 1 must have starting skill %s" % str(s))
		assert_true(c2.skills.has(s), "Citizen 2 must have starting skill %s" % str(s))
		assert_true(c1.get_skill(s) >= 0.0 and c1.get_skill(s) <= 100.0, "Skill %s must be within [0, 100]" % str(s))
		assert_true(c2.get_skill(s) >= 0.0 and c2.get_skill(s) <= 100.0, "Skill %s must be within [0, 100]" % str(s))

	# Verify there is variation between individuals
	var has_difference: bool = false
	for s in CitizenState.SKILL_NAMES:
		if c1.get_skill(s) != c2.get_skill(s):
			has_difference = true
			break
	assert_true(has_difference, "Starting skills should have sensible variation between citizens")
	print("✓ Test 1: Starting skills and individual variation PASSED")

func test_2_skill_clamping_and_bounded_formula() -> void:
	var c := CitizenState.new(10)
	c.set_skill(&"farming", 150.0)
	assert_eq(c.get_skill(&"farming"), 100.0, "Skill should clamp to 100 max")
	c.set_skill(&"farming", -20.0)
	assert_eq(c.get_skill(&"farming"), 0.0, "Skill should clamp to 0 min")
	
	# Bounded formula: 0.75 + skill / 200.0
	c.set_skill(&"forestry", 0.0)
	assert_true(is_equal_approx(c.get_skill_factor(&"forestry"), 0.75), "Skill 0 factor must be 0.75")
	c.set_skill(&"forestry", 50.0)
	assert_true(is_equal_approx(c.get_skill_factor(&"forestry"), 1.00), "Skill 50 factor must be 1.00 (baseline)")
	c.set_skill(&"forestry", 100.0)
	assert_true(is_equal_approx(c.get_skill_factor(&"forestry"), 1.25), "Skill 100 factor must be 1.25")
	print("✓ Test 2: Skill clamping and bounded formula PASSED")

func test_3_farming_skill_affects_farming() -> void:
	var prod := ProductionSystem.new()
	var recipe := RecipeDef.new(&"grow_grain", {}, {&"grain": 3}, 1, 6) # 6 ticks duration
	
	# Farm A with Master Farmer (skill 100 -> factor 1.25)
	var farm_a := BuildingState.new(1, &"farm", 30, [&"grain"])
	var master_farmer := CitizenState.new(101)
	master_farmer.set_skill(&"farming", 100.0)
	
	# Farm B with Novice Farmer (skill 0 -> factor 0.75)
	var farm_b := BuildingState.new(2, &"farm", 30, [&"grain"])
	var novice_farmer := CitizenState.new(102)
	novice_farmer.set_skill(&"farming", 0.0)
	
	# Run 4 ticks for both
	for t in range(4):
		prod.tick_building(farm_a, recipe, null, 1, [master_farmer])
		prod.tick_building(farm_b, recipe, null, 1, [novice_farmer])
		
	# Over 4 ticks:
	# Master Farmer (1.25 * 4 = 5.0) -> production_progress should be 5
	# Novice Farmer (0.75 * 4 = 3.0) -> production_progress should be 3
	assert_eq(farm_a.production_progress, 5, "Master farmer should advance 5 progress in 4 ticks")
	assert_eq(farm_b.production_progress, 3, "Novice farmer should advance 3 progress in 4 ticks")
	print("✓ Test 3: Farming skill affects farming progress PASSED")

func test_4_forestry_skill_affects_harvesting_and_output() -> void:
	var prod := ProductionSystem.new()
	var recipe := RecipeDef.new(&"chop_wood", {}, {&"timber": 2}, 1, 4)
	
	var world := WorldState.new(10, 10, 123)
	for y in range(10):
		for x in range(10):
			var tile := WorldTile.new(Vector2i(x, y), &"grass", 0.5)
			world.set_tile(Vector2i(x, y), tile)
	# Forest deposit next to woodcutter
	var tree_tile := world.get_tile(Vector2i(2, 2))
	tree_tile.resource_deposit_id = &"trees"
	tree_tile.resource_amount = 10
	
	# Master Forester (skill 100)
	var wc_master := BuildingState.new(10, &"woodcutter", 30, [&"timber"])
	wc_master.tile_origin = Vector2i(2, 3)
	var forester_master := CitizenState.new(201)
	forester_master.set_skill(&"forestry", 100.0)
	
	# Complete one cycle for master
	while wc_master.inventory.get_quantity(&"timber") == 0:
		prod.tick_building(wc_master, recipe, world, 1, [forester_master])
	
	# Master should receive 3 timber (base 2 + 1 bonus yield)
	assert_eq(wc_master.inventory.get_quantity(&"timber"), 3, "Skilled forester gets bonus timber output (3 instead of 2)")
	
	# Novice Forester (skill 0)
	var wc_novice := BuildingState.new(11, &"woodcutter", 30, [&"timber"])
	wc_novice.tile_origin = Vector2i(2, 3)
	var forester_novice := CitizenState.new(202)
	forester_novice.set_skill(&"forestry", 0.0)
	
	while wc_novice.inventory.get_quantity(&"timber") == 0:
		prod.tick_building(wc_novice, recipe, world, 1, [forester_novice])
		
	# Novice receives 1 timber (penalized yield)
	assert_eq(wc_novice.inventory.get_quantity(&"timber"), 1, "Novice forester gets reduced timber output (1 instead of 2)")
	print("✓ Test 4: Forestry skill affects harvesting and output PASSED")

func test_5_masonry_skill_affects_construction_labor() -> void:
	var construction := ConstructionSystem.new()
	var cost := {&"timber": 2}
	
	# Site A with Master Mason (skill 100 -> factor 1.25)
	var site_a := construction.create_construction_site(1, &"house", Vector2i(2, 2), cost, 12, 1001)
	site_a.construction_inventory.add_resource(&"timber", 2, "SUPPLY")
	var master_mason := CitizenState.new(301)
	master_mason.set_skill(&"masonry", 100.0)
	
	# Site B with Novice Mason (skill 0 -> factor 0.75)
	var site_b := construction.create_construction_site(2, &"house", Vector2i(6, 2), cost, 12, 1002)
	site_b.construction_inventory.add_resource(&"timber", 2, "SUPPLY")
	var novice_mason := CitizenState.new(302)
	novice_mason.set_skill(&"masonry", 0.0)
	
	# Tick both for 4 ticks
	for t in range(4):
		construction.tick_building(site_a, 1, t, [master_mason])
		construction.tick_building(site_b, 1, t, [novice_mason])
		
	# Over 4 ticks:
	# Master mason (1.25 * 4 = 5.0 labor) -> 5 construction ticks
	# Novice mason (0.75 * 4 = 3.0 labor) -> 3 construction ticks
	assert_eq(site_a.construction_ticks, 5, "Master mason must deliver 5 ticks of labor in 4 ticks")
	assert_eq(site_b.construction_ticks, 3, "Novice mason must deliver 3 ticks of labor in 4 ticks")
	print("✓ Test 5: Masonry affects construction labor PASSED")

func test_6_crafting_and_hauling_effects() -> void:
	var prod := ProductionSystem.new()
	var recipe := RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 4)
	
	var bakery_fast := BuildingState.new(20, &"bakery", 30, [&"grain", &"bread"])
	bakery_fast.inventory.add_resource(&"grain", 2, "INPUT")
	var master_baker := CitizenState.new(401)
	master_baker.set_skill(&"crafting", 100.0)
	
	var bakery_slow := BuildingState.new(21, &"bakery", 30, [&"grain", &"bread"])
	bakery_slow.inventory.add_resource(&"grain", 2, "INPUT")
	var novice_baker := CitizenState.new(402)
	novice_baker.set_skill(&"crafting", 0.0)
	
	for t in range(4):
		prod.tick_building(bakery_fast, recipe, null, 1, [master_baker])
		prod.tick_building(bakery_slow, recipe, null, 1, [novice_baker])
		
	assert_true(bakery_fast.inventory.get_quantity(&"bread") == 2, "Master baker completed 4-tick recipe in 4 ticks (accumulated 5.0)")
	assert_true(bakery_slow.inventory.get_quantity(&"bread") == 0, "Novice baker has not completed 4-tick recipe yet (accumulated 3.0)")
	print("✓ Test 6: Crafting skill affects production cycle PASSED")

func test_7_and_11_experience_gains_and_blocked_prevention() -> void:
	var prod := ProductionSystem.new()
	var recipe_grain := RecipeDef.new(&"grow_grain", {}, {&"grain": 3}, 1, 6)
	
	var citizen := CitizenState.new(501)
	citizen.set_skill(&"farming", 20.0)
	
	# Case A: Active work advances and grants experience
	var farm := BuildingState.new(30, &"farm", 30, [&"grain"])
	prod.tick_building(farm, recipe_grain, null, 1, [citizen])
	assert_true(citizen.get_skill(&"farming") > 20.0, "Active work must grant experience")
	
	# Test diminishing returns
	var novice := CitizenState.new(502)
	novice.set_skill(&"farming", 10.0)
	var gain_novice: float = novice.gain_experience(&"farming", 1.0)
	
	var master := CitizenState.new(503)
	master.set_skill(&"farming", 90.0)
	var gain_master: float = master.gain_experience(&"farming", 1.0)
	
	assert_true(gain_novice > gain_master, "Training must have diminishing returns near upper limit")
	
	# Case B: Blocked / waiting worker must NOT gain experience (Requirement 11)
	var recipe_bread := RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 4)
	var blocked_citizen := CitizenState.new(504)
	blocked_citizen.set_skill(&"crafting", 45.0)
	var blocked_bakery := BuildingState.new(31, &"bakery", 30, [&"grain", &"bread"])
	# Missing inputs (no grain): bakery is blocked
	prod.tick_building(blocked_bakery, recipe_bread, null, 1, [blocked_citizen])
	assert_eq(blocked_bakery.current_block_reason, &"MISSING_INPUTS")
	assert_eq(blocked_citizen.get_skill(&"crafting"), 45.0, "Blocked worker must NOT gain experience")
	print("✓ Test 7 & 11: Experience gain rules and blocked prevention PASSED")

func test_8_energy_decrease_and_recovery() -> void:
	var citizen := CitizenState.new(601)
	citizen.energy = 100.0
	
	# Working consumes energy
	citizen.consume_energy(CitizenState.WORK_ENERGY_DRAIN)
	assert_true(citizen.energy < 100.0, "Working must consume energy")
	assert_true(is_equal_approx(citizen.energy, 99.5), "Energy should decrease by WORK_ENERGY_DRAIN (0.5)")
	
	# Resting restores energy
	citizen.restore_energy(CitizenState.REST_ENERGY_RECOVERY)
	assert_eq(citizen.energy, 100.0, "Energy cannot exceed 100.0")
	
	# Clamping at 0
	citizen.consume_energy(200.0)
	assert_eq(citizen.energy, 0.0, "Energy cannot drop below 0.0")
	assert_true(citizen.is_exhausted(), "Energy 0 must be considered exhausted")
	print("✓ Test 8: Energy decrease during work and recovery during rest PASSED")

func test_9_exhausted_citizen_seeks_rest_and_resumes_job() -> void:
	var world_scene = load("res://scenes/world/world.tscn").instantiate()
	world_scene._init_simulation()
	var house: BuildingState = world_scene.place_building(&"house", Vector2i(10, 10), true)
	assert_true(house != null, "House placed")
	
	var c: CitizenState = world_scene.citizens[0]
	c.workplace_id = 999 # Simulated assigned workplace
	c.role_id = &"worker"
	c.energy = 15.0 # Below exhaustion threshold (20)
	assert_true(c.is_exhausted(), "Citizen is exhausted")
	
	# Tick world simulation
	world_scene._update_housing_and_rest()
	assert_eq(c.home_building_id, house.entity_id, "Citizen must be assigned to active house")
	assert_true(c.is_resting, "Exhausted citizen must enter resting state")
	assert_eq(c.workplace_id, 999, "Resting must NOT erase workplace assignment")
	
	# Simulate arrival at home and resting to recovery
	var home_ent: Vector2i = house.get_entrance_tile()
	c.position_tile = home_ent
	
	while c.is_resting:
		world_scene._update_housing_and_rest()
		
	assert_true(c.energy >= CitizenState.RECOVERY_THRESHOLD, "Citizen recovered energy past recovery threshold")
	assert_true(not c.is_resting, "Citizen resumed active state")
	assert_eq(c.workplace_id, 999, "Workplace assignment preserved after recovery")
	world_scene.queue_free()
	print("✓ Test 9: Exhausted citizen seeks rest and resumes job PASSED")

func test_10_homeless_citizen_cannot_rest_diagnostic() -> void:
	var world_scene = load("res://scenes/world/world.tscn").instantiate()
	world_scene._init_simulation()
	# No houses exist in world
	var c: CitizenState = world_scene.citizens[0]
	c.home_building_id = 0
	c.energy = 10.0
	assert_true(c.is_exhausted())
	
	world_scene._update_housing_and_rest()
	assert_true(c.is_resting, "Citizen wants to rest")
	assert_eq(c.current_block_reason, &"Cannot rest — no valid home assigned", "Must expose clear diagnostic reason when homeless")
	assert_eq(c.energy, 10.0, "Homeless citizen cannot recover energy without a home")
	world_scene.queue_free()
	print("✓ Test 10: Homeless citizen exposed diagnostic reason and does not teleport PASSED")

func test_12_save_load_preserves_skills_energy_and_handles_legacy() -> void:
	var c := CitizenState.new(777, Vector2i(5, 5), &"farmer")
	c.set_skill(&"farming", 82.5)
	c.set_skill(&"forestry", 67.0)
	c.energy = 38.0
	c.is_resting = true
	
	var serialized: Dictionary = SaveSchema.serialize(null, null, [], [c], [], null, 100, 1.0)
	var loaded: Dictionary = SaveSchema.deserialize(serialized)
	var loaded_citizens: Array = loaded["citizens"]
	assert_eq(loaded_citizens.size(), 1)
	var loaded_c: CitizenState = loaded_citizens[0]
	
	assert_eq(loaded_c.id, 777)
	assert_true(is_equal_approx(loaded_c.get_skill(&"farming"), 82.5), "Farming skill preserved")
	assert_true(is_equal_approx(loaded_c.get_skill(&"forestry"), 67.0), "Forestry skill preserved")
	assert_true(is_equal_approx(loaded_c.energy, 38.0), "Energy preserved")
	assert_eq(loaded_c.is_resting, true, "Resting status preserved")
	
	# Legacy save without skills/energy dictionary
	var legacy_data: Dictionary = {
		"meta": {"schema_version": 2},
		"citizens": [{
			"id": 888,
			"position_tile": [1, 1],
			"role_id": "unassigned"
		}]
	}
	var legacy_loaded: Dictionary = SaveSchema.deserialize(legacy_data)
	var leg_c: CitizenState = legacy_loaded["citizens"][0]
	assert_eq(leg_c.id, 888)
	assert_eq(leg_c.energy, 100.0, "Legacy save defaults energy to 100")
	assert_eq(leg_c.is_resting, false, "Legacy save defaults is_resting to false")
	for s in CitizenState.SKILL_NAMES:
		assert_true(leg_c.get_skill(s) >= 0.0 and leg_c.get_skill(s) <= 100.0, "Legacy save initializes valid starting skills")
	print("✓ Test 12: Save/load round-trip and legacy compatibility PASSED")
