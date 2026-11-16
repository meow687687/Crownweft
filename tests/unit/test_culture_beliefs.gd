extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const SpeciesCatalog = preload("res://scripts/domain/species_catalog.gd")
const SocialClassCatalog = preload("res://scripts/domain/social_class_catalog.gd")
const CultureCatalog = preload("res://scripts/domain/culture_catalog.gd")
const DoctrineCatalog = preload("res://scripts/domain/doctrine_catalog.gd")
const ReligionCatalog = preload("res://scripts/domain/religion_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const NeedsSystem = preload("res://scripts/simulation/needs_system.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldScene = preload("res://scenes/world/world.gd")
const JobBoard = preload("res://scripts/simulation/job_board.gd")
const EconomyState = preload("res://scripts/domain/economy_state.gd")
const Inventory = preload("res://scripts/domain/inventory.gd")

func _init() -> void:
	print("--- Running TestCultureBeliefs ---")
	test_1_catalog_definitions_valid_and_unique()
	test_2_independent_dimensions()
	test_3_convictions_bounded()
	test_4_individual_variation_within_culture()
	test_5_work_ethic_stamina_benefit_and_exhaustion()
	test_6_dietary_conviction_and_conflicts()
	test_7_nature_conservation_workplace_conflict()
	test_8_save_load_round_trip()
	test_9_legacy_save_fallback_defaults()
	test_10_world_workforce_data_and_simulation_non_regression()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestCultureBeliefs PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_1_catalog_definitions_valid_and_unique() -> void:
	var cultures: Dictionary = CultureCatalog.get_all_defs()
	assert_true(cultures.size() >= 3, "Catalog must define at least 3 cultures")
	for c_id in CultureCatalog.CULTURE_IDS:
		assert_true(cultures.has(c_id), "Culture %s must exist in catalog" % str(c_id))
		var c_def: Dictionary = cultures[c_id]
		assert_eq(c_def.get("id"), c_id, "Culture ID must match definition key")
		assert_true(str(c_def.get("display_name", "")).strip_edges() != "", "Display name must not be empty")
		assert_true(str(c_def.get("description", "")).strip_edges() != "", "Description must not be empty")
		assert_true(c_def.has("default_convictions"), "Culture must provide default convictions")

	var doctrines: Dictionary = DoctrineCatalog.get_all_defs()
	assert_true(doctrines.size() >= 3, "Catalog must define at least 3 doctrines")
	for d_id in DoctrineCatalog.DOCTRINE_IDS:
		assert_true(doctrines.has(d_id), "Doctrine %s must exist in catalog" % str(d_id))
		var d_def: Dictionary = doctrines[d_id]
		assert_eq(d_def.get("id"), d_id, "Doctrine ID must match definition key")
		assert_true(str(d_def.get("display_name", "")).strip_edges() != "", "Doctrine display name must not be empty")

	var religions: Dictionary = ReligionCatalog.get_all_defs()
	assert_true(religions.size() >= 3, "Catalog must define at least 3 religions")
	for r_id in ReligionCatalog.RELIGION_IDS:
		assert_true(religions.has(r_id), "Religion %s must exist in catalog" % str(r_id))
		var r_def: Dictionary = religions[r_id]
		assert_eq(r_def.get("id"), r_id, "Religion ID must match definition key")
		assert_true(str(r_def.get("display_name", "")).strip_edges() != "", "Religion display name must not be empty")

	print("✓ Test 1: Culture, doctrine, and religion definitions valid and unique PASSED")

func test_2_independent_dimensions() -> void:
	var c := CitizenState.new(1, Vector2i(3, 4), &"farmer", &"stoneborn", &"artisan", &"sylvanari", &"old_grove", &"communal_labor")

	assert_eq(c.species_id, &"stoneborn", "Species must be stoneborn")
	assert_eq(c.social_status_id, &"artisan", "Status must be artisan")
	assert_eq(c.culture_id, &"sylvanari", "Culture must be sylvanari")
	assert_eq(c.religion_id, &"old_grove", "Religion must be old_grove")
	assert_eq(c.doctrine_id, &"communal_labor", "Doctrine must be communal_labor")
	assert_eq(c.role_id, &"farmer", "Role must remain farmer")

	# Check that changing one dimension does not mutate others
	c.set_social_status(&"merchant")
	assert_eq(c.species_id, &"stoneborn", "Changing status must not alter species")
	assert_eq(c.culture_id, &"sylvanari", "Changing status must not alter culture")
	assert_eq(c.religion_id, &"old_grove", "Changing status must not alter religion")

	print("✓ Test 2: Culture, doctrine, species, and social status are independent dimensions PASSED")

func test_3_convictions_bounded() -> void:
	var c := CitizenState.new(2, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"valen")
	
	c.set_conviction(&"work_ethic", -0.5)
	assert_eq(c.get_conviction(&"work_ethic"), 0.0, "Negative conviction must clamp to 0.0")

	c.set_conviction(&"work_ethic", 1.8)
	assert_eq(c.get_conviction(&"work_ethic"), 1.0, "Conviction > 1.0 must clamp to 1.0")

	c.set_conviction(&"nature_conservation", 0.65)
	assert_eq(c.get_conviction(&"nature_conservation"), 0.65, "Conviction in [0, 1] must be preserved exactly")

	print("✓ Test 3: Conviction values remain strictly bounded in [0.0, 1.0] PASSED")

func test_4_individual_variation_within_culture() -> void:
	var c1 := CitizenState.new(10, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"khorvath")
	var c2 := CitizenState.new(11, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"khorvath")

	assert_eq(c1.culture_id, c2.culture_id, "Both citizens must share Khorvath culture")

	c1.set_conviction(&"work_ethic", 0.95)
	c1.set_conviction(&"nature_conservation", 0.15)

	c2.set_conviction(&"work_ethic", 0.40)
	c2.set_conviction(&"nature_conservation", 0.85)

	assert_true(c1.get_conviction(&"work_ethic") != c2.get_conviction(&"work_ethic"), "Citizens of same culture can have distinct work ethic")
	assert_true(c1.get_conviction(&"nature_conservation") != c2.get_conviction(&"nature_conservation"), "Citizens of same culture can have distinct conservation conviction")

	print("✓ Test 4: Citizens of same culture can differ in personal convictions PASSED")

func test_5_work_ethic_stamina_benefit_and_exhaustion() -> void:
	var diligent := CitizenState.new(20, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"valen")
	var relaxed := CitizenState.new(21, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"valen")

	diligent.set_conviction(&"work_ethic", 0.9)
	relaxed.set_conviction(&"work_ethic", 0.3)

	diligent.energy = 100.0
	relaxed.energy = 100.0

	# Both perform work
	diligent.consume_energy(10.0, true)
	relaxed.consume_energy(10.0, true)

	assert_true(diligent.energy > relaxed.energy, "Diligent worker should retain more energy than relaxed worker")
	# Diligent: ethic 0.9 -> discount = 1.0 - (0.9 * 0.12) = 0.892 -> energy = 100 - (10 * 0.892) = 91.08
	# Relaxed: ethic 0.3 (< 0.7) -> discount = 1.0 -> energy = 90.0
	assert_true(is_equal_approx(relaxed.energy, 90.0), "Relaxed worker without high work ethic loses 10.0 energy")
	assert_true(is_equal_approx(diligent.energy, 91.08), "Diligent worker with 0.9 work ethic retains stamina benefit")

	# Clamping & exhaustion: high work ethic cannot bypass exhaustion
	diligent.consume_energy(200.0, true)
	assert_eq(diligent.energy, 0.0, "Energy cannot drop below 0.0")
	assert_true(diligent.is_exhausted(), "Exhaustion threshold reached even for high work ethic")

	print("✓ Test 5: Work ethic reduces work stamina drain within bounds without bypassing exhaustion PASSED")

func test_6_dietary_conviction_and_conflicts() -> void:
	var sylvan := CitizenState.new(30, Vector2i.ZERO, &"farmer", &"greenwarden", &"commoner", &"sylvanari")
	assert_true(sylvan.rejects_food(&"meat"), "Vegetarian Sylvanari must reject meat")
	assert_true(not sylvan.rejects_food(&"bread"), "Vegetarian Sylvanari must accept bread")

	var storehouse := BuildingState.new(101, &"storehouse", 100, [&"meat", &"bread"], Vector2i(3, 3))
	storehouse.status = BuildingState.Status.ACTIVE
	storehouse.inventory.add_resource(&"meat", 20, "Stockpile")

	var needs_sys := NeedsSystem.new()
	var food_invs: Array[Inventory] = [storehouse.inventory]

	# Attempt consumption with only meat available
	var ate: bool = needs_sys._try_consume_food(sylvan, food_invs, {}, null)
	assert_true(not ate, "Vegetarian must refuse to eat available meat")
	assert_eq(storehouse.inventory.get_quantity(&"meat"), 20, "No meat should be consumed")
	
	sylvan.hunger_counter = 2
	sylvan.food_state = CitizenState.FoodState.HUNGRY
	var conflict: String = sylvan.get_active_belief_conflict()
	assert_eq(conflict, "Rejects meat; available dietary alternatives are insufficient.", "Active conflict exposed when only rejected food exists")

	# Now add bread to storehouse
	storehouse.inventory.add_resource(&"bread", 10, "Stockpile")
	ate = needs_sys._try_consume_food(sylvan, food_invs, {}, null)
	assert_true(ate, "Vegetarian should consume bread when available")
	assert_eq(storehouse.inventory.get_quantity(&"bread"), 9, "One bread consumed")
	sylvan.hunger_counter = 0
	sylvan.food_state = CitizenState.FoodState.FED

	var conflict_after: String = sylvan.get_active_belief_conflict()
	assert_eq(conflict_after, "", "Belief conflict clears once acceptable food is available")

	print("✓ Test 6: Dietary restrictions prevent eating rejected food and report plain-language conflict PASSED")

func test_7_nature_conservation_workplace_conflict() -> void:
	var warden := CitizenState.new(40, Vector2i.ZERO, &"woodcutter", &"greenwarden", &"commoner", &"sylvanari")
	warden.set_conviction(&"nature_conservation", 0.85)

	var conflict: String = warden.get_active_belief_conflict()
	assert_eq(conflict, "Supports conservation; forestry assignment conflicts with personal conviction.", "Conservationist in woodcutter reports conflict")

	# Reassign role away from woodcutter
	warden.role_id = &"baker"
	var resolved_conflict: String = warden.get_active_belief_conflict()
	assert_eq(resolved_conflict, "", "Conflict clears when reassigned away from forestry")

	# Test idle diligent worker
	var diligent_idle := CitizenState.new(41, Vector2i.ZERO, &"unassigned", &"human", &"commoner", &"valen")
	diligent_idle.set_conviction(&"work_ethic", 0.85)
	var idle_conflict: String = diligent_idle.get_active_belief_conflict()
	assert_eq(idle_conflict, "Values diligent labor; currently idle and unassigned.", "High work ethic unassigned worker reports idle conflict")

	print("✓ Test 7: Conservation conviction produces conflict when assigned to forestry PASSED")

func test_8_save_load_round_trip() -> void:
	var world_state := WorldState.new(10, 10)
	var economy := EconomyState.new()
	var job_board := JobBoard.new()
	var buildings: Array[BuildingState] = []
	var military_units: Array[MilitaryUnitState] = []
	var citizens: Array[CitizenState] = [
		CitizenState.new(1, Vector2i(1, 1), &"builder", &"human", &"commoner", &"valen", &"pantheon", &"communal_labor"),
		CitizenState.new(2, Vector2i(2, 2), &"farmer", &"greenwarden", &"artisan", &"sylvanari", &"old_grove", &"sylvan_harmony"),
		CitizenState.new(3, Vector2i(3, 3), &"miner", &"stoneborn", &"noble", &"khorvath", &"secular", &"martial_tradition")
	]

	citizens[0].set_conviction(&"work_ethic", 0.88)
	citizens[1].set_conviction(&"nature_conservation", 0.92)
	citizens[2].set_conviction(&"piety", 0.15)

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

	assert_eq(loaded_citizens[0].culture_id, &"valen", "Citizen 0 culture preserved")
	assert_eq(loaded_citizens[0].religion_id, &"pantheon", "Citizen 0 religion preserved")
	assert_eq(loaded_citizens[0].doctrine_id, &"communal_labor", "Citizen 0 doctrine preserved")
	assert_true(is_equal_approx(loaded_citizens[0].get_conviction(&"work_ethic"), 0.88), "Citizen 0 work_ethic conviction preserved")

	assert_eq(loaded_citizens[1].culture_id, &"sylvanari", "Citizen 1 culture preserved")
	assert_eq(loaded_citizens[1].religion_id, &"old_grove", "Citizen 1 religion preserved")
	assert_eq(loaded_citizens[1].doctrine_id, &"sylvan_harmony", "Citizen 1 doctrine preserved")
	assert_true(is_equal_approx(loaded_citizens[1].get_conviction(&"nature_conservation"), 0.92), "Citizen 1 nature_conservation preserved")

	assert_eq(loaded_citizens[2].culture_id, &"khorvath", "Citizen 2 culture preserved")
	assert_eq(loaded_citizens[2].religion_id, &"secular", "Citizen 2 religion preserved")
	assert_eq(loaded_citizens[2].doctrine_id, &"martial_tradition", "Citizen 2 doctrine preserved")
	assert_true(is_equal_approx(loaded_citizens[2].get_conviction(&"piety"), 0.15), "Citizen 2 piety preserved")

	print("✓ Test 8: Save/load round-trip preserves culture, religion, doctrine, and convictions PASSED")

func test_9_legacy_save_fallback_defaults() -> void:
	var legacy_citizen_dict: Dictionary = {
		"id": 99,
		"position_tile": Vector2i(2, 2),
		"role_id": "builder",
		"species_id": "human",
		"social_status_id": "commoner",
		"energy": 80.0,
		"skills": {"farming": 50.0, "forestry": 50.0, "masonry": 50.0, "crafting": 50.0, "hauling": 50.0}
		# Note: culture_id, religion_id, doctrine_id, convictions are completely omitted
	}

	var legacy_save: Dictionary = {
		"version": 1,
		"world": {"width": 10, "height": 10, "tiles": []},
		"economy": {"treasury": 100, "tax_level": 1, "approval": 60.0},
		"buildings": [],
		"citizens": [legacy_citizen_dict],
		"military_units": [],
		"job_board": {"jobs": []},
		"time_elapsed": 10.0,
		"current_tick": 5,
		"auto_staffing": false
	}

	var deserialized: Dictionary = SaveSchema.deserialize(legacy_save)
	var loaded_citizens: Array = deserialized["citizens"]
	assert_eq(loaded_citizens.size(), 1, "Legacy citizen loaded")

	var c: CitizenState = loaded_citizens[0]
	assert_eq(c.culture_id, &"valen", "Legacy save defaults to valen culture")
	assert_eq(c.religion_id, &"pantheon", "Legacy save defaults to pantheon religion")
	assert_eq(c.doctrine_id, &"communal_labor", "Legacy save defaults to communal_labor doctrine")
	assert_true(c.convictions.size() >= 4, "Legacy save populates default starting convictions")
	assert_true(c.get_conviction(&"work_ethic") > 0.0, "Legacy save has valid work_ethic conviction")

	print("✓ Test 9: Legacy saves safely default to Valen / Pantheon / Communal Labor PASSED")

func test_10_world_workforce_data_and_simulation_non_regression() -> void:
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()

	var c1: CitizenState = world.spawn_citizen(Vector2i(2, 2), &"farmer", &"human", &"commoner", &"valen", &"pantheon", &"communal_labor")
	var c2: CitizenState = world.spawn_citizen(Vector2i(3, 3), &"builder", &"greenwarden", &"artisan", &"sylvanari", &"old_grove", &"sylvan_harmony")

	assert_eq(c1.culture_id, &"valen", "Spawned citizen 1 culture is valen")
	assert_eq(c2.culture_id, &"sylvanari", "Spawned citizen 2 culture is sylvanari")

	var wf_data: Array[Dictionary] = world.get_workforce_citizens_data()
	assert_eq(wf_data.size(), 2, "Workforce data has 2 citizens")
	assert_eq(wf_data[0]["culture_id"], &"valen", "Workforce citizen 0 culture_id is valen")
	assert_eq(wf_data[0]["culture_name"], "Valen", "Workforce citizen 0 culture_name is Valen")
	assert_eq(wf_data[1]["culture_id"], &"sylvanari", "Workforce citizen 1 culture_id is sylvanari")
	assert_eq(wf_data[1]["culture_name"], "Sylvanari", "Workforce citizen 1 culture_name is Sylvanari")

	world.free()
	print("✓ Test 10: World workforce data and non-regression PASSED")
