extends SceneTree

func _init() -> void:
	print("\n--- Running TestPoliticalAgents ---")
	test_1_faction_definitions_valid_and_unique()
	test_2_relationship_bounds_and_modifiers()
	test_3_deterministic_utility_decision_making()
	test_4_invalid_actions_rejected_before_execution()
	test_5_aid_acceptance_transfers_resources_and_builds_trust()
	test_6_aid_refusal_creates_distinct_event_and_resentment()
	test_7_trade_proposals_use_real_resources_and_currency()
	test_8_alliance_persistence_and_approval_effect()
	test_9_faction_memory_retention_and_decay()
	test_10_different_goals_and_doctrines_yield_different_choices()
	test_11_agents_do_not_access_hidden_information()
	test_12_cooldowns_prevent_excessive_oscillation()
	test_13_save_load_preserves_diplomacy_state()
	test_14_legacy_save_compatibility_and_non_regression()
	print("--- TestPoliticalAgents PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

# Test 1: Faction definitions valid and unique
func test_1_faction_definitions_valid_and_unique() -> void:
	var defs: Dictionary = FactionCatalog.get_all_defs()
	assert_true(defs.size() >= 4, "Must define at least 4 factions (Player + 3 neighbours)")
	
	var seen_ids: Array[StringName] = []
	for f_id in FactionCatalog.FACTION_IDS:
		assert_true(not seen_ids.has(f_id), "Faction ID must be unique: %s" % str(f_id))
		seen_ids.append(f_id)
		
		var f_def: Dictionary = FactionCatalog.get_faction_def(f_id)
		assert_true(f_def.has("display_name"), "Faction must have display_name")
		assert_true(f_def.has("culture"), "Faction must have culture")
		assert_true(f_def.has("doctrine"), "Faction must have doctrine")
		assert_true(f_def.has("initial_treasury"), "Faction must have initial_treasury")
		assert_true(f_def.has("default_goals"), "Faction must have default_goals")
		assert_true(f_def.has("initial_resources"), "Faction must have initial_resources")
	print("✓ Test 1: Faction definitions and runtime IDs valid and unique PASSED")

# Test 2: Relationship values remain within documented bounds
func test_2_relationship_bounds_and_modifiers() -> void:
	var rel := DiplomaticRelationship.new(&"valen_compact", &"player", 0.0, 10.0, 0.0, 20.0, 0.0)
	
	# Test positive clamping
	rel.modify_trust(500.0)
	assert_eq(rel.trust, DiplomaticRelationship.TRUST_MAX, "Trust should clamp to max (100)")
	rel.modify_threat(500.0)
	assert_eq(rel.threat, DiplomaticRelationship.THREAT_MAX, "Threat should clamp to max (100)")
	rel.modify_resentment(500.0)
	assert_eq(rel.resentment, DiplomaticRelationship.RESENTMENT_MAX, "Resentment should clamp to max (100)")
	rel.modify_respect(500.0)
	assert_eq(rel.respect, DiplomaticRelationship.RESPECT_MAX, "Respect should clamp to max (100)")
	rel.modify_cooperation(500.0)
	assert_eq(rel.economic_cooperation, DiplomaticRelationship.COOPERATION_MAX, "Cooperation should clamp to max (100)")

	# Test negative clamping
	rel.modify_trust(-500.0)
	assert_eq(rel.trust, DiplomaticRelationship.TRUST_MIN, "Trust should clamp to min (-100)")
	rel.modify_threat(-500.0)
	assert_eq(rel.threat, DiplomaticRelationship.THREAT_MIN, "Threat should clamp to min (0)")
	rel.modify_resentment(-500.0)
	assert_eq(rel.resentment, DiplomaticRelationship.RESENTMENT_MIN, "Resentment should clamp to min (0)")
	rel.modify_respect(-500.0)
	assert_eq(rel.respect, DiplomaticRelationship.RESPECT_MIN, "Respect should clamp to min (0)")
	rel.modify_cooperation(-500.0)
	assert_eq(rel.economic_cooperation, DiplomaticRelationship.COOPERATION_MIN, "Cooperation should clamp to min (0)")
	print("✓ Test 2: Relationship values remain within documented bounds PASSED")

# Test 3: Deterministic utility decision-making
func test_3_deterministic_utility_decision_making() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip_a := DiplomacyState.new()
	var dip_b := DiplomacyState.new()

	# Set up identical states: Old Grove Commune with low food at tick 24
	dip_a.factions[FactionCatalog.FACTION_OLD_GROVE].resources[&"grain"] = 5
	dip_b.factions[FactionCatalog.FACTION_OLD_GROVE].resources[&"grain"] = 5

	var gov := GovernmentState.new()
	dip_sys.tick_diplomacy(dip_a, 24, null, null, gov)
	dip_sys.tick_diplomacy(dip_b, 24, null, null, gov)

	var f_a: FactionState = dip_a.factions[FactionCatalog.FACTION_OLD_GROVE]
	var f_b: FactionState = dip_b.factions[FactionCatalog.FACTION_OLD_GROVE]

	assert_eq(f_a.last_utility_breakdown.get("chosen_action"), f_b.last_utility_breakdown.get("chosen_action"), "Decisions must be deterministic")
	assert_eq(f_a.last_utility_breakdown.get("utility"), f_b.last_utility_breakdown.get("utility"), "Utilities must be identical")
	assert_eq(dip_a.pending_proposals.size(), dip_b.pending_proposals.size(), "Proposals dispatched count must be identical")
	print("✓ Test 3: Identical state and inputs generate repeatable choices PASSED")

# Test 4: Invalid diplomatic actions rejected before execution
func test_4_invalid_actions_rejected_before_execution() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)
	var eco := EconomyState.new()

	# Non-existent proposal ID
	var res1: Dictionary = dip_sys.resolve_player_response(dip, 9999, true, inv, eco, 10)
	assert_true(not res1.get("ok", false), "Non-existent proposal must be rejected")

	# Already resolved proposal
	var prop := DiplomaticProposal.new(101, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, DiplomaticProposal.TYPE_AID)
	prop.status = DiplomaticProposal.STATUS_ACCEPTED
	dip.add_proposal(prop)
	var res2: Dictionary = dip_sys.resolve_player_response(dip, 101, true, inv, eco, 10)
	assert_true(not res2.get("ok", false), "Already resolved proposal must be rejected")
	print("✓ Test 4: Invalid diplomatic actions rejected before execution PASSED")

# Test 5: Aid acceptance transfers resources and builds trust
func test_5_aid_acceptance_transfers_resources_and_builds_trust() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)
	inv.add_resource(&"grain", 25, "Initial Setup")
	var eco := EconomyState.new()

	var old_grove: FactionState = dip.factions[FactionCatalog.FACTION_OLD_GROVE]
	old_grove.resources[&"grain"] = 5
	var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER)
	var initial_trust: float = rel.trust

	# Create aid proposal
	var prop := DiplomaticProposal.new(
		201,
		FactionCatalog.FACTION_OLD_GROVE,
		FactionCatalog.FACTION_PLAYER,
		DiplomaticProposal.TYPE_AID,
		{"resource_id": &"grain", "resource_amount": 10}
	)
	dip.add_proposal(prop)

	var res: Dictionary = dip_sys.resolve_player_response(dip, 201, true, inv, eco, 30)
	assert_true(res.get("ok", false), "Aid provision should succeed")
	assert_eq(inv.get_quantity(&"grain"), 15, "10 grain must be transferred out of player storage")
	assert_eq(old_grove.resources.get(&"grain"), 15, "AI faction must receive 10 grain")
	assert_true(rel.trust > initial_trust, "Trust must increase after providing aid")
	assert_eq(old_grove.memories.size(), 1, "Faction must record gratitude memory")
	assert_true(old_grove.memories[0].get("interpretation", "").contains("graciously supplied"), "Gratitude text logged")
	print("✓ Test 5: Aid acceptance transfers resources and builds trust PASSED")

# Test 6: Aid refusal creates distinct event and resentment
func test_6_aid_refusal_creates_distinct_event_and_resentment() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)
	inv.add_resource(&"grain", 25, "Initial Setup")
	var eco := EconomyState.new()

	var old_grove: FactionState = dip.factions[FactionCatalog.FACTION_OLD_GROVE]
	var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER)
	var initial_resentment: float = rel.resentment

	var prop := DiplomaticProposal.new(
		202,
		FactionCatalog.FACTION_OLD_GROVE,
		FactionCatalog.FACTION_PLAYER,
		DiplomaticProposal.TYPE_AID,
		{"resource_id": &"grain", "resource_amount": 10}
	)
	dip.add_proposal(prop)

	var res: Dictionary = dip_sys.resolve_player_response(dip, 202, false, inv, eco, 35)
	assert_true(res.get("ok", false), "Refusal resolves cleanly")
	assert_eq(inv.get_quantity(&"grain"), 25, "Player resources must NOT be deducted on refusal")
	assert_true(rel.resentment > initial_resentment, "Resentment must increase after refusing aid")
	assert_eq(old_grove.memories.size(), 1, "Faction must record refusal memory")
	assert_true(old_grove.memories[0].get("interpretation", "").contains("refused emergency relief"), "Bitterness text logged")
	print("✓ Test 6: Aid refusal creates distinct event and resentment PASSED")

# Test 7: Trade proposals use real resources and currency
func test_7_trade_proposals_use_real_resources_and_currency() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var inv := Inventory.new(1, 100)
	inv.add_resource(&"coin", 50, "Town Treasury Initial")
	var eco := EconomyState.new()

	var valen: FactionState = dip.factions[FactionCatalog.FACTION_VALEN]
	valen.resources[&"timber"] = 30
	valen.treasury = 100

	# 1. AI sells 15 timber to Player for 15 coins
	var prop_sell := DiplomaticProposal.new(
		301,
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_PLAYER,
		DiplomaticProposal.TYPE_TRADE,
		{"action": "sell", "resource_id": &"timber", "resource_amount": 15, "coin_amount": 15}
	)
	dip.add_proposal(prop_sell)

	var res_sell: Dictionary = dip_sys.resolve_player_response(dip, 301, true, inv, eco, 40)
	assert_true(res_sell.get("ok", false), "Trade sell should succeed")
	assert_eq(inv.get_quantity(&"coin"), 35, "Player treasury reduced by 15 coins (50 - 15 = 35)")
	assert_eq(valen.treasury, 115, "AI treasury increased by 15 coins (100 + 15 = 115)")
	assert_eq(inv.get_quantity(&"timber"), 15, "Player receives 15 timber in storage")
	assert_eq(valen.resources.get(&"timber"), 15, "AI loses 15 timber from stocks")

	# 2. AI buys 10 stone from Player for 18 coins, but player has NO stone!
	var prop_buy := DiplomaticProposal.new(
		302,
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_PLAYER,
		DiplomaticProposal.TYPE_TRADE,
		{"action": "buy", "resource_id": &"stone", "resource_amount": 10, "coin_amount": 18}
	)
	dip.add_proposal(prop_buy)

	var res_buy_fail: Dictionary = dip_sys.resolve_player_response(dip, 302, true, inv, eco, 45)
	assert_true(not res_buy_fail.get("ok", false), "Trade must fail if player lacks goods to export")
	assert_eq(inv.get_quantity(&"coin"), 35, "Coins unchanged on trade failure")
	print("✓ Test 7: Trade proposals use real resources and currency PASSED")

# Test 8: Alliance persistence and approval effect
func test_8_alliance_persistence_and_approval_effect() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var eco := EconomyState.new()
	var eco_sys := EconomySystem.new()
	var inv := Inventory.new(1, 100)

	var ironpeak: FactionState = dip.factions[FactionCatalog.FACTION_IRONPEAK]
	var prop := DiplomaticProposal.new(
		401,
		FactionCatalog.FACTION_IRONPEAK,
		FactionCatalog.FACTION_PLAYER,
		DiplomaticProposal.TYPE_ALLIANCE,
		{"treaty_type": &"defensive_pact", "duration_ticks": 600}
	)
	dip.add_proposal(prop)

	var res: Dictionary = dip_sys.resolve_player_response(dip, 401, true, inv, eco, 50)
	assert_true(res.get("ok", false), "Alliance acceptance succeeds")
	assert_true(ironpeak.has_active_treaty(&"defensive_pact"), "AI has active defensive pact")
	assert_true(dip.factions[FactionCatalog.FACTION_PLAYER].has_active_treaty(&"defensive_pact"), "Player has active defensive pact")

	# Verify approval calculation with defensive pact
	eco.approval = 60.0
	eco_sys.tick_economy(eco, 10, 0, 0, inv, 40, [], null, dip)
	# Base approval target is 60.0, plus 4.0 defensive pact bonus = 64.0 target
	assert_true(eco.approval > 60.0, "Active defensive alliance should increase approval (drifted toward 64.0)")
	print("✓ Test 8: Alliance agreements persist and produce their defined effects PASSED")

# Test 9: Faction memory retention and decay
func test_9_faction_memory_retention_and_decay() -> void:
	var faction := FactionState.new(FactionCatalog.FACTION_VALEN)
	faction.add_memory(10, FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN, &"trade_completed", 15.0, "Great trade", 50)
	assert_eq(faction.memories.size(), 1, "Memory added")

	faction.decay_memories(30)
	assert_eq(faction.memories.size(), 1, "Memory retained at tick 30 (expires at 60)")

	faction.decay_memories(65)
	assert_eq(faction.memories.size(), 0, "Memory decayed and cleaned at tick 65")
	print("✓ Test 9: Faction memory reflects events actually experienced with retention/decay PASSED")

# Test 10: Different goals and doctrines yield different choices
func test_10_different_goals_and_doctrines_yield_different_choices() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var gov := GovernmentState.new()

	var old_grove: FactionState = dip.factions[FactionCatalog.FACTION_OLD_GROVE]
	var ironpeak: FactionState = dip.factions[FactionCatalog.FACTION_IRONPEAK]

	# Equal low grain scenario
	old_grove.resources[&"grain"] = 5
	ironpeak.resources[&"grain"] = 5

	var rel_og: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER)
	var rel_ip: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER)

	var cand_aid: Dictionary = {
		"action_id": DiplomacySystem.ACTION_REQUEST_AID,
		"resource_id": &"grain",
		"resource_amount": 10
	}

	var score_og: Dictionary = dip_sys._calculate_utility(dip, old_grove, rel_og, cand_aid, gov)
	var score_ip: Dictionary = dip_sys._calculate_utility(dip, ironpeak, rel_ip, cand_aid, gov)

	# Sylvan Harmony doctrine and food security goals should score requesting food aid significantly higher than Martial Tradition
	assert_true(score_og["total"] > score_ip["total"], "Old Grove must value food aid higher than proud Ironpeak Clans (%f vs %f)" % [score_og["total"], score_ip["total"]])
	print("✓ Test 10: Different goals or doctrines produce different choices in equivalent scenarios PASSED")

# Test 11: Agents do not access hidden private information
func test_11_agents_do_not_access_hidden_information() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var gov := GovernmentState.new()
	var valen: FactionState = dip.factions[FactionCatalog.FACTION_VALEN]
	var rel: DiplomaticRelationship = dip.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER)

	# Candidates generated without access to private player storage
	var candidates: Array[Dictionary] = dip_sys._generate_candidate_actions(dip, valen, rel, 24, gov)
	for cand in candidates:
		assert_true(not cand.has("player_hidden_storage"), "Agent cannot access private player storage fields")
	print("✓ Test 11: Agents do not access explicitly hidden information PASSED")

# Test 12: Decision cooldowns prevent excessive oscillation
func test_12_cooldowns_prevent_excessive_oscillation() -> void:
	var dip_sys := DiplomacySystem.new()
	var dip := DiplomacyState.new()
	var gov := GovernmentState.new()
	var valen: FactionState = dip.factions[FactionCatalog.FACTION_VALEN]
	valen.resources[&"timber"] = 50

	# First evaluation creates a trade proposal and sets cooldown
	dip_sys.tick_diplomacy(dip, 24, null, null, gov)
	assert_true(valen.is_on_cooldown(&"trade", 30), "Trade cooldown must be active")
	
	# Resolve the proposal so pending check passes
	if not dip.pending_proposals.is_empty():
		dip.pending_proposals.clear()

	# Next tick at 48 (within cooldown 24 + 72 = 96): should NOT dispatch another trade proposal
	dip_sys.tick_diplomacy(dip, 48, null, null, gov)
	assert_true(dip.pending_proposals.is_empty(), "Cooldown must prevent consecutive trade proposals")
	print("✓ Test 12: Decision cooldowns prevent excessive oscillation PASSED")

# Test 13: Save/load preserves diplomacy state without duplicating effects
func test_13_save_load_preserves_diplomacy_state() -> void:
	var dip_orig := DiplomacyState.new()
	var rel: DiplomaticRelationship = dip_orig.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER)
	rel.trust = 37.5
	rel.threat = 14.0
	rel.modify_resentment(18.0)
	
	var valen: FactionState = dip_orig.factions[FactionCatalog.FACTION_VALEN]
	valen.treasury = 180
	valen.resources[&"stone"] = 65
	valen.add_memory(10, FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN, &"trade_completed", 20.0, "Prosperous trade", 500)
	valen.add_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER, 15, 600)

	var prop := DiplomaticProposal.new(501, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, DiplomaticProposal.TYPE_AID, {"resource_id": &"grain", "resource_amount": 10}, 20, 140, "Help needed")
	dip_orig.add_proposal(prop)
	dip_orig.add_chronicle(25, "Bilateral trade reached new heights.")

	# Serialize & Deserialize
	var serialized: Dictionary = dip_orig.serialize()
	var dip_loaded: DiplomacyState = DiplomacyState.deserialize(serialized)

	var rel_loaded: DiplomaticRelationship = dip_loaded.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER)
	assert_eq(rel_loaded.trust, 37.5, "Trust preserved")
	assert_eq(rel_loaded.threat, 14.0, "Threat preserved")
	assert_eq(rel_loaded.resentment, 18.0, "Resentment preserved")

	var valen_loaded: FactionState = dip_loaded.factions[FactionCatalog.FACTION_VALEN]
	assert_eq(valen_loaded.treasury, 180, "Treasury preserved")
	assert_eq(valen_loaded.resources.get(&"stone"), 65, "Resources preserved")
	assert_eq(valen_loaded.memories.size(), 1, "Memories preserved")
	assert_true(valen_loaded.has_active_treaty(&"defensive_pact"), "Treaty preserved")

	assert_eq(dip_loaded.pending_proposals.size(), 1, "Pending proposal preserved")
	assert_eq(dip_loaded.pending_proposals[0].id, 501, "Proposal ID preserved")
	assert_eq(dip_loaded.diplomatic_chronicle.size(), dip_orig.diplomatic_chronicle.size(), "Chronicle preserved")
	print("✓ Test 13: Save/load preserves diplomatic state without duplicating effects PASSED")

# Test 14: Legacy save compatibility and non-regression
func test_14_legacy_save_compatibility_and_non_regression() -> void:
	# Simulate legacy save data without "diplomacy" key
	var legacy_dict: Dictionary = {
		"meta": {"schema_version": 1},
		"world": {"width": 10, "height": 10},
		"economy": {"tax_level": 1, "approval": 60.0},
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"job_board": {"jobs": []}
	}

	var loaded_data: Dictionary = SaveSchema.deserialize(legacy_dict)
	assert_true(loaded_data.has("diplomacy"), "Must populate diplomacy state for legacy save")
	var dip: DiplomacyState = loaded_data["diplomacy"]
	assert_true(dip != null, "DiplomacyState must not be null")
	assert_true(dip.factions.has(FactionCatalog.FACTION_VALEN), "Valen Compact present in legacy fallback")
	assert_true(dip.factions.has(FactionCatalog.FACTION_OLD_GROVE), "Old Grove present in legacy fallback")
	assert_true(dip.factions.has(FactionCatalog.FACTION_IRONPEAK), "Ironpeak Clans present in legacy fallback")
	print("✓ Test 14: Legacy save compatibility and non-regression PASSED")
