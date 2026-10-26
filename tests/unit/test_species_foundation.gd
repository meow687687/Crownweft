extends SceneTree

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SpeciesCatalog = preload("res://scripts/domain/species_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const ProductionSystem = preload("res://scripts/simulation/production_system.gd")
const ConstructionSystem = preload("res://scripts/simulation/construction_system.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldScene = preload("res://scenes/world/world.gd")
const JobBoard = preload("res://scripts/simulation/job_board.gd")
const EconomyState = preload("res://scripts/domain/economy_state.gd")

func _init() -> void:
	print("--- Running TestSpeciesFoundation ---")
	test_1_species_definitions_valid_and_unique()
	test_2_citizen_valid_species_assignment()
	test_3_older_saves_load_safely_with_default_species()
	test_4_species_modifiers_affect_intended_activities()
	test_5_experienced_generalist_outperforms_inexperienced_specialist()
	test_6_skills_and_outputs_remain_within_defined_bounds()
	test_7_auto_staffing_works_for_all_species()
	test_8_energy_and_rest_continue_to_work_for_all_species()
	test_9_save_load_round_trip_preserves_species_and_attributes()
	test_10_non_regression_and_workforce_data()
	print("--- TestSpeciesFoundation PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_1_species_definitions_valid_and_unique() -> void:
	var defs: Dictionary = SpeciesCatalog.get_all_defs()
	assert_true(defs.size() >= 3, "Species catalog must contain at least 3 species")
	
	var seen_ids: Dictionary = {}
	for sp_id: StringName in SpeciesCatalog.SPECIES_IDS:
		assert_true(defs.has(sp_id), "Catalog must contain definition for %s" % str(sp_id))
		assert_true(not seen_ids.has(sp_id), "Species ID %s must be unique" % str(sp_id))
		seen_ids[sp_id] = true
		
		var d: Dictionary = defs[sp_id]
		assert_eq(d.get("id"), sp_id, "Definition ID must match key")
		assert_true(str(d.get("display_name", "")).strip_edges() != "", "Display name must not be empty")
		assert_true(str(d.get("description", "")).strip_edges() != "", "Description must not be empty")
		assert_true(d.has("advantages") and d["advantages"] is Array, "Must have advantages array")
		assert_true(d.has("disadvantages") and d["disadvantages"] is Array, "Must have disadvantages array")
		assert_true(float(d.get("energy_drain_modifier", 0.0)) > 0.0, "Energy drain modifier must be positive")
		assert_true(float(d.get("energy_recovery_modifier", 0.0)) > 0.0, "Energy recovery modifier must be positive")
	print("✓ Test 1: Species definitions valid and unique PASSED")

func test_2_citizen_valid_species_assignment() -> void:
	var c_default := CitizenState.new(1)
	assert_eq(c_default.species_id, SpeciesCatalog.DEFAULT_SPECIES_ID, "Default citizen must be Human")
	
	var c_stone := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"stoneborn")
	assert_eq(c_stone.species_id, &"stoneborn", "Citizen must be Stoneborn")
	
	var c_green := CitizenState.new(3, Vector2i.ZERO, &"unassigned", &"greenwarden")
	assert_eq(c_green.species_id, &"greenwarden", "Citizen must be Greenwarden")
	
	var c_invalid := CitizenState.new(4, Vector2i.ZERO, &"unassigned", &"unknown_alien")
	assert_eq(c_invalid.species_id, SpeciesCatalog.DEFAULT_SPECIES_ID, "Invalid species must normalize to Human")
	
	# Verify starting skills incorporate species modifiers
	var c_h := CitizenState.new(10, Vector2i.ZERO, &"unassigned", &"human")
	var c_s := CitizenState.new(10, Vector2i.ZERO, &"unassigned", &"stoneborn")
	var c_g := CitizenState.new(10, Vector2i.ZERO, &"unassigned", &"greenwarden")
	
	# Masonry starting skill bonus for Stoneborn (+10) vs Greenwarden
	assert_true(c_s.get_skill(&"masonry") > c_h.get_skill(&"masonry"), "Stoneborn should have higher starting masonry than Human")
	assert_true(c_g.get_skill(&"farming") > c_h.get_skill(&"farming"), "Greenwarden should have higher starting farming than Human")
	print("✓ Test 2: Citizen valid species assignment PASSED")

func test_3_older_saves_load_safely_with_default_species() -> void:
	# Simulate legacy save data where 'species_id' is missing
	var legacy_citizen_data: Dictionary = {
		"id": 99,
		"position_tile": [10, 12],
		"target_tile": [10, 12],
		"role_id": "unassigned",
		"home_building_id": 0,
		"workplace_id": 0,
		"move_state": 0,
		"hunger_counter": 0,
		"food_state": 0,
		"carried_resource": "",
		"carried_amount": 0,
		"active_job_id": 0,
		"current_block_reason": "",
		"energy": 100.0,
		"is_resting": false,
		"skills": {
			"farming": 55.0,
			"forestry": 50.0,
			"masonry": 45.0,
			"crafting": 50.0,
			"hauling": 50.0
		}
	}
	
	var save_dict: Dictionary = {
		"version": 4,
		"meta": {"seed_val": 2026, "timestamp": 12345},
		"world": {"width": 10, "height": 10, "tiles": []},
		"economy": {},
		"buildings": [],
		"citizens": [legacy_citizen_data],
		"military_units": [],
		"jobs": []
	}
	
	var restored: Dictionary = SaveSchema.deserialize(save_dict)
	var loaded_citizens: Array = restored["citizens"]
	assert_eq(loaded_citizens.size(), 1, "Should deserialize 1 citizen")
	var c: CitizenState = loaded_citizens[0]
	assert_eq(c.species_id, SpeciesCatalog.DEFAULT_SPECIES_ID, "Missing species_id must default safely to Human")
	assert_eq(c.get_skill(&"farming"), 55.0, "Saved skills must be preserved")
	print("✓ Test 3: Older saves load safely with default species PASSED")

func test_4_species_modifiers_affect_intended_activities() -> void:
	var human := CitizenState.new(1, Vector2i.ZERO, &"unassigned", &"human")
	var stoneborn := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"stoneborn")
	var greenwarden := CitizenState.new(3, Vector2i.ZERO, &"unassigned", &"greenwarden")
	
	human.set_skill(&"masonry", 50.0)
	stoneborn.set_skill(&"masonry", 50.0)
	greenwarden.set_skill(&"masonry", 50.0)
	
	# Base factor at skill 50 is 1.00
	var h_factor: float = human.get_skill_factor(&"masonry")
	var s_factor: float = stoneborn.get_skill_factor(&"masonry")
	var g_factor: float = greenwarden.get_skill_factor(&"masonry")
	
	assert_eq(h_factor, 1.00, "Human masonry factor at skill 50 must be 1.00")
	assert_true(s_factor > h_factor, "Stoneborn masonry factor (%.2f) must exceed Human (%.2f)" % [s_factor, h_factor])
	assert_true(g_factor < h_factor, "Greenwarden masonry factor (%.2f) must be lower than Human (%.2f)" % [g_factor, h_factor])
	
	# Test Farming/Forestry
	human.set_skill(&"farming", 50.0)
	stoneborn.set_skill(&"farming", 50.0)
	greenwarden.set_skill(&"farming", 50.0)
	
	var h_farm: float = human.get_skill_factor(&"farming")
	var s_farm: float = stoneborn.get_skill_factor(&"farming")
	var g_farm: float = greenwarden.get_skill_factor(&"farming")
	
	assert_eq(h_farm, 1.00, "Human farming factor at skill 50 must be 1.00")
	assert_true(g_farm > h_farm, "Greenwarden farming factor (%.2f) must exceed Human (%.2f)" % [g_farm, h_farm])
	assert_true(s_farm < h_farm, "Stoneborn farming factor (%.2f) must be lower than Human (%.2f)" % [s_farm, h_farm])
	print("✓ Test 4: Species modifiers affect intended activities PASSED")

func test_5_experienced_generalist_outperforms_inexperienced_specialist() -> void:
	var exp_human := CitizenState.new(101, Vector2i.ZERO, &"unassigned", &"human")
	var novice_stoneborn := CitizenState.new(102, Vector2i.ZERO, &"unassigned", &"stoneborn")
	
	# Experienced human has skill 80
	exp_human.set_skill(&"masonry", 80.0)
	# Novice Stoneborn has skill 20
	novice_stoneborn.set_skill(&"masonry", 20.0)
	
	var human_eff: float = exp_human.get_skill_factor(&"masonry")
	var stoneborn_eff: float = novice_stoneborn.get_skill_factor(&"masonry")
	
	# Human: 0.75 + 80/200 + 0 = 1.15
	# Stoneborn: 0.75 + 20/200 + 0.12 = 0.97
	assert_true(human_eff > stoneborn_eff, "Experienced Human (%.2f) must outperform Novice Stoneborn (%.2f)" % [human_eff, stoneborn_eff])
	
	# In forestry: Experienced human (80) vs Novice Greenwarden (20)
	var novice_greenwarden := CitizenState.new(103, Vector2i.ZERO, &"unassigned", &"greenwarden")
	exp_human.set_skill(&"forestry", 80.0)
	novice_greenwarden.set_skill(&"forestry", 20.0)
	
	var human_for: float = exp_human.get_skill_factor(&"forestry")
	var green_for: float = novice_greenwarden.get_skill_factor(&"forestry")
	assert_true(human_for > green_for, "Experienced Human (%.2f) must outperform Novice Greenwarden (%.2f)" % [human_for, green_for])
	print("✓ Test 5: Experienced generalist outperforms inexperienced specialist PASSED")

func test_6_skills_and_outputs_remain_within_defined_bounds() -> void:
	var c := CitizenState.new(50, Vector2i.ZERO, &"unassigned", &"stoneborn")
	
	# Underflow clamp
	c.set_skill(&"masonry", -50.0)
	assert_eq(c.get_skill(&"masonry"), 0.0, "Skill cannot drop below 0.0")
	
	# Overflow clamp
	c.set_skill(&"masonry", 250.0)
	assert_eq(c.get_skill(&"masonry"), 100.0, "Skill cannot exceed 100.0")
	
	# Factor clamping under extreme bounds
	c.set_skill(&"masonry", 0.0)
	var min_factor: float = c.get_skill_factor(&"masonry")
	assert_true(min_factor >= 0.60, "Skill factor must not drop below 0.60")
	
	c.set_skill(&"masonry", 100.0)
	var max_factor: float = c.get_skill_factor(&"masonry")
	assert_true(max_factor <= 1.45, "Skill factor must not exceed 1.45")
	print("✓ Test 6: Skills and outputs remain within defined bounds PASSED")

func test_7_auto_staffing_works_for_all_species() -> void:
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()
	
	# Create a quarry requiring masonry
	var quarry: BuildingState = BuildingState.new(10, &"quarry", 50, [&"stone"])
	quarry.tile_origin = Vector2i(5, 5)
	quarry.footprint = Vector2i(2, 2)
	quarry.status = BuildingState.Status.ACTIVE
	world.buildings.append(quarry)
	
	# Add one Greenwarden and one Stoneborn at equal distance and equal base skill (50)
	var greenwarden: CitizenState = CitizenState.new(1, Vector2i(5, 6), &"unassigned", &"greenwarden")
	greenwarden.set_skill(&"masonry", 50.0)
	var stoneborn: CitizenState = CitizenState.new(2, Vector2i(5, 6), &"unassigned", &"stoneborn")
	stoneborn.set_skill(&"masonry", 50.0)
	
	world.citizens.append(greenwarden)
	world.citizens.append(stoneborn)
	
	# With 1 slot needed, Stoneborn should be selected first due to higher effective masonry
	quarry.assigned_workers = 1 # 1 out of 2 slots filled
	world.auto_staff_workplaces()
	
	assert_eq(stoneborn.workplace_id, quarry.entity_id, "Stoneborn should be prioritized for masonry when skills are equal")
	assert_eq(greenwarden.workplace_id, 0, "Greenwarden should remain unassigned when only 1 slot was needed")
	
	# Now open another slot: Greenwarden MUST be assignable and not disqualified
	quarry.assigned_workers = 1 # open 1 slot
	stoneborn.workplace_id = 99 # already busy elsewhere
	world.auto_staff_workplaces()
	assert_eq(greenwarden.workplace_id, quarry.entity_id, "Greenwarden must be assignable to masonry when needed")
	
	world.free()
	print("✓ Test 7: Auto-staffing works for all species without disqualification PASSED")

func test_8_energy_and_rest_continue_to_work_for_all_species() -> void:
	var human := CitizenState.new(1, Vector2i.ZERO, &"unassigned", &"human")
	var stoneborn := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"stoneborn")
	var greenwarden := CitizenState.new(3, Vector2i.ZERO, &"unassigned", &"greenwarden")
	
	human.energy = 100.0
	stoneborn.energy = 100.0
	greenwarden.energy = 100.0
	
	# Consume 10 energy
	human.consume_energy(10.0)
	stoneborn.consume_energy(10.0)
	greenwarden.consume_energy(10.0)
	
	# Stoneborn has drain_mod 0.90 -> consumes 9.0 -> remaining 91.0
	assert_eq(human.energy, 90.0, "Human should lose 10.0 energy")
	assert_true(stoneborn.energy > human.energy, "Stoneborn (%.1f) should retain more energy than Human (%.1f)" % [stoneborn.energy, human.energy])
	assert_eq(stoneborn.energy, 91.0, "Stoneborn energy should be 91.0")
	
	# Restore energy: Human vs Greenwarden
	human.energy = 50.0
	greenwarden.energy = 50.0
	human.restore_energy(10.0)
	greenwarden.restore_energy(10.0)
	
	# Greenwarden has rec_mod 1.15 -> restores 11.5 -> energy 61.5
	assert_eq(human.energy, 60.0, "Human should restore 10.0 energy to 60.0")
	assert_true(greenwarden.energy > human.energy, "Greenwarden (%.1f) should recover faster than Human (%.1f)" % [greenwarden.energy, human.energy])
	assert_eq(greenwarden.energy, 61.5, "Greenwarden energy should be 61.5")
	print("✓ Test 8: Energy and rest continue to work for all species PASSED")

func test_9_save_load_round_trip_preserves_species_and_attributes() -> void:
	var world_state := WorldState.new(10, 10)
	var economy := EconomyState.new()
	var job_board := JobBoard.new()
	var buildings: Array[BuildingState] = []
	var military_units: Array[MilitaryUnitState] = []
	var citizens: Array[CitizenState] = [
		CitizenState.new(1, Vector2i(2, 3), &"builder", &"human"),
		CitizenState.new(2, Vector2i(4, 5), &"farmer", &"greenwarden"),
		CitizenState.new(3, Vector2i(6, 7), &"miner", &"stoneborn")
	]
	
	citizens[1].energy = 84.5
	citizens[1].set_skill(&"farming", 72.0)
	citizens[2].energy = 65.0
	citizens[2].set_skill(&"masonry", 78.0)
	
	var serialized: Dictionary = SaveSchema.serialize(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		1,
		1.0,
		false
	)
	
	var deserialized: Dictionary = SaveSchema.deserialize(serialized)
	var loaded_citizens: Array = deserialized["citizens"]
	assert_eq(loaded_citizens.size(), 3, "All 3 citizens must be deserialized")
	
	assert_eq(loaded_citizens[0].species_id, &"human", "Citizen 1 must remain Human")
	assert_eq(loaded_citizens[1].species_id, &"greenwarden", "Citizen 2 must remain Greenwarden")
	assert_eq(loaded_citizens[2].species_id, &"stoneborn", "Citizen 3 must remain Stoneborn")
	
	assert_eq(loaded_citizens[1].get_skill(&"farming"), 72.0, "Citizen 2 farming skill must be preserved")
	assert_eq(loaded_citizens[2].get_skill(&"masonry"), 78.0, "Citizen 3 masonry skill must be preserved")
	assert_eq(loaded_citizens[1].energy, 84.5, "Citizen 2 energy must be preserved")
	assert_eq(loaded_citizens[2].energy, 65.0, "Citizen 3 energy must be preserved")
	print("✓ Test 9: Save/load round-trip preserves species and attributes PASSED")

func test_10_non_regression_and_workforce_data() -> void:
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()
	
	var c_s := world.spawn_citizen(Vector2i(1, 1), &"builder", &"stoneborn")
	var c_g := world.spawn_citizen(Vector2i(2, 2), &"farmer", &"greenwarden")
	
	assert_eq(c_s.species_id, &"stoneborn", "Spawned citizen 1 must be Stoneborn")
	assert_eq(c_g.species_id, &"greenwarden", "Spawned citizen 2 must be Greenwarden")
	
	var wf_data: Array[Dictionary] = world.get_workforce_citizens_data()
	assert_eq(wf_data.size(), 2, "Workforce data must contain 2 entries")
	assert_eq(wf_data[0]["species_id"], &"stoneborn", "Workforce entry 1 species_id must be stoneborn")
	assert_eq(wf_data[0]["species_name"], "Stoneborn", "Workforce entry 1 species_name must be Stoneborn")
	assert_eq(wf_data[1]["species_id"], &"greenwarden", "Workforce entry 2 species_id must be greenwarden")
	assert_eq(wf_data[1]["species_name"], "Greenwarden", "Workforce entry 2 species_name must be Greenwarden")
	
	world.free()
	print("✓ Test 10: Non-regression and workforce data PASSED")
