class_name TestRegionalCampaigns
extends SceneTree

# A failed assert() only aborts the current function, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("\n--- Running TestRegionalCampaigns ---")
	test_1_campaign_objective_lifecycle()
	test_2_regional_engagement_detection()
	test_3_peace_and_ceasefire_prevent_engagement()
	test_4_deterministic_combat_force_ratio()
	test_5_terrain_defensive_advantage_modifier()
	test_6_supply_condition_modifiers()
	test_7_bounded_casualties_formula()
	test_8_single_casualty_accounting()
	test_9_defeat_and_retreat_handling()
	test_10_territorial_occupation_after_victory()
	test_11_permanent_control_transfer_via_treaty()
	test_12_diplomatic_chronicle_and_war_records()
	test_13_save_load_round_trip()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestRegionalCampaigns PASSED ---\n")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Assertion failed: " + message)
		printerr("Assertion failed: " + message)
		_failed_assertions += 1

func _setup_world() -> RegionalWorldState:
	var state := RegionalWorldState.new()
	state.regions = RegionCatalog.create_default_regions()
	state.routes = RegionCatalog.create_default_routes()
	return state

func test_1_campaign_objective_lifecycle() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	
	var obj := world.create_objective(
		FactionCatalog.FACTION_PLAYER,
		CampaignObjective.TYPE_DEFEND_REGION,
		RegionCatalog.REGION_CROWNWEFT,
		0,
		1,
		10
	)
	_assert(obj != null, "Objective created")
	_assert(obj.status == CampaignObjective.STATUS_IN_PROGRESS, "Objective starts in progress")
	_assert(obj.faction_id == FactionCatalog.FACTION_PLAYER, "Faction assigned correctly")
	_assert(obj.target_region_id == RegionCatalog.REGION_CROWNWEFT, "Target region assigned")

	var active: Array[CampaignObjective] = world.get_active_objectives(FactionCatalog.FACTION_PLAYER)
	_assert(active.size() == 1, "One active objective found")

	# Target defended successfully
	obj.complete("Threat repelled by royal forces", 50)
	_assert(obj.status == CampaignObjective.STATUS_COMPLETED, "Objective completed")
	_assert(obj.completion_tick == 50, "Completion tick recorded")
	_assert(obj.reason.contains("Threat repelled"), "Completion reason recorded")
	_assert(world.get_active_objectives(FactionCatalog.FACTION_PLAYER).is_empty(), "No active objectives remaining")

	# Failed objective lifecycle
	var obj_fail := world.create_objective(
		FactionCatalog.FACTION_PLAYER,
		CampaignObjective.TYPE_OCCUPY_REGION,
		RegionCatalog.REGION_IRONPEAK,
		0,
		1,
		60
	)
	obj_fail.fail("Force routed before objective achieved", 120)
	_assert(obj_fail.status == CampaignObjective.STATUS_FAILED, "Objective marked failed")
	_assert(obj_fail.completion_tick == 120, "Failure tick recorded")

	print("✓ Test 1: Campaign objective lifecycle and state transitions PASSED")

func test_2_regional_engagement_detection() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()

	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Territorial dispute", 10, WarState.STATUS_WAR)
	_assert(war != null, "Active war created")

	# Station opposing armies at Shattered Pass
	var crown_army := world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Crown Defenders",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 10, &"archer": 5},
		30,
		10
	)
	var iron_army := world.create_army(
		FactionCatalog.FACTION_IRONPEAK,
		"Ironpeak Invaders",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 12, &"archer": 6},
		30,
		10
	)

	var resolved := world.detect_and_resolve_engagements(diplomacy, 15)
	_assert(resolved.size() == 1, "Detected and resolved exactly 1 regional engagement")
	_assert(world.engagements.size() == 1, "Engagement recorded in world state")

	var eng: RegionalEngagement = world.engagements.values()[0]
	_assert(eng.region_id == RegionCatalog.REGION_SHATTERED_PASS, "Engagement occurred at Shattered Pass")
	_assert(eng.is_resolved(), "Engagement transitioned to RESOLVED status")
	_assert(eng.resolution_tick == 15, "Resolution tick recorded")

	print("✓ Test 2: Regional engagement detection between hostile forces PASSED")

func test_3_peace_and_ceasefire_prevent_engagement() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()

	# 1. At peace: Crown and Valen in same region
	world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Crown Trade Escort",
		RegionCatalog.REGION_VALEN,
		{&"warrior": 10},
		30,
		10
	)
	world.create_army(
		FactionCatalog.FACTION_VALEN,
		"Valen City Guard",
		RegionCatalog.REGION_VALEN,
		{&"warrior": 15},
		30,
		10
	)

	var res_peace := world.detect_and_resolve_engagements(diplomacy, 15)
	_assert(res_peace.is_empty(), "Peacetime factions do NOT engage in battle")
	_assert(world.engagements.is_empty(), "No engagements generated during peace")

	# 2. Under ceasefire: Crown and Ironpeak
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border dispute", 10, WarState.STATUS_CEASEFIRE)
	world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Crown Border Watch",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 10},
		30,
		20
	)
	world.create_army(
		FactionCatalog.FACTION_IRONPEAK,
		"Ironpeak Truce Envoy",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 10},
		30,
		20
	)

	var res_ceasefire := world.detect_and_resolve_engagements(diplomacy, 25)
	_assert(res_ceasefire.is_empty(), "Ceasefire strictly prohibits military engagements")

	print("✓ Test 3: Peace and ceasefire prevent prohibited hostile engagements PASSED")

func test_4_deterministic_combat_force_ratio() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Clash", 1, WarState.STATUS_WAR)

	# Overwhelming Attacker (80 vs 15)
	var att_strong := world.create_army(FactionCatalog.FACTION_PLAYER, "Strong Army", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 80}, 30, 1)
	var def_weak := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Weak Army", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 15}, 30, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 5)
	_assert(res.size() == 1, "Engagement resolved")
	var eng: RegionalEngagement = res[0]
	_assert(eng.outcome == RegionalEngagement.OUTCOME_ATTACKER_VICTORY, "Force ratio > 0.55 yields attacker victory")

	print("✓ Test 4: Deterministic force ratio calculation PASSED")

func test_5_terrain_defensive_advantage_modifier() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Pass Defense", 1, WarState.STATUS_WAR)

	var pass_reg: RegionState = world.get_region(RegionCatalog.REGION_SHATTERED_PASS)
	pass_reg.defensive_advantage = 1.60 # Strong mountain fortification

	# Defender has 40 troops, Attacker has 45 troops, equal supplies
	var def_army := world.create_army(FactionCatalog.FACTION_PLAYER, "Pass Garrison", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 40}, 20, 1)
	var att_army := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Climbers", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 45}, 20, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	_assert(res.size() == 1, "Engagement resolved")
	var eng: RegionalEngagement = res[0]
	# P_att = 45 * 1.15 = 51.75; P_def = 40 * 1.15 * 1.60 = 73.6; Ratio = 51.75 / 125.35 = 0.413 < 0.45
	_assert(eng.outcome == RegionalEngagement.OUTCOME_DEFENDER_VICTORY, "Terrain defensive advantage enables victory for smaller defending force")

	print("✓ Test 5: Terrain defensive advantage modifier PASSED")

func test_6_supply_condition_modifiers() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Supply War", 1, WarState.STATUS_WAR)

	var open_reg: RegionState = world.get_region(RegionCatalog.REGION_GREY_MARCHES)
	open_reg.defensive_advantage = 1.0

	# Attacker well-supplied (40 grain -> +15%), Defender starving (0 grain -> -30%)
	# Equal starting troop count (30 vs 30)
	var att_fed := world.create_army(FactionCatalog.FACTION_PLAYER, "Fed Army", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 30}, 40, 1)
	var def_starved := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Starved Army", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 30}, 0, 1)
	def_starved.status = ArmyState.STATUS_SUPPLY_STRAINED

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	_assert(res.size() == 1, "Battle resolved")
	var eng: RegionalEngagement = res[0]
	_assert(eng.winner_faction == FactionCatalog.FACTION_PLAYER, "Well-supplied army defeats supply-strained equivalent force")

	print("✓ Test 6: Supply condition modifiers (+15% vs -30%) PASSED")

func test_7_bounded_casualties_formula() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Skirmish", 1, WarState.STATUS_WAR)

	var army_a := world.create_army(FactionCatalog.FACTION_PLAYER, "Crown Force", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 100}, 25, 1)
	var army_b := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Iron Force", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 100}, 25, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	_assert(res.size() == 1, "Engagement occurred")
	var eng: RegionalEngagement = res[0]

	# Casualties must be strictly bounded between 20% and 45%
	_assert(eng.attacker_losses >= 20 and eng.attacker_losses <= 45, "Attacker casualties within 20-45% bound")
	_assert(eng.defender_losses >= 20 and eng.defender_losses <= 45, "Defender casualties within 20-45% bound")
	_assert(army_a.strength == 100 - eng.attacker_losses, "Army A roster deducted correctly")
	_assert(army_b.strength == 100 - eng.defender_losses, "Army B roster deducted correctly")

	print("✓ Test 7: Bounded casualties formula (20-45%) PASSED")

func test_8_single_casualty_accounting() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "War of Attrition", 1, WarState.STATUS_WAR)

	_assert(war.casualties.get(str(FactionCatalog.FACTION_PLAYER), 0) == 0, "Initial player casualties zero")
	_assert(war.casualties.get(str(FactionCatalog.FACTION_IRONPEAK), 0) == 0, "Initial enemy casualties zero")

	var crown_force := world.create_army(FactionCatalog.FACTION_PLAYER, "Crown Guard", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 50}, 30, 1)
	var iron_force := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Iron Vanguard", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 50}, 30, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	var eng: RegionalEngagement = res[0]

	var crown_casualties_war: int = int(war.casualties.get(str(FactionCatalog.FACTION_PLAYER), 0))
	var iron_casualties_war: int = int(war.casualties.get(str(FactionCatalog.FACTION_IRONPEAK), 0))

	_assert(crown_casualties_war == eng.attacker_losses, "War casualties match engagement losses exactly for attacker")
	_assert(iron_casualties_war == eng.defender_losses, "War casualties match engagement losses exactly for defender")

	# Re-run detection on next tick without movements — no phantom engagements or casualty duplicates
	var next_res := world.detect_and_resolve_engagements(diplomacy, 11)
	_assert(next_res.is_empty(), "No duplicate engagement triggered")
	_assert(int(war.casualties.get(str(FactionCatalog.FACTION_PLAYER), 0)) == crown_casualties_war, "Casualties not duplicated")

	print("✓ Test 8: Single casualty accounting across WarState and ArmyState PASSED")

func test_9_defeat_and_retreat_handling() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Invasion", 1, WarState.STATUS_WAR)

	# Overwhelming Crown victory at Shattered Pass
	var crown := world.create_army(FactionCatalog.FACTION_PLAYER, "Crushing Force", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 100}, 30, 1)
	var iron := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Outmatched Force", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 15}, 30, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	_assert(res.size() == 1, "Engagement resolved")
	var eng: RegionalEngagement = res[0]
	_assert(eng.outcome == RegionalEngagement.OUTCOME_ATTACKER_VICTORY, "Attacker achieved victory")

	# Defeated iron army with surviving troops must be retreating to a valid neighbor (e.g. Ironpeak)
	_assert(iron.is_active(), "Iron army has survivors")
	_assert(iron.status == ArmyState.STATUS_RETREATING, "Defeated army entered STATUS_RETREATING")
	_assert(iron.destination_region_id != RegionCatalog.REGION_SHATTERED_PASS, "Retreat destination set to adjacent region")
	_assert(not iron.route_path.is_empty(), "Retreat route path established")

	# Test total elimination -> STATUS_DESTROYED
	var doomed := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Doomed Scout", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 1}, 5, 20)
	doomed.apply_casualties(1, "Wiped out in ambush", 25)
	_assert(doomed.status == ArmyState.STATUS_DESTROYED, "Fully eliminated unit becomes STATUS_DESTROYED")
	_assert(not doomed.is_active(), "Destroyed unit is no longer active")

	print("✓ Test 9: Defeat, retreat, and destruction handling PASSED")

func test_10_territorial_occupation_after_victory() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_IRONPEAK, "Offensive", 1, WarState.STATUS_WAR)

	var iron_reg: RegionState = world.get_region(RegionCatalog.REGION_IRONPEAK)
	_assert(iron_reg.controlling_faction == FactionCatalog.FACTION_IRONPEAK, "Ironpeak initially controls region")
	_assert(iron_reg.occupying_faction == &"", "Region starts unoccupied")

	# Crown army takes Ironpeak capital region
	var crown := world.create_army(FactionCatalog.FACTION_PLAYER, "Crown Expedition", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 90}, 30, 1)
	crown.current_region_id = RegionCatalog.REGION_IRONPEAK
	var iron_def := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Weak Iron Defenders", RegionCatalog.REGION_IRONPEAK, {&"warrior": 10}, 30, 1)

	var res := world.detect_and_resolve_engagements(diplomacy, 10)
	_assert(res.size() == 1, "Battle resolved")

	_assert(iron_reg.status == RegionState.STATUS_OCCUPIED, "Region status transitions to OCCUPIED")
	_assert(iron_reg.occupying_faction == FactionCatalog.FACTION_PLAYER, "Occupier set to The Crown")
	_assert(iron_reg.controlling_faction == FactionCatalog.FACTION_IRONPEAK, "Legal sovereign controller remains Ironpeak (not yet ceded)")
	_assert(iron_reg.get_effective_controller() == FactionCatalog.FACTION_PLAYER, "Effective controller is the occupier")

	print("✓ Test 10: Territorial military occupation distinct from sovereignty PASSED")

func test_11_permanent_control_transfer_via_treaty() -> void:
	var world := _setup_world()
	var iron_reg: RegionState = world.get_region(RegionCatalog.REGION_IRONPEAK)
	iron_reg.set_occupation(FactionCatalog.FACTION_PLAYER, "Wartime occupation", 50)
	_assert(iron_reg.status == RegionState.STATUS_OCCUPIED, "Occupied prior to treaty")

	# Ratify treaty cession
	var transfer_res := world.transfer_control(RegionCatalog.REGION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Treaty of Ironpeak Cession", 100)
	_assert(transfer_res["ok"], "Control transfer succeeded")
	_assert(iron_reg.controlling_faction == FactionCatalog.FACTION_PLAYER, "Sovereign control transferred to Crown")
	_assert(iron_reg.occupying_faction == &"", "Occupation status cleared upon legal cession")
	_assert(iron_reg.status == RegionState.STATUS_CONTROLLED, "Region status is now CONTROLLED")

	print("✓ Test 11: Permanent control transfer via treaty cession PASSED")

func test_12_diplomatic_chronicle_and_war_records() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border Clash", 1, WarState.STATUS_WAR)

	var initial_chronicle_count: int = diplomacy.diplomatic_chronicle.size()
	var att := world.create_army(FactionCatalog.FACTION_PLAYER, "Royal Army", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 30}, 20, 1)
	var def := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Raiders", RegionCatalog.REGION_GREY_MARCHES, {&"warrior": 30}, 20, 1)

	world.detect_and_resolve_engagements(diplomacy, 15)

	_assert(diplomacy.diplomatic_chronicle.size() > initial_chronicle_count, "Battle logged in diplomatic chronicle")
	var last_entry: Dictionary = diplomacy.diplomatic_chronicle.back()
	_assert(last_entry.get("text", "").contains("Grey Marches"), "Chronicle details engagement location")

	_assert(war.battles.size() == 1, "Battle recorded in WarState")
	var battle_record: Dictionary = war.battles[0]
	_assert(battle_record["tick"] == 15, "Battle tick recorded")
	_assert(battle_record["attacker_losses"] > 0, "Attacker losses recorded in battle history")
	_assert(battle_record["defender_losses"] > 0, "Defender losses recorded in battle history")

	print("✓ Test 12: Diplomatic chronicle and war battle records PASSED")

func test_13_save_load_round_trip() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var war := diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Campaign War", 1, WarState.STATUS_WAR)

	var obj := world.create_objective(FactionCatalog.FACTION_PLAYER, CampaignObjective.TYPE_DEFEND_REGION, RegionCatalog.REGION_CROWNWEFT, 0, war.id, 5)
	
	var att := world.create_army(FactionCatalog.FACTION_PLAYER, "Crown Guard", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 40}, 25, 1)
	var def := world.create_army(FactionCatalog.FACTION_IRONPEAK, "Clan Vanguard", RegionCatalog.REGION_SHATTERED_PASS, {&"warrior": 20}, 25, 1)

	world.detect_and_resolve_engagements(diplomacy, 10)

	var serialized: Dictionary = world.serialize()
	_assert(serialized.has("objectives"), "Serialized dict contains objectives")
	_assert(serialized.has("engagements"), "Serialized dict contains engagements")

	var loaded: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(loaded.objectives.size() == world.objectives.size(), "All objectives deserialized")
	_assert(loaded.engagements.size() == world.engagements.size(), "All engagements deserialized")

	var loaded_obj: CampaignObjective = loaded.get_objective(obj.id)
	_assert(loaded_obj != null, "Target objective found")
	_assert(loaded_obj.type == obj.type, "Objective type preserved")
	_assert(loaded_obj.target_region_id == obj.target_region_id, "Target region preserved")

	var loaded_eng: RegionalEngagement = loaded.engagements.values()[0]
	var original_eng: RegionalEngagement = world.engagements.values()[0]
	_assert(loaded_eng.outcome == original_eng.outcome, "Engagement outcome preserved")
	_assert(loaded_eng.attacker_losses == original_eng.attacker_losses, "Attacker losses preserved")
	_assert(loaded_eng.defender_losses == original_eng.defender_losses, "Defender losses preserved")

	# Test legacy save compatibility (no objectives or engagements key)
	serialized.erase("objectives")
	serialized.erase("engagements")
	var legacy_loaded: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(legacy_loaded.objectives.is_empty(), "Legacy save loads safely with empty objectives")
	_assert(legacy_loaded.engagements.is_empty(), "Legacy save loads safely with empty engagements")

	print("✓ Test 13: Full save/load round-trip and legacy compatibility PASSED")
