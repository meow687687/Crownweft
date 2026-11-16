extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SpeciesCatalog = preload("res://scripts/domain/species_catalog.gd")
const SocialClassCatalog = preload("res://scripts/domain/social_class_catalog.gd")
const SocialClassService = preload("res://scripts/simulation/social_class_service.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const ProductionSystem = preload("res://scripts/simulation/production_system.gd")
const EconomyState = preload("res://scripts/domain/economy_state.gd")
const EconomySystem = preload("res://scripts/simulation/economy_system.gd")
const Inventory = preload("res://scripts/domain/inventory.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldScene = preload("res://scenes/world/world.gd")
const JobBoard = preload("res://scripts/simulation/job_board.gd")

func _init() -> void:
	print("--- Running TestSocialClasses ---")
	test_1_status_definitions_valid_and_unique()
	test_2_citizens_receive_valid_default_status()
	test_3_species_and_social_status_vary_independently()
	test_4_status_eligibility_and_role_restrictions()
	test_5_status_transitions_and_hauling_demotion()
	test_6_measurable_economic_and_service_modifiers()
	test_7_workforce_data_and_ui_state()
	test_8_save_load_round_trip_preserves_social_status()
	test_9_legacy_and_invalid_save_data_handling()
	test_10_automatic_social_advancement()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestSocialClasses PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_1_status_definitions_valid_and_unique() -> void:
	var defs: Dictionary = SocialClassCatalog.get_all_defs()
	assert_true(defs.size() >= 7, "Catalog must have at least 7 statuses")
	
	var seen: Dictionary = {}
	for st_id: StringName in SocialClassCatalog.STATUS_IDS:
		assert_true(defs.has(st_id), "Catalog must define %s" % str(st_id))
		assert_true(not seen.has(st_id), "Status ID %s must be unique" % str(st_id))
		seen[st_id] = true
		
		var d: Dictionary = defs[st_id]
		assert_eq(d.get("id"), st_id, "Def ID must match key")
		assert_true(str(d.get("display_name", "")).strip_edges() != "", "Display name must not be empty")
		assert_true(str(d.get("description", "")).strip_edges() != "", "Description must not be empty")
		assert_true(d.has("privileges") and d["privileges"] is Array, "Must have privileges array")
		assert_true(d.has("responsibilities") and d["responsibilities"] is Array, "Must have responsibilities array")
	print("✓ Test 1: Status definitions valid and unique PASSED")

func test_2_citizens_receive_valid_default_status() -> void:
	var c := CitizenState.new(1)
	assert_eq(c.social_status_id, SocialClassCatalog.DEFAULT_STATUS_ID, "New citizen must default to Commoner")
	assert_eq(c.social_status_id, &"commoner", "Default status ID must be 'commoner'")
	
	var c_inv := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"human", &"nonexistent_status")
	assert_eq(c_inv.social_status_id, &"commoner", "Invalid status must normalize to default commoner")
	print("✓ Test 2: Citizens receive valid default status PASSED")

func test_3_species_and_social_status_vary_independently() -> void:
	var stoneborn_artisan := CitizenState.new(10, Vector2i.ZERO, &"unassigned", &"stoneborn", &"artisan")
	var stoneborn_noble := CitizenState.new(11, Vector2i.ZERO, &"unassigned", &"stoneborn", &"noble")
	var greenwarden_scholar := CitizenState.new(12, Vector2i.ZERO, &"unassigned", &"greenwarden", &"scholar")
	var human_noble := CitizenState.new(13, Vector2i.ZERO, &"unassigned", &"human", &"noble")
	
	assert_eq(stoneborn_artisan.species_id, &"stoneborn")
	assert_eq(stoneborn_artisan.social_status_id, &"artisan")
	
	assert_eq(stoneborn_noble.species_id, &"stoneborn")
	assert_eq(stoneborn_noble.social_status_id, &"noble")
	
	assert_eq(greenwarden_scholar.species_id, &"greenwarden")
	assert_eq(greenwarden_scholar.social_status_id, &"scholar")
	
	assert_eq(human_noble.species_id, &"human")
	assert_eq(human_noble.social_status_id, &"noble")
	
	# Verify that status does not mutate species or vice versa
	assert_true(stoneborn_artisan.species_id != human_noble.species_id)
	assert_true(stoneborn_artisan.social_status_id != stoneborn_noble.social_status_id)
	print("✓ Test 3: Species and social status vary independently PASSED")

func test_4_status_eligibility_and_role_restrictions() -> void:
	var noble := CitizenState.new(20, Vector2i.ZERO, &"unassigned", &"human", &"noble")
	var commoner := CitizenState.new(21, Vector2i.ZERO, &"unassigned", &"human", &"commoner")
	
	# Nobles refuse manual resource hauling
	assert_true(noble.can_perform_role(&"builder"), "Noble can perform builder")
	assert_true(not noble.can_perform_role(&"hauler"), "Noble must refuse manual hauler role")
	assert_true(commoner.can_perform_role(&"hauler"), "Commoner can perform manual hauler role")
	
	# Town Hall staffing eligibility
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()
	
	var th := BuildingState.new(1, &"town_hall", 150)
	th.tile_origin = Vector2i(10, 10)
	th.status = BuildingState.Status.ACTIVE
	th.assigned_workers = 0
	world.buildings.append(th)
	
	var admin := CitizenState.new(22, Vector2i(10, 11), &"unassigned", &"human", &"administrator")
	commoner.position_tile = Vector2i(10, 11)
	
	world.citizens.append(commoner)
	world.citizens.append(admin)
	
	# Auto-staffing Town Hall should reject commoner and select administrator
	world.auto_staff_workplaces()
	assert_eq(admin.workplace_id, th.entity_id, "Administrator should be assigned to Town Hall")
	assert_eq(admin.role_id, &"administrator", "Administrator role assigned")
	assert_eq(commoner.workplace_id, 0, "Commoner must not be auto-staffed to Town Hall")
	
	world.free()
	print("✓ Test 4: Status eligibility and role restrictions PASSED")

func test_5_status_transitions_and_hauling_demotion() -> void:
	var treasury := Inventory.new(100, 200)
	treasury.add_resource(&"coin", 100, "INITIAL")
	
	var c := CitizenState.new(30, Vector2i.ZERO, &"hauler", &"human", &"commoner")
	c.carried_resource = &"timber"
	c.carried_amount = 5
	
	# Promoting to Noble requires 50 coin and causes immediate step-down from hauling
	var ok: bool = SocialClassService.promote_citizen(c, &"noble", "ENNOBLEMENT_DECREE", treasury, 100)
	assert_true(ok, "Promotion to noble should succeed")
	assert_eq(c.social_status_id, &"noble", "Status should update to noble")
	assert_eq(c.last_status_transition_reason, "ENNOBLEMENT_DECREE", "Transition reason recorded")
	assert_eq(treasury.get_quantity(&"coin"), 50, "50 coin deducted for nobility patent")
	
	# Since Nobles refuse hauling, citizen stepped down from hauler role
	assert_eq(c.role_id, &"unassigned", "Noble must step down from hauler role on promotion")
	assert_eq(c.carried_amount, 0, "Carried cargo cleared upon stepping down")
	print("✓ Test 5: Status transitions and hauling step-down PASSED")

func test_6_measurable_economic_and_service_modifiers() -> void:
	var eco := EconomyState.new()
	eco.tax_level = EconomyState.TaxLevel.NORMAL # base rate = 2
	var sys := EconomySystem.new()
	var treasury := Inventory.new(200, 500)
	
	var c_com := CitizenState.new(1, Vector2i.ZERO, &"unassigned", &"human", &"commoner")
	var c_art := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"human", &"artisan")
	var c_mer := CitizenState.new(3, Vector2i.ZERO, &"unassigned", &"human", &"merchant")
	var c_nob := CitizenState.new(4, Vector2i.ZERO, &"unassigned", &"human", &"noble")
	var c_cle := CitizenState.new(5, Vector2i.ZERO, &"unassigned", &"human", &"clergy")
	
	# Rate per capita checks:
	# Commoner: 2
	# Artisan: 2
	# Merchant: 2 + 2 = 4 (commerce bonus)
	# Noble: 0 (tax exempt)
	# Clergy: 0 (tax exempt)
	# Total = 2 + 2 + 4 + 0 + 0 = 8
	var citizens_group: Array = [c_com, c_art, c_mer, c_nob, c_cle]
	sys.tick_economy(eco, citizens_group.size(), 0, 0, treasury, 40, citizens_group)
	assert_eq(eco.last_tax_income, 8, "Expected 8 coins (Commoner 2 + Artisan 2 + Merchant 4 + Noble 0 + Clergy 0)")
	assert_eq(treasury.get_quantity(&"coin"), 8, "8 coins added to treasury")
	
	# Artisan craftsmanship skill factor modifier (+0.10)
	c_com.set_skill(&"crafting", 50.0)
	c_art.set_skill(&"crafting", 50.0)
	var com_fac: float = c_com.get_skill_factor(&"crafting") # 1.00
	var art_fac: float = c_art.get_skill_factor(&"crafting") # 1.10
	assert_eq(com_fac, 1.00, "Commoner crafting factor at skill 50 is 1.00")
	assert_eq(art_fac, 1.10, "Artisan crafting factor at skill 50 is 1.10 (+0.10 bonus)")
	
	# Scholar accelerated learning (+20%)
	var c_sch := CitizenState.new(6, Vector2i.ZERO, &"unassigned", &"human", &"scholar")
	c_com.set_skill(&"forestry", 0.0)
	c_sch.set_skill(&"forestry", 0.0)
	var com_gain: float = c_com.gain_experience(&"forestry", 10.0)
	var sch_gain: float = c_sch.gain_experience(&"forestry", 10.0)
	assert_true(sch_gain > com_gain, "Scholar gain (%.2f) must exceed Commoner (%.2f)" % [sch_gain, com_gain])
	assert_eq(sch_gain, com_gain * 1.20, "Scholar receives 20% experience gain bonus")
	print("✓ Test 6: Measurable economic and service modifiers PASSED")

func test_7_workforce_data_and_ui_state() -> void:
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()
	
	var c1 := world.spawn_citizen(Vector2i(1, 1), &"builder", &"stoneborn", &"artisan")
	var c2 := world.spawn_citizen(Vector2i(2, 2), &"farmer", &"greenwarden", &"scholar")
	
	assert_eq(c1.social_status_id, &"artisan")
	assert_eq(c2.social_status_id, &"scholar")
	
	var wf_list: Array[Dictionary] = world.get_workforce_citizens_data()
	assert_eq(wf_list.size(), 2)
	assert_eq(wf_list[0]["social_status_id"], &"artisan")
	assert_eq(wf_list[0]["social_status_name"], "Artisan")
	assert_eq(wf_list[1]["social_status_id"], &"scholar")
	assert_eq(wf_list[1]["social_status_name"], "Scholar")
	
	world.free()
	print("✓ Test 7: Workforce data and UI state PASSED")

func test_8_save_load_round_trip_preserves_social_status() -> void:
	var world_state := WorldState.new(10, 10)
	var economy := EconomyState.new()
	var job_board := JobBoard.new()
	var buildings: Array[BuildingState] = []
	var military_units: Array[MilitaryUnitState] = []
	
	var citizens: Array[CitizenState] = [
		CitizenState.new(1, Vector2i(2, 3), &"builder", &"human", &"artisan"),
		CitizenState.new(2, Vector2i(4, 5), &"farmer", &"greenwarden", &"clergy"),
		CitizenState.new(3, Vector2i(6, 7), &"worker", &"stoneborn", &"noble")
	]
	citizens[0].last_status_transition_reason = "EXEMPLARY_CRAFTSMANSHIP"
	citizens[2].last_status_transition_reason = "PATENT_OF_NOBILITY"
	
	var serialized: Dictionary = SaveSchema.serialize(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		10,
		1.0,
		false
	)
	
	var deserialized: Dictionary = SaveSchema.deserialize(serialized)
	var loaded_citizens: Array = deserialized["citizens"]
	assert_eq(loaded_citizens.size(), 3, "All 3 citizens deserialized")
	
	assert_eq(loaded_citizens[0].social_status_id, &"artisan", "Citizen 0 status preserved as Artisan")
	assert_eq(loaded_citizens[0].last_status_transition_reason, "EXEMPLARY_CRAFTSMANSHIP", "Transition reason preserved")
	
	assert_eq(loaded_citizens[1].social_status_id, &"clergy", "Citizen 1 status preserved as Clergy")
	assert_eq(loaded_citizens[2].social_status_id, &"noble", "Citizen 2 status preserved as Noble")
	assert_eq(loaded_citizens[2].last_status_transition_reason, "PATENT_OF_NOBILITY", "Transition reason preserved")
	print("✓ Test 8: Save/load round trip preserves social status PASSED")

func test_9_legacy_and_invalid_save_data_handling() -> void:
	var legacy_dict: Dictionary = {
		"id": 99,
		"position_tile": [5, 5],
		"role_id": "unassigned",
		"species_id": "stoneborn",
		# social_status_id is omitted (simulating v4 legacy save)
		"energy": 90.0,
		"skills": {"masonry": 60.0}
	}
	
	var save_dict: Dictionary = {
		"version": 4,
		"meta": {"seed_val": 2026},
		"world": {"width": 10, "height": 10, "tiles": []},
		"economy": {},
		"buildings": [],
		"citizens": [legacy_dict],
		"military_units": [],
		"jobs": []
	}
	
	var restored: Dictionary = SaveSchema.deserialize(save_dict)
	var loaded: Array = restored["citizens"]
	assert_eq(loaded.size(), 1)
	var c: CitizenState = loaded[0]
	assert_eq(c.species_id, &"stoneborn", "Species preserved")
	assert_eq(c.social_status_id, SocialClassCatalog.DEFAULT_STATUS_ID, "Legacy save safely defaults to Commoner")
	assert_eq(c.social_status_id, &"commoner")
	print("✓ Test 9: Legacy and invalid save data handling PASSED")

func test_10_automatic_social_advancement() -> void:
	var commoner := CitizenState.new(40, Vector2i.ZERO, &"unassigned", &"human", &"commoner")
	commoner.set_skill(&"masonry", 55.0)
	
	# Below threshold (60.0), no advancement
	var advanced: bool = SocialClassService.check_automatic_advancement(commoner, 100)
	assert_true(not advanced, "Below threshold should not advance")
	assert_eq(commoner.social_status_id, &"commoner")
	
	# Reaches 62.0 masonry -> automatic advancement to Artisan
	commoner.set_skill(&"masonry", 62.0)
	advanced = SocialClassService.check_automatic_advancement(commoner, 101)
	assert_true(advanced, "Reaching threshold should trigger advancement")
	assert_eq(commoner.social_status_id, &"artisan", "Advanced to Artisan")
	assert_eq(commoner.last_status_transition_reason, "EXEMPLARY_CRAFTSMANSHIP")
	print("✓ Test 10: Automatic social advancement PASSED")
