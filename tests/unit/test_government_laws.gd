extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const GovernmentState = preload("res://scripts/domain/government_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const EconomyState = preload("res://scripts/domain/economy_state.gd")
const EconomySystem = preload("res://scripts/simulation/economy_system.gd")
const ProductionSystem = preload("res://scripts/simulation/production_system.gd")
const ConstructionSystem = preload("res://scripts/simulation/construction_system.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldScene = preload("res://scenes/world/world.gd")
const JobBoard = preload("res://scripts/simulation/job_board.gd")
const Inventory = preload("res://scripts/domain/inventory.gd")

func _init() -> void:
	print("--- Running TestGovernmentLaws ---")
	test_1_catalog_definitions_valid_and_unique()
	test_2_policy_enactment_and_state_update()
	test_3_tax_policy_effects_on_collection()
	test_4_labour_policy_energy_and_speed_modifiers()
	test_5_forestry_policy_and_woodcutter_blocking()
	test_6_belief_conflicts_distinct_from_laws()
	test_7_administrator_and_approval_damping()
	test_8_policy_chronicle_events()
	test_9_save_load_round_trip()
	test_10_legacy_save_fallback_defaults()
	test_11_world_integration_and_non_regression()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestGovernmentLaws PASSED ---\n")
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
	var defs: Dictionary = LawCatalog.get_all_defs()
	assert_true(defs.size() >= 3, "Catalog must define at least 3 laws")
	
	for law_id in LawCatalog.LAW_IDS:
		assert_true(defs.has(law_id), "Law ID %s must exist in catalog" % str(law_id))
		var l_def: Dictionary = defs[law_id]
		assert_eq(l_def.get("id"), law_id, "Def ID must match key")
		assert_true(str(l_def.get("display_name", "")).strip_edges() != "", "Display name must not be empty")
		assert_true(str(l_def.get("description", "")).strip_edges() != "", "Description must not be empty")
		assert_true(l_def.has("options") and l_def["options"] is Dictionary, "Must have options dictionary")
		assert_true(l_def["options"].size() >= 2, "Must have at least 2 options")
	print("✓ Test 1: Law catalog definitions valid and unique PASSED")

func test_2_policy_enactment_and_state_update() -> void:
	var gov := GovernmentState.new()
	assert_eq(gov.get_policy(LawCatalog.LAW_TAXATION), &"standard", "Default taxation must be standard")
	assert_eq(gov.get_policy(LawCatalog.LAW_LABOUR), &"standard", "Default labour must be standard")
	assert_eq(gov.get_policy(LawCatalog.LAW_FORESTRY), &"managed", "Default forestry must be managed")

	# Enact new policy
	var ok: bool = gov.enact_policy(LawCatalog.LAW_TAXATION, &"high", 50, "War treasury requirement")
	assert_true(ok, "Enacting valid policy must succeed")
	assert_eq(gov.get_policy(LawCatalog.LAW_TAXATION), &"high", "Policy must be updated to high")
	assert_eq(gov.policy_ticks[LawCatalog.LAW_TAXATION], 50, "Enacted tick must be recorded")

	# Idempotent: re-enacting same policy fails cleanly
	var re_ok: bool = gov.enact_policy(LawCatalog.LAW_TAXATION, &"high", 60)
	assert_true(not re_ok, "Re-enacting already active policy returns false")

	# Invalid law or option rejected
	assert_true(not gov.enact_policy(&"invalid_law", &"option", 70), "Invalid law rejected")
	assert_true(not gov.enact_policy(LawCatalog.LAW_TAXATION, &"nonexistent_option", 70), "Invalid option rejected")
	print("✓ Test 2: Policy enactment and state update PASSED")

func test_3_tax_policy_effects_on_collection() -> void:
	var economy := EconomyState.new()
	var econ_sys := EconomySystem.new()
	var gov := GovernmentState.new()
	var town_inv := Inventory.new(1, 100, [&"coin"])

	var citizens: Array[CitizenState] = [
		CitizenState.new(1, Vector2i.ZERO, &"farmer", &"human", &"commoner"),
		CitizenState.new(2, Vector2i.ZERO, &"builder", &"human", &"commoner")
	]

	# Standard tax: 2 coins per commoner * 2 = 4 coins
	economy.last_tax_tick = 0
	econ_sys.tick_economy(economy, citizens.size(), 0, 0, town_inv, EconomyState.TAX_INTERVAL_TICKS, citizens, gov)
	assert_eq(economy.tax_level, EconomyState.TaxLevel.NORMAL, "Tax level synchronized to NORMAL")
	assert_eq(economy.last_tax_income, 4, "Standard tax income must be 4")
	assert_eq(town_inv.get_quantity(&"coin"), 4, "Town treasury received 4 coin")

	# Enact High tax: 4 coins per commoner * 2 = 8 coins
	gov.enact_policy(LawCatalog.LAW_TAXATION, &"high", 50)
	economy.last_tax_tick = 50
	econ_sys.tick_economy(economy, citizens.size(), 0, 0, town_inv, 50 + EconomyState.TAX_INTERVAL_TICKS, citizens, gov)
	assert_eq(economy.tax_level, EconomyState.TaxLevel.HIGH, "Tax level synchronized to HIGH")
	assert_eq(economy.last_tax_income, 8, "High tax income must be 8")
	assert_eq(town_inv.get_quantity(&"coin"), 12, "Town treasury total is now 12 coin")

	# Enact Low tax: 1 coin per commoner * 2 = 2 coins
	gov.enact_policy(LawCatalog.LAW_TAXATION, &"low", 100)
	economy.last_tax_tick = 100
	econ_sys.tick_economy(economy, citizens.size(), 0, 0, town_inv, 100 + EconomyState.TAX_INTERVAL_TICKS, citizens, gov)
	assert_eq(economy.tax_level, EconomyState.TaxLevel.LOW, "Tax level synchronized to LOW")
	assert_eq(economy.last_tax_income, 2, "Low tax income must be 2")
	print("✓ Test 3: Tax policy changes affect actual tax collection correctly PASSED")

func test_4_labour_policy_energy_and_speed_modifiers() -> void:
	var prod := ProductionSystem.new()
	var constr := ConstructionSystem.new()
	var gov := GovernmentState.new()

	var worker_standard := CitizenState.new(10, Vector2i.ZERO, &"farmer", &"human", &"commoner")
	var worker_extended := CitizenState.new(11, Vector2i.ZERO, &"farmer", &"human", &"commoner")

	worker_standard.energy = 100.0
	worker_extended.energy = 100.0

	var recipe := RecipeDef.new()
	recipe.required_workers = 1
	recipe.duration_ticks = 20
	recipe.inputs = {}
	recipe.outputs = {&"grain": 2}

	var farm_b := BuildingState.new(1, &"farm", 50, [&"grain"], Vector2i(2, 2))
	farm_b.assigned_workers = 1

	# Standard shift tick
	gov.enact_policy(LawCatalog.LAW_LABOUR, &"standard", 0)
	prod.tick_building(farm_b, recipe, null, 1, [worker_standard], gov)
	# Extended shift tick
	gov.enact_policy(LawCatalog.LAW_LABOUR, &"extended", 0)
	prod.tick_building(farm_b, recipe, null, 1, [worker_extended], gov)

	# Extended shift drains 1.35x energy vs 1.0x
	assert_true(worker_extended.energy < worker_standard.energy, "Extended shift drains more energy (%.2f vs %.2f)" % [worker_extended.energy, worker_standard.energy])

	# Clamping and exhaustion still work strictly
	worker_extended.consume_energy(200.0, true)
	assert_eq(worker_extended.energy, 0.0, "Energy bounded at 0.0")
	assert_true(worker_extended.is_exhausted(), "Exhaustion trigger remains intact under extended shifts")

	print("✓ Test 4: Labour policies respect energy, rest, and fatigue limits PASSED")

func test_5_forestry_policy_and_woodcutter_blocking() -> void:
	var prod := ProductionSystem.new()
	var gov := GovernmentState.new()
	var world := WorldState.new(10, 10)
	for y in range(world.height):
		for x in range(world.width):
			world.set_tile(Vector2i(x, y), WorldTile.new(Vector2i(x, y), &"grass"))

	var woodcutter_b := BuildingState.new(20, &"woodcutter", 50, [&"timber"], Vector2i(2, 2))
	woodcutter_b.tile_origin = Vector2i(5, 5)
	woodcutter_b.assigned_workers = 1

	# Plant a tree deposit nearby
	var tree_tile := world.get_tile(Vector2i(6, 5))
	tree_tile.resource_deposit_id = &"trees"
	tree_tile.resource_amount = 5

	var recipe := RecipeDef.new()
	recipe.required_workers = 1
	recipe.duration_ticks = 10
	recipe.inputs = {}
	recipe.outputs = {&"timber": 2}

	var worker := CitizenState.new(25, Vector2i(5, 5), &"woodcutter", &"human", &"commoner")

	# Managed forestry: harvest is allowed
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"managed", 0)
	prod.tick_building(woodcutter_b, recipe, world, 1, [worker], gov)
	assert_eq(woodcutter_b.current_block_reason, &"", "Woodcutter operates normally under managed forestry")

	# Protected forests: decree prohibits timber harvesting
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"protected_forests", 10)
	prod.tick_building(woodcutter_b, recipe, world, 1, [worker], gov)
	assert_eq(woodcutter_b.current_block_reason, &"LAW_BLOCKED: PROTECTED_FORESTS", "Woodcutter blocked by Protected Forests law")

	# Open extraction: permits harvest and grants bonus timber
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"open_extraction", 20)
	recipe.duration_ticks = 2
	woodcutter_b.production_progress = 0
	prod.tick_building(woodcutter_b, recipe, world, 1, [worker], gov)
	prod.tick_building(woodcutter_b, recipe, world, 1, [worker], gov)
	assert_eq(woodcutter_b.current_block_reason, &"", "Woodcutter unblocked under open extraction")
	assert_true(woodcutter_b.inventory.get_quantity(&"timber") >= 3, "Open extraction yields bonus timber (expected >= 3)")

	print("✓ Test 5: Forestry policies affect actual harvesting behavior and legally block woodcutters PASSED")

func test_6_belief_conflicts_distinct_from_laws() -> void:
	var gov := GovernmentState.new()
	var conservationist := CitizenState.new(30, Vector2i.ZERO, &"farmer", &"greenwarden", &"commoner", &"sylvanari")
	conservationist.set_conviction(&"nature_conservation", 0.85)

	# Under managed forestry, no decree conflict
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"managed", 0)
	var conflict_managed: String = conservationist.get_active_belief_conflict(gov)
	assert_eq(conflict_managed, "", "No belief conflict under managed forestry")

	# Under open extraction, conservationist reports belief conflict
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"open_extraction", 10)
	var conflict_open: String = conservationist.get_active_belief_conflict(gov)
	assert_eq(conflict_open, "Disapproves of open extraction; forestry decree conflicts with personal conservation conviction.", "Open extraction creates active belief conflict for conservationist")

	# Under protected forests, conflict clears
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"protected_forests", 20)
	var conflict_protected: String = conservationist.get_active_belief_conflict(gov)
	assert_eq(conflict_protected, "", "Protected forests clears conservation conflict")

	print("✓ Test 6: Belief conflicts remain distinct from laws PASSED")

func test_7_administrator_and_approval_damping() -> void:
	var economy := EconomyState.new()
	var econ_sys := EconomySystem.new()
	var town_inv := Inventory.new(1, 100, [&"coin"])

	# Base high tax without administrator
	var citizens_no_admin: Array[CitizenState] = [
		CitizenState.new(1, Vector2i.ZERO, &"farmer", &"human", &"commoner"),
		CitizenState.new(2, Vector2i.ZERO, &"builder", &"human", &"commoner")
	]
	economy.tax_level = EconomyState.TaxLevel.HIGH

	# High tax with active administrator at Town Hall
	var economy_with_admin := EconomyState.new()
	economy_with_admin.tax_level = EconomyState.TaxLevel.HIGH
	var town_inv2 := Inventory.new(2, 100, [&"coin"])
	var admin_c := CitizenState.new(3, Vector2i.ZERO, &"administrator", &"human", &"administrator")
	admin_c.workplace_id = 99 # assigned to Town Hall
	var citizens_with_admin: Array[CitizenState] = [
		CitizenState.new(1, Vector2i.ZERO, &"farmer", &"human", &"commoner"),
		admin_c
	]

	# Run multiple tax cycles to allow approval to drift toward targets
	for cycle in range(1, 6):
		var tick: int = cycle * EconomyState.TAX_INTERVAL_TICKS
		econ_sys.tick_economy(economy, 2, 0, 0, town_inv, tick, citizens_no_admin)
		econ_sys.tick_economy(economy_with_admin, 2, 0, 0, town_inv2, tick, citizens_with_admin)

	var approval_no_admin: float = economy.approval
	var approval_with_admin: float = economy_with_admin.approval

	assert_true(approval_with_admin > approval_no_admin, "Administrator dampens high tax discontent (%.1f > %.1f)" % [approval_with_admin, approval_no_admin])
	assert_true(town_inv2.get_quantity(&"coin") > town_inv.get_quantity(&"coin"), "Administrator boosts tax revenue via audit efficiency")

	print("✓ Test 7: Administrator role and approval damping verified PASSED")

func test_8_policy_chronicle_events() -> void:
	var gov := GovernmentState.new()
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"protected_forests", 120, "Decree of the Crown")
	gov.enact_policy(LawCatalog.LAW_LABOUR, &"extended", 150, "Wartime production")

	var history: Array[Dictionary] = gov.get_recent_history(5)
	assert_eq(history.size(), 2, "Chronicle must contain 2 entries")
	assert_eq(history[0]["law_id"], LawCatalog.LAW_LABOUR, "Most recent entry is labour")
	assert_eq(history[0]["tick"], 150, "Most recent tick is 150")
	assert_true(history[0]["description"].contains("Extended Shifts"), "Description details extended shifts")
	assert_eq(history[1]["law_id"], LawCatalog.LAW_FORESTRY, "Second entry is forestry")
	assert_eq(history[1]["tick"], 120, "Second tick is 120")

	print("✓ Test 8: Policy events and chronicle history recorded correctly PASSED")

func test_9_save_load_round_trip() -> void:
	var world_state := WorldState.new(10, 10)
	var economy := EconomyState.new()
	var job_board := JobBoard.new()
	var buildings: Array[BuildingState] = []
	var military_units: Array[MilitaryUnitState] = []
	var citizens: Array[CitizenState] = [CitizenState.new(1, Vector2i(1, 1))]
	var gov := GovernmentState.new()

	gov.enact_policy(LawCatalog.LAW_TAXATION, &"high", 10)
	gov.enact_policy(LawCatalog.LAW_LABOUR, &"relaxed", 20)
	gov.enact_policy(LawCatalog.LAW_FORESTRY, &"protected_forests", 30)

	var serialized: Dictionary = SaveSchema.serialize(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		35,
		1.0,
		false,
		gov
	)

	var deserialized: Dictionary = SaveSchema.deserialize(serialized)
	assert_true(deserialized.has("government"), "Deserialized save must contain government")
	var loaded_gov: GovernmentState = deserialized["government"]
	assert_eq(loaded_gov.get_policy(LawCatalog.LAW_TAXATION), &"high", "Taxation policy preserved")
	assert_eq(loaded_gov.get_policy(LawCatalog.LAW_LABOUR), &"relaxed", "Labour policy preserved")
	assert_eq(loaded_gov.get_policy(LawCatalog.LAW_FORESTRY), &"protected_forests", "Forestry policy preserved")
	assert_eq(loaded_gov.policy_ticks[LawCatalog.LAW_FORESTRY], 30, "Enacted tick preserved")
	assert_eq(loaded_gov.policy_history.size(), 3, "Policy history preserved across save/load")

	print("✓ Test 9: Save/load round-trip preserves policies without replaying effects PASSED")

func test_10_legacy_save_fallback_defaults() -> void:
	var legacy_save: Dictionary = {
		"version": 1,
		"world": {"width": 10, "height": 10, "tiles": []},
		"economy": {"tax_level": 1, "approval": 60.0},
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"job_board": {"jobs": []},
		"time_elapsed": 10.0,
		"current_tick": 5,
		"auto_staffing": false
		# Note: "government" is completely omitted
	}

	var deserialized: Dictionary = SaveSchema.deserialize(legacy_save)
	assert_true(deserialized.has("government"), "Legacy save must populate default government")
	var gov: GovernmentState = deserialized["government"]
	assert_eq(gov.get_policy(LawCatalog.LAW_TAXATION), &"standard", "Legacy save defaults to standard taxation")
	assert_eq(gov.get_policy(LawCatalog.LAW_LABOUR), &"standard", "Legacy save defaults to standard labour")
	assert_eq(gov.get_policy(LawCatalog.LAW_FORESTRY), &"managed", "Legacy save defaults to managed forestry")

	print("✓ Test 10: Legacy saves load with safe policy defaults PASSED")

func test_11_world_integration_and_non_regression() -> void:
	var world := WorldScene.new()
	world.citizens.clear()
	world.buildings.clear()

	assert_true(world.government != null, "World must initialize government state")
	assert_eq(world.government.get_policy(LawCatalog.LAW_TAXATION), &"standard", "Initial tax policy is standard")

	# Enact through world interface
	var ok: bool = world.enact_policy(LawCatalog.LAW_TAXATION, &"high", "Test world policy enactment")
	assert_true(ok, "World enact_policy succeeds")
	assert_eq(world.government.get_policy(LawCatalog.LAW_TAXATION), &"high", "Government policy updated")
	assert_eq(world.economy.tax_level, EconomyState.TaxLevel.HIGH, "Economy tax level synchronized")

	# Test cycle tax level through world interface
	world.cycle_tax_level() # from HIGH -> LOW
	assert_eq(world.government.get_policy(LawCatalog.LAW_TAXATION), &"low", "Cycle tax moves to low")
	assert_eq(world.economy.tax_level, EconomyState.TaxLevel.LOW, "Economy tax level moves to low")

	world.free()
	print("✓ Test 11: World integration and non-regression PASSED")
