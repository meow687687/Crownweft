class_name TestCivicIncidents
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const IncidentCatalog = preload("res://scripts/domain/incident_catalog.gd")
const IncidentService = preload("res://scripts/simulation/incident_service.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestCivicIncidents (Task 22 Integration) ---")
	print("=======================================================\n")

	test_1_incident_catalog_integrity()
	test_2_food_shortage_triggers_hungry_settlement()
	test_3_approval_collapse_triggers_realm_grievance()
	test_4_frontier_threat_triggers_frontier_trouble()
	test_5_decision_strict_rationing_enacts_policy()
	test_6_decision_prioritize_food_boosts_building_priorities()
	test_7_decision_relief_purchase_deducts_coin_adds_food()
	test_8_prerequisites_blocking_when_resources_insufficient()
	test_9_deduplication_and_cooldown_enforcement()
	test_10_resolution_conditions_evaluation()
	test_11_event_log_and_chronicle_integration()
	test_12_save_load_round_trip_preservation()
	test_13_scenario_independence_and_clean_reset()
	test_14_simulation_invariants_pass()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestCivicIncidents: ALL 14 TEST SUITES PASSED ---")
	else:
		print("--- TestCivicIncidents: %d FAILURES DETECTED ---" % _tests_failed)
	print("=======================================================\n")
	quit(_tests_failed)

func _assert(condition: bool, msg: String) -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		printerr("FAIL: ", msg)

func _create_test_world() -> WorldScene:
	var w: WorldScene = WorldScene.new()
	w._init_simulation(ScenarioCatalog.SCENARIO_FOUNDING, 2026)
	return w

# 1. Catalog Integrity
func test_1_incident_catalog_integrity() -> void:
	print(">> Test 1: Incident catalog definitions and option schemas")
	var defs: Dictionary = IncidentCatalog.get_all_defs()
	_assert(defs.size() == 3, "Catalog contains exactly 3 core incidents")

	for inc_id in IncidentCatalog.INCIDENT_IDS:
		_assert(defs.has(inc_id), "Catalog contains incident %s" % str(inc_id))
		var def: Dictionary = defs[inc_id]
		_assert(not def.get("title", "").is_empty(), "Incident %s has title" % str(inc_id))
		_assert(def.get("urgency", &"") in [&"critical", &"high", &"medium", &"civic"], "Incident %s has valid urgency" % str(inc_id))
		var options: Array = def.get("options", [])
		_assert(options.size() == 3, "Incident %s has exactly 3 options" % str(inc_id))
		for opt in options:
			_assert(not opt.get("id", &"").is_empty(), "Option has valid id")
			_assert(not opt.get("title", "").is_empty(), "Option has valid title")
			_assert(not opt.get("consequence_preview", "").is_empty(), "Option has consequence preview")
	print("✓ Test 1: Incident catalog integrity PASSED\n")

# 2. Food shortage trigger
func test_2_food_shortage_triggers_hungry_settlement() -> void:
	print(">> Test 2: Food shortage triggers hungry_settlement with cause")
	var w: WorldScene = _create_test_world()
	# Drain all food stores
	for b in w.buildings:
		if b.inventory != null:
			var b_qty: int = b.inventory.get_quantity(&"bread")
			if b_qty > 0: b.inventory.remove_resource(&"bread", b_qty, "TEST_DRAIN")
			var m_qty: int = b.inventory.get_quantity(&"meat")
			if m_qty > 0: b.inventory.remove_resource(&"meat", m_qty, "TEST_DRAIN")
	
	w.current_tick = 36
	var triggered: Array[StringName] = w.incidents.evaluate_incidents(w, {"hungry": 2, "at_risk": 1, "fed": 0}, w.current_tick)
	_assert(triggered.has(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Hungry settlement triggered")
	_assert(w.incidents.is_incident_active(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Incident is active")
	
	var data: Dictionary = w.incidents.get_active_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT)
	_assert("0 food in storage" in data.get("cause", ""), "Cause diagnostic explains food storage")
	w.free()
	print("✓ Test 2: Food shortage trigger PASSED\n")

# 3. Approval collapse trigger
func test_3_approval_collapse_triggers_realm_grievance() -> void:
	print(">> Test 3: Approval collapse triggers realm_grievance")
	var w: WorldScene = _create_test_world()
	w.economy.approval = 38.0
	w.current_tick = 48

	var triggered: Array[StringName] = w.incidents.evaluate_incidents(w, {"hungry": 0, "at_risk": 0, "fed": 10}, w.current_tick)
	_assert(triggered.has(IncidentCatalog.INCIDENT_REALM_GRIEVANCE), "Realm grievance triggered")
	_assert(w.incidents.is_incident_active(IncidentCatalog.INCIDENT_REALM_GRIEVANCE), "Incident is active")
	var data: Dictionary = w.incidents.get_active_incident(IncidentCatalog.INCIDENT_REALM_GRIEVANCE)
	_assert("38%" in data.get("cause", ""), "Cause string records 38% approval")
	w.free()
	print("✓ Test 3: Approval collapse trigger PASSED\n")

# 4. Frontier threat trigger
func test_4_frontier_threat_triggers_frontier_trouble() -> void:
	print(">> Test 4: Supply depletion / active war triggers frontier_trouble")
	var w: WorldScene = _create_test_world()
	var p_armies = w.regional_world.get_armies_for_faction(FactionCatalog.FACTION_PLAYER)
	_assert(not p_armies.is_empty(), "Player has army")
	var army = p_armies[0]
	army.supplies[&"grain"] = 10.0 # Deplete supplies below 25.0
	w.current_tick = 36

	var triggered: Array[StringName] = w.incidents.evaluate_incidents(w, {"hungry": 0, "at_risk": 0, "fed": 10}, w.current_tick)
	_assert(triggered.has(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE), "Frontier trouble triggered")
	_assert(w.incidents.is_incident_active(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE), "Frontier trouble is active")
	w.free()
	print("✓ Test 4: Frontier threat trigger PASSED\n")

# 5. Strict rationing decision
func test_5_decision_strict_rationing_enacts_policy() -> void:
	print(">> Test 5: Consequential choice enacts strict rationing policy")
	var w: WorldScene = _create_test_world()
	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	var initial_app: float = w.economy.approval

	var res: Dictionary = w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"strict_rationing")
	_assert(res.get("ok", false), "Decision applied successfully")
	_assert(w.government.get_policy(LawCatalog.LAW_RATIONING) == &"strict", "Strict rationing law enacted")
	_assert(w.economy.approval < initial_app, "Approval reduced by rationing decree")

	var inc_data: Dictionary = w.incidents.get_active_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT)
	_assert(inc_data.get("status", &"") == &"decision_applied", "Status is decision_applied")
	_assert(inc_data.get("chosen_option_id", &"") == &"strict_rationing", "Chosen option recorded")
	w.free()
	print("✓ Test 5: Strict rationing decision PASSED\n")

# 6. Prioritize food building priorities
func test_6_decision_prioritize_food_boosts_building_priorities() -> void:
	print(">> Test 6: Prioritize food boosts farm and bakery work priorities")
	var w: WorldScene = _create_test_world()
	var farm: BuildingState = w.place_building(&"farm", Vector2i(20, 20), true)
	var bakery: BuildingState = w.place_building(&"bakery", Vector2i(25, 20), true)
	farm.status = BuildingState.Status.ACTIVE
	bakery.status = BuildingState.Status.ACTIVE
	farm.work_priority = 1
	bakery.work_priority = 1

	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	var res: Dictionary = w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"prioritize_agriculture")
	_assert(res.get("ok", false), "Decision applied")
	_assert(farm.work_priority == BuildingState.PRIORITY_MAX, "Farm priority boosted to maximum")
	_assert(bakery.work_priority == BuildingState.PRIORITY_MAX, "Bakery priority boosted to maximum")
	w.free()
	print("✓ Test 6: Prioritize food decision PASSED\n")

# 7. Emergency relief purchase
func test_7_decision_relief_purchase_deducts_coin_adds_food() -> void:
	print(">> Test 7: Emergency relief purchase deducts coin and adds food")
	var w: WorldScene = _create_test_world()
	var th: BuildingState = w.buildings[0]
	th.inventory.remove_resource(&"coin", th.inventory.get_quantity(&"coin"), "TEST")
	th.inventory.add_resource(&"coin", 50, "TEST")
	var initial_bread: int = th.inventory.get_quantity(&"bread")

	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	var res: Dictionary = w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"emergency_relief")
	_assert(res.get("ok", false), "Emergency relief applied")
	_assert(th.inventory.get_quantity(&"coin") == 25, "25 Coin deducted from Town Hall (50 -> 25)")
	_assert(th.inventory.get_quantity(&"bread") == initial_bread + 15, "15 Bread added to Town Hall")
	w.free()
	print("✓ Test 7: Relief purchase decision PASSED\n")

# 8. Prerequisites blocking
func test_8_prerequisites_blocking_when_resources_insufficient() -> void:
	print(">> Test 8: Prerequisites block choices when Town Hall lacks resources")
	var w: WorldScene = _create_test_world()
	var th: BuildingState = w.buildings[0]
	th.inventory.remove_resource(&"coin", th.inventory.get_quantity(&"coin"), "TEST")
	th.inventory.add_resource(&"coin", 5, "TEST") # Needs 25

	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	var check: Dictionary = w.incidents.check_option_prerequisites(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"emergency_relief", w)
	_assert(check.get("ok", false) == false, "Prerequisite check failed as expected")
	_assert("Insufficient Coin" in check.get("reason", ""), "Descriptive reason returned")

	var res: Dictionary = w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"emergency_relief")
	_assert(res.get("ok", false) == false, "Application blocked")
	_assert(th.inventory.get_quantity(&"coin") == 5, "Coin not deducted")
	w.free()
	print("✓ Test 8: Prerequisites blocking PASSED\n")

# 9. Deduplication and cooldown
func test_9_deduplication_and_cooldown_enforcement() -> void:
	print(">> Test 9: Deduplication and cooldown prevents immediate recurrence")
	var w: WorldScene = _create_test_world()
	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	var second_attempt: bool = w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 25)
	_assert(not second_attempt, "Cannot trigger duplicate incident while active")

	w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"strict_rationing")
	w.incidents.resolve_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 30)

	_assert(not w.incidents.is_incident_active(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Incident no longer active")
	_assert(w.incidents.cooldowns.get(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, 0) == 30 + IncidentCatalog.DEFAULT_COOLDOWN_TICKS, "Cooldown tick set correctly")

	# Attempt to trigger during cooldown
	var can_trig: bool = w.incidents.can_trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, {"hungry": 5}, 40)
	_assert(not can_trig, "Trigger blocked during cooldown period")
	w.free()
	print("✓ Test 9: Deduplication and cooldown PASSED\n")

# 10. Resolution conditions
func test_10_resolution_conditions_evaluation() -> void:
	print(">> Test 10: Automatic resolution when simulation conditions recover")
	var w: WorldScene = _create_test_world()
	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	w.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"strict_rationing")

	# Still hungry -> should NOT resolve
	var resolved_before: bool = w.incidents.check_resolution(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, {"hungry": 1, "at_risk": 0})
	_assert(not resolved_before, "Does not resolve while hunger persists")

	# Supply ample food to Town Hall
	var th: BuildingState = w.buildings[0]
	th.inventory.add_resource(&"bread", w.citizens.size() * 3, "TEST")

	# Fully fed and stocked -> resolves at multiple of 12
	w.current_tick = 60
	w.incidents.evaluate_incidents(w, {"hungry": 0, "at_risk": 0, "fed": w.citizens.size()}, w.current_tick)
	_assert(not w.incidents.is_incident_active(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Incident resolved automatically")
	_assert(w.incidents.resolution_history.size() == 1, "Recorded in resolution history")
	w.free()
	print("✓ Test 10: Automatic resolution PASSED\n")

# 11. Event log chronicle integration
func test_11_event_log_and_chronicle_integration() -> void:
	print(">> Test 11: EventLogService records appearance, decision, and resolution")
	var w: WorldScene = _create_test_world()
	var initial_events: int = w.event_log.events.size()

	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_REALM_GRIEVANCE, w, 24)
	_assert(w.event_log.events.size() > initial_events, "Trigger logged to chronicle")
	var latest_ev: Dictionary = w.event_log.events.back()
	_assert(latest_ev.get("category", &"") == &"civic", "Category is civic")
	_assert("CIVIC INCIDENT" in latest_ev.get("message", ""), "Message indicates incident")

	w.apply_incident_decision(IncidentCatalog.INCIDENT_REALM_GRIEVANCE, &"lower_taxes")
	latest_ev = w.event_log.events.back()
	_assert("DECISION ENACTED" in latest_ev.get("message", ""), "Decision enacted logged")

	w.incidents.resolve_incident(IncidentCatalog.INCIDENT_REALM_GRIEVANCE, w, 50)
	latest_ev = w.event_log.events.back()
	_assert("INCIDENT RESOLVED" in latest_ev.get("message", ""), "Resolution logged")
	w.free()
	print("✓ Test 11: Event log chronicle integration PASSED\n")

# 12. Save/Load round trip
func test_12_save_load_round_trip_preservation() -> void:
	print(">> Test 12: Save/load round-trip preserves active incidents and cooldowns")
	var w1: WorldScene = _create_test_world()
	var th: BuildingState = w1.buildings[0]
	th.inventory.add_resource(&"coin", 50, "TEST")
	th.inventory.add_resource(&"bread", 20, "TEST")

	w1.incidents.trigger_incident(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE, w1, 24)
	w1.apply_incident_decision(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE, &"resupply_army")
	w1.incidents.cooldowns[IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT] = 180

	var save_path: String = "user://saves/test_civic_incidents_save.json"
	var saved: bool = w1.save_game(save_path)
	_assert(saved, "Saved game successfully")

	var w2: WorldScene = _create_test_world()
	var loaded: bool = w2.load_game(save_path)
	_assert(loaded, "Loaded game successfully")

	_assert(w2.incidents.is_incident_active(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE), "Active incident restored")
	var restored_inc: Dictionary = w2.incidents.get_active_incident(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE)
	_assert(restored_inc.get("chosen_option_id", &"") == &"resupply_army", "Chosen option restored")
	_assert(w2.incidents.cooldowns.get(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, 0) == 180, "Cooldown restored")

	w1.free()
	w2.free()
	print("✓ Test 12: Save/load round trip PASSED\n")

# 13. Scenario independence
func test_13_scenario_independence_and_clean_reset() -> void:
	print(">> Test 13: Clean reset across scenario transitions")
	var w: WorldScene = _create_test_world()
	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 10)
	_assert(w.incidents.is_incident_active(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Incident active in scenario 1")

	# Switch scenario
	w._init_simulation(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	_assert(not w.incidents.is_incident_active(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT), "Incident cleared on scenario switch")
	_assert(w.incidents.active_incidents.is_empty(), "Zero active incidents in new scenario")
	_assert(w.incidents.cooldowns.is_empty(), "Cooldowns cleared")
	w.free()
	print("✓ Test 13: Scenario independence PASSED\n")

# 14. Simulation Invariants
func test_14_simulation_invariants_pass() -> void:
	print(">> Test 14: Invariant checker passes with active incidents and cooldowns")
	var w: WorldScene = _create_test_world()
	w.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, w, 24)
	w.incidents.cooldowns[IncidentCatalog.INCIDENT_REALM_GRIEVANCE] = 120

	var audit_res = SimulationInvariantChecker.audit(
		w.world_state,
		w.buildings,
		w.citizens,
		w.job_board,
		w.logistics,
		w.pathfinding,
		w.economy,
		w.government,
		w.diplomacy,
		w.regional_world,
		w.incidents
	)

	_assert(audit_res.passed, "All invariants passed: " + audit_res.summary())
	_assert(audit_res.violations.is_empty(), "0 violations reported")
	w.free()
	print("✓ Test 14: Simulation invariants PASSED\n")
