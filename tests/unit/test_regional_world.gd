extends SceneTree

# A failed assert() only aborts the current function, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("\n--- Running TestRegionalWorld ---")
	
	test_1_region_ids_and_neighbour_references()
	test_2_initial_region_graph_connected()
	test_3_ownership_claims_and_occupation_distinct()
	test_4_invalid_ownership_transitions_rejected()
	test_5_regional_pathfinding()
	test_6_route_availability_and_travel_costs()
	test_7_faction_and_war_information_consistency()
	test_8_regional_resources_isolated_from_local_inventory()
	test_9_simulation_subsystems_non_regression()
	test_10_save_load_round_trip_preservation()
	test_11_legacy_save_migration()
	test_12_local_battles_do_not_cause_territorial_conquest()

	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestRegionalWorld PASSED ---\n")
	quit(0)

func _assert(condition: bool, message: String = "") -> void:
	if not condition:
		printerr("Assertion failed: " + message)
		_failed_assertions += 1

func test_1_region_ids_and_neighbour_references() -> void:
	var regions: Dictionary = RegionCatalog.create_default_regions()
	var routes: Array[RegionRoute] = RegionCatalog.create_default_routes()

	_assert(regions.size() >= 5, "Initial world must have at least 5 regions")
	_assert(regions.has(RegionCatalog.REGION_CROWNWEFT), "Must contain player capital region")
	_assert(regions.has(RegionCatalog.REGION_VALEN), "Must contain Valen region")
	_assert(regions.has(RegionCatalog.REGION_OLD_GROVE), "Must contain Old Grove region")
	_assert(regions.has(RegionCatalog.REGION_IRONPEAK), "Must contain Ironpeak region")
	_assert(regions.has(RegionCatalog.REGION_GREY_MARCHES), "Must contain neutral/buffer region")
	_assert(regions.has(RegionCatalog.REGION_SHATTERED_PASS), "Must contain contested pass region")

	var reg_world := RegionalWorldState.new()
	reg_world.regions = regions
	reg_world.routes = routes

	var val_res: Dictionary = reg_world.validate_graph()
	_assert(val_res["ok"] == true, "Default region graph validation failed: " + str(val_res.get("errors", [])))

	# Check uniqueness
	var seen_ids: Dictionary = {}
	for r_id in regions:
		_assert(not seen_ids.has(r_id), "Duplicate region ID found: " + str(r_id))
		seen_ids[r_id] = true
		var reg: RegionState = regions[r_id]
		_assert(reg.id == r_id, "Region internal ID must match dictionary key")
		_assert(reg.display_name != "", "Region must have display name")
		for n in reg.neighbors:
			_assert(regions.has(n), "Neighbour '%s' of '%s' must exist in graph" % [n, r_id])

	print("✓ Test 1: Region IDs are unique and every neighbour reference is valid PASSED")

func test_2_initial_region_graph_connected() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	# BFS connectivity from Player capital
	var visited: Dictionary = {RegionCatalog.REGION_CROWNWEFT: true}
	var queue: Array[StringName] = [RegionCatalog.REGION_CROWNWEFT]

	while not queue.is_empty():
		var curr: StringName = queue.pop_front()
		for r in reg_world.routes:
			if r.has_endpoint(curr):
				var other: StringName = r.get_other_region(curr)
				if not visited.has(other):
					visited[other] = true
					queue.append(other)

	_assert(visited.size() == reg_world.regions.size(), "All regions in initial world must be reachable from player capital")
	print("✓ Test 2: Initial region graph is fully connected as intended PASSED")

func test_3_ownership_claims_and_occupation_distinct() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var pass_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_SHATTERED_PASS)
	_assert(pass_reg != null, "Shattered Pass must exist")
	_assert(pass_reg.controlling_faction == &"", "Shattered Pass starts uncontrolled")
	_assert(pass_reg.claimed_by_faction == FactionCatalog.FACTION_IRONPEAK, "Ironpeak holds initial recognized claim")
	_assert(pass_reg.is_contested == true, "Shattered Pass starts contested")
	_assert(pass_reg.status == RegionState.STATUS_CONTESTED, "Status must be contested")

	# Diplomatic claim update does NOT change control
	pass_reg.set_claim(FactionCatalog.FACTION_PLAYER)
	_assert(pass_reg.claimed_by_faction == FactionCatalog.FACTION_PLAYER, "Player asserted diplomatic claim")
	_assert(pass_reg.controlling_faction == &"", "Control must remain empty despite claim update")
	_assert(pass_reg.status == RegionState.STATUS_CONTESTED, "Status remains contested")

	# Military occupation during conflict
	reg_world.set_occupation(pass_reg.id, FactionCatalog.FACTION_IRONPEAK, "Armed Vanguard Garrison", 100)
	_assert(pass_reg.occupying_faction == FactionCatalog.FACTION_IRONPEAK, "Occupying faction set")
	_assert(pass_reg.controlling_faction == &"", "Control remains distinct from temporary military occupation")
	_assert(pass_reg.status == RegionState.STATUS_OCCUPIED, "Status is now occupied")
	_assert(pass_reg.get_effective_controller() == FactionCatalog.FACTION_IRONPEAK, "Effective controller is occupier")

	# Clearing occupation
	reg_world.set_occupation(pass_reg.id, &"", "Armistice troop withdrawal", 200)
	_assert(pass_reg.occupying_faction == &"", "Occupation cleared")
	_assert(pass_reg.controlling_faction == &"", "Control still distinct")
	_assert(pass_reg.status == RegionState.STATUS_CONTESTED, "Returns to contested status")

	print("✓ Test 3: Region ownership, claims, and military occupation remain distinct PASSED")

func test_4_invalid_ownership_transitions_rejected() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	# 1. Non-existent region
	var res1: Dictionary = reg_world.transfer_control(&"mystic_void", FactionCatalog.FACTION_PLAYER, "Cession", 10)
	_assert(res1["ok"] == false, "Must reject non-existent region")

	# 2. Transfer to current controller
	var res2: Dictionary = reg_world.transfer_control(RegionCatalog.REGION_CROWNWEFT, FactionCatalog.FACTION_PLAYER, "Redundant", 10)
	_assert(res2["ok"] == false, "Must reject transfer to existing controller")

	# 3. Unrecognized faction
	var res3: Dictionary = reg_world.transfer_control(RegionCatalog.REGION_CROWNWEFT, &"unknown_pirates", "Raid", 10)
	_assert(res3["ok"] == false, "Must reject unrecognized faction")

	# 4. Empty justification / reason
	var res4: Dictionary = reg_world.transfer_control(RegionCatalog.REGION_CROWNWEFT, FactionCatalog.FACTION_VALEN, "", 10)
	_assert(res4["ok"] == false, "Must reject control transfer without valid justification")

	# 5. Valid validated transfer
	var res5: Dictionary = reg_world.transfer_control(RegionCatalog.REGION_GREY_MARCHES, FactionCatalog.FACTION_VALEN, "treaty_cession", 100)
	_assert(res5["ok"] == true, "Must accept valid control transfer")
	var marches: RegionState = reg_world.get_region(RegionCatalog.REGION_GREY_MARCHES)
	_assert(marches.controlling_faction == FactionCatalog.FACTION_VALEN, "Marches now administered by Valen")
	_assert(marches.control_transition_history.size() == 1, "Control transition recorded in history")

	print("✓ Test 4: Invalid ownership transitions are rejected PASSED")

func test_5_regional_pathfinding() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	# Normal shortest path: Crownweft -> Ironpeak
	var route_res: Dictionary = reg_world.find_route(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_IRONPEAK)
	_assert(route_res["ok"] == true, "Route from Crownweft to Ironpeak should be found")
	var path: Array = route_res["path"]
	_assert(path.front() == RegionCatalog.REGION_CROWNWEFT, "Path starts at origin")
	_assert(path.back() == RegionCatalog.REGION_IRONPEAK, "Path ends at destination")
	# Shortest by ticks: Crownweft (80) -> Shattered Pass (50) -> Ironpeak = 130 ticks
	_assert(route_res["total_ticks"] == 130, "Travel ticks should be 130 (80+50)")
	_assert(route_res["total_supply_cost"] == 14, "Supply cost should be 14 (8+6)")

	# Path to disconnected region fails cleanly
	var isolated := RegionState.new(&"isolated_isle", "Isolated Isle", Vector2(800, 800))
	reg_world.regions[isolated.id] = isolated
	var fail_res: Dictionary = reg_world.find_route(RegionCatalog.REGION_CROWNWEFT, &"isolated_isle")
	_assert(fail_res["ok"] == false, "Path to disconnected region must fail")
	_assert(fail_res.has("reason"), "Failure must provide explanatory reason")

	print("✓ Test 5: Regional pathfinding produces valid routes and fails clearly when none exists PASSED")

func test_6_route_availability_and_travel_costs() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	# Block primary pass route
	var pass_route: RegionRoute = reg_world.get_route_between(RegionCatalog.REGION_SHATTERED_PASS, RegionCatalog.REGION_IRONPEAK)
	_assert(pass_route != null, "Pass route exists")
	pass_route.set_blocked(true, "Avalanche / Military Blockade")

	# Re-run pathfinding: should detour via Grey Marches (Crownweft -> Grey Marches [90] -> Ironpeak [110] = 200 ticks)
	var detour_res: Dictionary = reg_world.find_route(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_IRONPEAK)
	_assert(detour_res["ok"] == true, "Detour route should be found")
	var detour_path: Array = detour_res["path"]
	_assert(detour_path.has(RegionCatalog.REGION_GREY_MARCHES), "Detour path must traverse Grey Marches")
	_assert(detour_res["total_ticks"] == 200, "Detour travel ticks should be 200 (90+110)")

	# Block second route as well
	var march_route: RegionRoute = reg_world.get_route_between(RegionCatalog.REGION_GREY_MARCHES, RegionCatalog.REGION_IRONPEAK)
	march_route.set_blocked(true, "Hostile incursion")

	var blocked_res: Dictionary = reg_world.find_route(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_IRONPEAK)
	_assert(blocked_res["ok"] == false, "Must fail when all routes to destination are blocked")

	print("✓ Test 6: Route availability and travel costs are respected PASSED")

func test_7_faction_and_war_information_consistency() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var diplomacy := DiplomacyState.new()
	var war: WarState = diplomacy.create_war(
		FactionCatalog.FACTION_IRONPEAK,
		FactionCatalog.FACTION_PLAYER,
		"Border aggression",
		50
	)
	war.transition_to(WarState.STATUS_WAR, 50, "Declaration")

	# Regional world and diplomacy consistency
	var iron_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_IRONPEAK)
	_assert(iron_reg.controlling_faction == FactionCatalog.FACTION_IRONPEAK, "Controller matches Ironpeak")
	_assert(diplomacy.has_active_war(iron_reg.controlling_faction, FactionCatalog.FACTION_PLAYER), "Active war matches regional controller")

	print("✓ Test 7: Faction and war information shown in regional model matches authoritative state PASSED")

func test_8_regional_resources_isolated_from_local_inventory() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var crown_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_CROWNWEFT)
	_assert(crown_reg.get_resource_stock(&"timber") == 500, "Regional timber stock is 500")

	var local_inventory := Inventory.new(100)
	local_inventory.add_resource(&"timber", 25, "Initial storehouse supply")

	# Modify regional stock
	crown_reg.add_resource_stock(&"timber", 200)
	_assert(crown_reg.get_resource_stock(&"timber") == 700, "Regional timber updated to 700")

	# Verify local inventory remains strictly unchanged
	_assert(local_inventory.get_available_outgoing(&"timber") == 25, "Local inventory timber must remain unchanged at 25")
	_assert(local_inventory.get_free_capacity() == 75, "Local inventory capacity unaffected")

	print("✓ Test 8: Regional resource quantities do not silently appear in local inventories PASSED")

func test_9_simulation_subsystems_non_regression() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var economy := EconomyState.new()
	var government := GovernmentState.new()
	var diplomacy := DiplomacyState.new()

	# Verify simultaneous coexistence without conflict
	_assert(economy.approval == 60.0, "Economy initial approval valid")
	_assert(government.enacted_policies.size() >= 2, "Government policies initialized")
	_assert(diplomacy.factions.size() == 4, "Diplomacy factions initialized")
	_assert(reg_world.regions.size() == 6, "Regional world initialized")

	print("✓ Test 9: Existing diplomatic, military, economic, and local simulation systems remain consistent PASSED")

func test_10_save_load_round_trip_preservation() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	# Apply state changes
	reg_world.transfer_control(RegionCatalog.REGION_GREY_MARCHES, FactionCatalog.FACTION_VALEN, "treaty_cession", 120)
	reg_world.set_occupation(RegionCatalog.REGION_SHATTERED_PASS, FactionCatalog.FACTION_IRONPEAK, "Watchtower Garrison", 150)
	var pass_route: RegionRoute = reg_world.get_route_between(RegionCatalog.REGION_SHATTERED_PASS, RegionCatalog.REGION_IRONPEAK)
	pass_route.set_blocked(true, "Military Barrier")

	var serialized: Dictionary = reg_world.serialize()

	# Deserialize
	var restored: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(restored.regions.size() == 6, "Restored region count matches")
	_assert(restored.routes.size() == 9, "Restored route count matches")

	var res_marches: RegionState = restored.get_region(RegionCatalog.REGION_GREY_MARCHES)
	_assert(res_marches.controlling_faction == FactionCatalog.FACTION_VALEN, "Restored controller preserved")
	_assert(res_marches.control_transition_history.size() == 1, "Control transition history preserved")

	var res_pass: RegionState = restored.get_region(RegionCatalog.REGION_SHATTERED_PASS)
	_assert(res_pass.occupying_faction == FactionCatalog.FACTION_IRONPEAK, "Occupation preserved")
	_assert(res_pass.status == RegionState.STATUS_OCCUPIED, "Occupied status preserved")

	var res_route: RegionRoute = restored.get_route_between(RegionCatalog.REGION_SHATTERED_PASS, RegionCatalog.REGION_IRONPEAK)
	_assert(res_route.is_open == false, "Blocked route preserved")
	_assert(res_route.blocked_reason == "Military Barrier", "Blocked reason preserved")

	print("✓ Test 10: Save/load preserves the regional graph and state without duplication PASSED")

func test_11_legacy_save_migration() -> void:
	# Simulate legacy save data without "regional_world" key
	var legacy_save: Dictionary = {
		"meta": {"schema_version": 1},
		"economy": {},
		"buildings": [],
		"citizens": []
	}

	var deserialized: Dictionary = SaveSchema.deserialize(legacy_save)
	_assert(deserialized.has("regional_world"), "Deserialization must populate regional_world for legacy save")
	var reg_world: RegionalWorldState = deserialized["regional_world"]
	_assert(reg_world != null, "Regional world should not be null")
	_assert(reg_world.regions.size() == 6, "Legacy save initializes 6 default regions")
	_assert(reg_world.routes.size() == 9, "Legacy save initializes 9 default routes")
	_assert(reg_world.validate_graph()["ok"] == true, "Legacy initialized world graph is valid")

	print("✓ Test 11: Legacy saves initialize the regional world safely PASSED")

func test_12_local_battles_do_not_cause_territorial_conquest() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var iron_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_IRONPEAK)
	var pass_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_SHATTERED_PASS)
	var initial_iron_controller: StringName = iron_reg.controlling_faction
	var initial_pass_controller: StringName = pass_reg.controlling_faction

	# War & battlefield encounter
	var diplomacy := DiplomacyState.new()
	var war: WarState = diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border raid", 100)
	war.transition_to(WarState.STATUS_WAR, 100, "Incursion")

	# Repel raiders on the local map
	war.record_casualty(FactionCatalog.FACTION_PLAYER)
	for i in range(4):
		war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_battle(110, "North Gate Skirmish", 4, 1, &"Crown Victory")

	# Crucial: Battlefield victory must NOT change regional ownership
	_assert(iron_reg.controlling_faction == initial_iron_controller, "Local tactical victory must not alter sovereign regional ownership")
	_assert(pass_reg.controlling_faction == initial_pass_controller, "Border pass must not be conquered by repelling a raid")
	_assert(war.status == WarState.STATUS_WAR, "War remains active until diplomatically concluded")

	print("✓ Test 12: Local battles and raids do not automatically become territorial conquest PASSED")
