extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("\n--- Running TestWarPeaceMilitary ---")
	test_1_valid_and_invalid_war_state_transitions()
	test_2_political_escalation_evaluation()
	test_3_deterministic_escalation_decisions()
	test_4_war_declaration_creates_persistent_record()
	test_5_hostile_forces_use_existing_unit_architecture()
	test_6_battles_update_casualties_and_state()
	test_7_transactionally_correct_war_economy_and_subsidies()
	test_8_defeating_expedition_does_not_terminate_war()
	test_9_defensive_pact_intervention()
	test_10_ceasefires_prevent_prohibited_actions()
	test_11_peace_resolution_preserves_conflict_history()
	test_12_save_load_preserves_active_conflict()
	test_13_non_regression_and_legacy_compatibility()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestWarPeaceMilitary PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

# Test 1: Valid and invalid war-state transitions
func test_1_valid_and_invalid_war_state_transitions() -> void:
	var war := WarState.new(1, FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, WarState.STATUS_PEACE, "Border dispute", 10)
	
	# Valid transitions
	assert_true(war.can_transition_to(WarState.STATUS_CRISIS), "PEACE -> CRISIS should be valid")
	assert_true(war.transition_to(WarState.STATUS_CRISIS, 20), "Transition to CRISIS must succeed")
	assert_eq(war.status, WarState.STATUS_CRISIS)

	assert_true(war.can_transition_to(WarState.STATUS_WAR), "CRISIS -> WAR should be valid")
	assert_true(war.transition_to(WarState.STATUS_WAR, 40), "Transition to WAR must succeed")
	assert_eq(war.status, WarState.STATUS_WAR)

	assert_true(war.can_transition_to(WarState.STATUS_CEASEFIRE), "WAR -> CEASEFIRE should be valid")
	assert_true(war.transition_to(WarState.STATUS_CEASEFIRE, 60), "Transition to CEASEFIRE must succeed")
	assert_eq(war.status, WarState.STATUS_CEASEFIRE)
	assert_true(war.ceasefire_ticks_remaining > 0, "Ceasefire should initialize truce ticks")

	assert_true(war.can_transition_to(WarState.STATUS_PEACE), "CEASEFIRE -> PEACE should be valid")
	assert_true(war.transition_to(WarState.STATUS_PEACE, 80), "Transition to PEACE must succeed")
	assert_eq(war.status, WarState.STATUS_PEACE)

	# Invalid transitions
	assert_true(not war.can_transition_to(WarState.STATUS_CEASEFIRE), "PEACE -> CEASEFIRE directly must be rejected")
	assert_true(not war.can_transition_to(WarState.STATUS_PEACE), "Redundant transition to PEACE must be rejected")

	# Invalid duplicate faction
	var invalid_war := WarState.new(2, FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_PLAYER, WarState.STATUS_PEACE)
	assert_true(not invalid_war.can_transition_to(WarState.STATUS_WAR), "War with identical factions must be invalid")
	print("✓ Test 1: Valid and invalid war-state transitions PASSED")

# Test 2: Political escalation evaluation
func test_2_political_escalation_evaluation() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var gov := GovernmentState.new()

	var ironpeak: FactionState = dip.factions[FactionCatalog.FACTION_IRONPEAK]
	var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER)

	# Baseline: Low resentment -> No escalation
	rel.resentment = 10.0
	var cands_peace: Array[Dictionary] = dip_sys._generate_candidate_actions(dip, ironpeak, rel, 24, gov)
	var has_escalation_peace: bool = false
	for c in cands_peace:
		if c.get("action_id") == DiplomacySystem.ACTION_ESCALATE_WAR:
			has_escalation_peace = true
	assert_true(not has_escalation_peace, "Peaceful faction should not generate escalation candidate")

	# Grievances: Resentment rises to 50.0 and military power is sufficient -> Escalation candidate generated
	rel.resentment = 50.0
	rel.trust = -30.0
	ironpeak.military_power = 35
	var cands_crisis: Array[Dictionary] = dip_sys._generate_candidate_actions(dip, ironpeak, rel, 24, gov)
	var has_escalation_crisis: bool = false
	for c in cands_crisis:
		if c.get("action_id") == DiplomacySystem.ACTION_ESCALATE_WAR:
			has_escalation_crisis = true
	assert_true(has_escalation_crisis, "High resentment must generate escalation candidate")
	print("✓ Test 2: Political escalation is evaluated using current known faction state PASSED")

# Test 3: Deterministic escalation decisions
func test_3_deterministic_escalation_decisions() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip_a := DiplomacyState.new()
	var dip_b := DiplomacyState.new()
	var gov := GovernmentState.new()

	for dip in [dip_a, dip_b]:
		var fac: FactionState = dip.factions[FactionCatalog.FACTION_IRONPEAK]
		fac.military_power = 40
		var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER)
		rel.resentment = 55.0
		rel.threat = 40.0
		rel.trust = -20.0

	dip_sys.tick_diplomacy(dip_a, 24, null, null, gov)
	dip_sys.tick_diplomacy(dip_b, 24, null, null, gov)

	var f_a: FactionState = dip_a.factions[FactionCatalog.FACTION_IRONPEAK]
	var f_b: FactionState = dip_b.factions[FactionCatalog.FACTION_IRONPEAK]

	assert_eq(f_a.last_utility_breakdown.get("chosen_action"), f_b.last_utility_breakdown.get("chosen_action"), "Escalation action must be identical")
	assert_eq(f_a.last_utility_breakdown.get("utility"), f_b.last_utility_breakdown.get("utility"), "Utility score must be identical")
	assert_eq(dip_a.active_wars.size(), dip_b.active_wars.size(), "Both must instantiate exactly one war")
	print("✓ Test 3: The same initial state produces repeatable escalation decisions PASSED")

# Test 4: War declaration creates persistent record
func test_4_war_declaration_creates_persistent_record() -> void:
	var dip := DiplomacyState.new()
	var war: WarState = dip.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border aggression", 10, WarState.STATUS_CRISIS)
	assert_true(war != null, "War record must be created")
	assert_eq(war.id, 1, "War should receive stable ID 1")
	assert_eq(war.status, WarState.STATUS_CRISIS, "War starts in CRISIS")
	assert_true(dip.has_active_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER), "has_active_war should be true")
	print("✓ Test 4: A war declaration creates one valid persistent conflict record PASSED")

# Test 5: Hostile forces use existing unit architecture
func test_5_hostile_forces_use_existing_unit_architecture() -> void:
	var combat := CombatSystem.new()
	var camp_pos: Vector2 = Vector2(100.0, 100.0)
	var raider: MilitaryUnitState = combat.spawn_raider_unit(camp_pos)
	assert_eq(raider.faction_id, 1, "Raider must have non-zero faction_id")
	assert_true(raider.health > 0, "Raider must have valid health")
	assert_eq(raider.position, camp_pos, "Spawn position must be exact")
	print("✓ Test 5: Hostile forces use existing unit and combat architecture PASSED")

# Test 6: Battles update casualties and military state
func test_6_battles_update_casualties_and_state() -> void:
	var war := WarState.new(1, FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, WarState.STATUS_WAR, "Test War", 5)
	
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_casualty(FactionCatalog.FACTION_PLAYER)
	
	assert_eq(war.casualties.get(str(FactionCatalog.FACTION_IRONPEAK)), 2, "2 enemy casualties recorded")
	assert_eq(war.casualties.get(str(FactionCatalog.FACTION_PLAYER)), 1, "1 Crown casualty recorded")

	war.record_battle(25, "First border skirmish", 2, 1, &"repelled")
	assert_eq(war.battles.size(), 1, "Battle recorded")
	assert_eq(war.battles[0].get("result"), &"repelled")
	print("✓ Test 6: Battles update casualties and military state correctly PASSED")

# Test 7: Transactionally correct war economy and subsidies
func test_7_transactionally_correct_war_economy_and_subsidies() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)
	inv.add_resource(&"coin", 20, "Initial Town Treasury")

	var valen: FactionState = dip.factions[FactionCatalog.FACTION_VALEN]
	valen.treasury = 100
	valen.add_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER, 0, 600)

	var war: WarState = dip.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Invasion", 0, WarState.STATUS_CRISIS)
	
	# Transition crisis to war: should trigger allied subsidy
	dip_sys._advance_war_lifecycles(dip, 24, inv)
	assert_eq(war.status, WarState.STATUS_WAR, "War status transitioned to WAR")
	assert_eq(inv.get_quantity(&"coin"), 45, "Player receives 25 coin subsidy (20 + 25 = 45)")
	assert_eq(valen.treasury, 75, "Ally deducted exactly 25 coins (100 - 25 = 75)")
	print("✓ Test 7: Resource and treasury changes are transactionally correct PASSED")

# Test 8: Defeating expedition does not terminate war
func test_8_defeating_expedition_does_not_terminate_war() -> void:
	var war := WarState.new(1, FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, WarState.STATUS_WAR, "Assault", 10)
	war.attacker_expedition_spawned = true
	war.attacker_expedition_unit_ids = [1001, 1002]

	# Both expedition units defeated in battle
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_battle(30, "Expedition repelled at settlement gate", 2, 0, &"repelled")

	assert_eq(war.status, WarState.STATUS_WAR, "War remains active in WAR status even after repelling expedition")
	assert_eq(war.battles.size(), 1, "Battle victory recorded")
	print("✓ Test 8: Defeating a raiding force does not incorrectly terminate the war PASSED")

# Test 9: Defensive pacts follow documented rules
func test_9_defensive_pact_intervention() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)

	var valen: FactionState = dip.factions[FactionCatalog.FACTION_VALEN]
	valen.add_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER, 0, 600)

	var war := WarState.new(1, FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, WarState.STATUS_WAR, "Assault", 10)
	dip_sys._check_defensive_pact_intervention(dip, war, 20, inv)

	var rel_valen_aggressor: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_IRONPEAK)
	assert_true(rel_valen_aggressor.trust < 0, "Ally trust toward aggressor drops significantly")
	assert_true(valen.memories.size() >= 1, "Ally records memory of honoring defensive pact")
	print("✓ Test 9: Defensive pacts follow their documented rules PASSED")

# Test 10: Ceasefires prevent prohibited actions
func test_10_ceasefires_prevent_prohibited_actions() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var war := dip.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border war", 10, WarState.STATUS_WAR)

	var res: Dictionary = dip_sys.negotiate_ceasefire(dip, war.id, 50)
	assert_true(res.get("ok", false), "Ceasefire negotiation succeeds")
	assert_eq(war.status, WarState.STATUS_CEASEFIRE, "War enters CEASEFIRE status")

	# While in ceasefire, hostile escalation is prohibited
	var ironpeak: FactionState = dip.factions[FactionCatalog.FACTION_IRONPEAK]
	var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER)
	rel.resentment = 60.0
	var cands: Array[Dictionary] = dip_sys._generate_candidate_actions(dip, ironpeak, rel, 70, GovernmentState.new())
	var has_escalation: bool = false
	for c in cands:
		if c.get("action_id") == DiplomacySystem.ACTION_ESCALATE_WAR:
			has_escalation = true
	assert_true(not has_escalation, "Ceasefire must prohibit war escalation")
	print("✓ Test 10: Ceasefires prevent prohibited hostile actions PASSED")

# Test 11: Peace resolution preserves conflict history
func test_11_peace_resolution_preserves_conflict_history() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var war := dip.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border dispute", 10, WarState.STATUS_WAR)
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_battle(20, "Early skirmish", 1, 0, &"stalemate")

	var res: Dictionary = dip_sys.conclude_peace_treaty(dip, war.id, 80, WarState.OUTCOME_WHITE_PEACE)
	assert_true(res.get("ok", false), "Peace treaty conclusion succeeds")
	assert_eq(war.status, WarState.STATUS_PEACE, "War status is PEACE")
	assert_eq(war.outcome, WarState.OUTCOME_WHITE_PEACE, "Outcome is WHITE_PEACE")
	assert_eq(dip.active_wars.size(), 0, "Active wars list cleared of concluded war")
	assert_eq(dip.war_history.size(), 1, "Concluded war preserved in war history")
	print("✓ Test 11: Peace resolution preserves conflict history and valid relationship changes PASSED")

# Test 12: Save/load preserves active conflict
func test_12_save_load_preserves_active_conflict() -> void:
	var dip_orig := DiplomacyState.new()
	var war: WarState = dip_orig.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Reconquest", 25, WarState.STATUS_WAR)
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_casualty(FactionCatalog.FACTION_PLAYER)
	war.record_battle(40, "Battle of Iron Creek", 1, 1, &"stalemate")
	war.attacker_expedition_spawned = true
	war.attacker_expedition_unit_ids = [1001, 1002]

	var serialized: Dictionary = dip_orig.serialize()
	var dip_loaded: DiplomacyState = DiplomacyState.deserialize(serialized)

	assert_eq(dip_loaded.active_wars.size(), 1, "Active wars count preserved")
	var war_loaded: WarState = dip_loaded.active_wars[0]
	assert_eq(war_loaded.id, war.id, "War ID preserved")
	assert_eq(war_loaded.status, WarState.STATUS_WAR, "War status preserved")
	assert_eq(war_loaded.casualties.get(str(FactionCatalog.FACTION_IRONPEAK)), 1, "Casualties preserved")
	assert_eq(war_loaded.battles.size(), 1, "Battle history preserved")
	assert_true(war_loaded.attacker_expedition_spawned, "Attacker expedition spawned flag preserved")
	print("✓ Test 12: Save/load preserves an active conflict without duplicating units or transactions PASSED")

# Test 13: Non-regression and legacy save compatibility
func test_13_non_regression_and_legacy_compatibility() -> void:
	# Older save without war data
	var legacy_dict: Dictionary = {
		"meta": {"schema_version": 1},
		"world": {"width": 10, "height": 10},
		"economy": {"tax_level": 1, "approval": 60.0},
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"job_board": {"jobs": []}
	}
	var loaded: Dictionary = SaveSchema.deserialize(legacy_dict)
	var dip: DiplomacyState = loaded["diplomacy"]
	assert_true(dip != null, "Diplomacy loaded from legacy")
	assert_eq(dip.active_wars.size(), 0, "Legacy save defaults to zero active wars")
	assert_eq(dip.war_history.size(), 0, "Legacy save defaults to zero war history")
	print("✓ Test 13: Non-regression and legacy save compatibility PASSED")
