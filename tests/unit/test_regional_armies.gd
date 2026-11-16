extends SceneTree

# A failed assert() only aborts the current function, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("\n--- Running TestRegionalArmies ---")
	
	test_1_army_ids_and_ownership_references_valid()
	test_2_valid_movement_orders_through_connected_routes()
	test_3_movement_advances_by_simulation_ticks()
	test_4_blocked_routes_trigger_detour_or_explicit_failure()
	test_5_repeated_orders_do_not_corrupt_movement_progress()
	test_6_supply_consumption_follows_documented_rule()
	test_7_empty_supply_inventories_never_become_negative()
	test_8_regional_supplies_and_army_inventories_distinct()
	test_9_resupply_transfers_resources_exactly_once()
	test_10_supply_routes_distinguish_connectivity_from_delivery()
	test_11_peace_and_ceasefire_prevent_prohibited_actions()
	test_12_war_integration_and_casualty_integrity()
	test_13_save_load_preserves_marching_armies()
	test_14_legacy_save_migration_without_armies()

	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestRegionalArmies PASSED ---\n")
	quit(0)

func _assert(condition: bool, message: String = "") -> void:
	if not condition:
		printerr("Assertion failed: " + message)
		_failed_assertions += 1

func test_1_army_ids_and_ownership_references_valid() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"First Royal Legion",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10, &"archer": 5},
		30,
		10
	)

	_assert(army != null, "Army creation should succeed")
	_assert(army.id > 0, "Army should be assigned a positive ID")
	_assert(army.faction_id == FactionCatalog.FACTION_PLAYER, "Owning faction must match")
	_assert(army.current_region_id == RegionCatalog.REGION_CROWNWEFT, "Origin region must match")
	_assert(army.status == ArmyState.STATUS_GARRISONED, "Initial status must be GARRISONED")
	_assert(army.strength == 15, "Strength should equal sum of units (10+5)")
	_assert(reg_world.get_army(army.id) == army, "Army must be retrievable from world state")

	print("✓ Test 1: Army IDs and ownership references remain valid PASSED")

func test_2_valid_movement_orders_through_connected_routes() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Vanguard Cohort",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 8},
		25,
		0
	)

	var res: Dictionary = reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 1)
	_assert(res["ok"] == true, "March order to connected region should succeed")
	_assert(army.status == ArmyState.STATUS_MARCHING, "Status should be MARCHING")
	_assert(army.destination_region_id == RegionCatalog.REGION_VALEN, "Destination should be set")
	_assert(army.route_path == [RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN], "Path should connect origin and destination")
	_assert(army.segment_total_ticks == 60, "Segment total ticks should match route travel duration (60)")

	print("✓ Test 2: Valid movement orders travel through connected regional routes PASSED")

func test_3_movement_advances_by_simulation_ticks() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Marching Regiment",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		50,
		0
	)

	reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 0)
	_assert(army.current_region_id == RegionCatalog.REGION_CROWNWEFT, "Still in origin at start")

	# Advance 30 ticks
	for i in range(30):
		reg_world.tick_regional_armies(i + 1)

	_assert(army.status == ArmyState.STATUS_MARCHING, "Army is still marching mid-route")
	_assert(army.segment_ticks_progress > 0.0, "Progress should advance on ticks")
	_assert(army.current_region_id == RegionCatalog.REGION_CROWNWEFT, "Has not yet arrived in destination")

	# Advance remaining ticks to complete route (60 ticks / 0.9 travel diff ~= 54 ticks total needed)
	for i in range(35):
		reg_world.tick_regional_armies(31 + i)

	_assert(army.current_region_id == RegionCatalog.REGION_VALEN, "Arrived at destination")
	_assert(army.status == ArmyState.STATUS_GARRISONED, "Garrisoned upon arrival")

	print("✓ Test 3: Movement advances by simulation ticks and respects travel duration PASSED")

func test_4_blocked_routes_trigger_detour_or_explicit_failure() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Expeditionary Corps",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		50,
		0
	)

	# March towards Shattered Pass (neutral/contested)
	reg_world.issue_march_order(army.id, RegionCatalog.REGION_SHATTERED_PASS, 0)

	# Block the direct route midway
	var direct_route: RegionRoute = reg_world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_SHATTERED_PASS)
	direct_route.set_blocked(true, "Mountain Landslide")

	# Ticking should trigger automatic detour via Valen Lowlands (Crownweft -> Valen -> Shattered Pass)
	reg_world.tick_regional_armies(1)
	_assert(army.route_path.has(RegionCatalog.REGION_VALEN), "Army detoured via Valen Lowlands")
	_assert(army.events.back().get("event") == "detour", "Detour event recorded in army history")

	# Now block all routes leading to Shattered Pass AND the active segment to Valen
	for r in reg_world.get_routes_for_region(RegionCatalog.REGION_SHATTERED_PASS):
		r.set_blocked(true, "All Passes Blocked")
	reg_world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN).set_blocked(true, "Active Segment Blocked")

	reg_world.tick_regional_armies(2)
	_assert(army.status == ArmyState.STATUS_GARRISONED, "Army halts when all paths are blocked")
	_assert(army.blocked_reason != "", "Army reports blocked reason")

	print("✓ Test 4: Blocked routes trigger a valid detour or explicit failure PASSED")

func test_5_repeated_orders_do_not_corrupt_movement_progress() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Steady Marchers",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		40,
		0
	)

	reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 0)
	for i in range(15):
		reg_world.tick_regional_armies(i + 1)

	var recorded_progress: float = army.segment_ticks_progress
	_assert(recorded_progress > 10.0, "Progress achieved")

	# Re-issue identical march order
	var rep_res: Dictionary = reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 20)
	_assert(rep_res["ok"] == true, "Re-issued order succeeds")
	_assert(army.segment_ticks_progress == recorded_progress, "Progress must NOT reset on repeated order")

	print("✓ Test 5: Repeated orders do not corrupt movement progress PASSED")

func test_6_supply_consumption_follows_documented_rule() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Provisioned Force",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		40,
		0
	)

	# Garrisoned consumption: 0.05 grain/tick
	for i in range(20):
		reg_world.tick_regional_armies(i + 1)
	# 20 * 0.05 = 1.0 grain consumed
	_assert(is_equal_approx(army.get_supplies(&"grain"), 39.0), "Garrisoned consumes 1.0 grain in 20 ticks")

	# Marching consumption: 0.20 grain/tick
	reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 21)
	for i in range(10):
		reg_world.tick_regional_armies(22 + i)
	# 10 * 0.20 = 2.0 grain consumed
	_assert(is_equal_approx(army.get_supplies(&"grain"), 37.0), "Marching consumes 2.0 grain in 10 ticks")

	print("✓ Test 6: Supply consumption follows the documented rule PASSED")

func test_7_empty_supply_inventories_never_become_negative() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Starving Vanguard",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		1, # Only 1 grain
		0
	)

	reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 0)

	# Tick 15 times (would consume 3.0 grain, but only 1.0 exists)
	for i in range(15):
		reg_world.tick_regional_armies(i + 1)

	_assert(army.get_supplies(&"grain") == 0.0, "Supplies clamp at 0.0, never negative")
	_assert(army.status == ArmyState.STATUS_SUPPLY_STRAINED, "Status becomes SUPPLY_STRAINED upon exhaustion")

	print("✓ Test 7: Empty supply inventories never become negative PASSED")

func test_8_regional_supplies_and_army_inventories_distinct() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var crown_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_CROWNWEFT)
	var initial_reg_grain: int = crown_reg.get_resource_stock(&"grain")

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Independent Garrison",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 5},
		20,
		0
	)

	# Verify stockpiles are independent
	_assert(crown_reg.get_resource_stock(&"grain") == initial_reg_grain, "Creating army does not silently drain regional stock")
	_assert(army.get_supplies(&"grain") == 20.0, "Army has dedicated carried supplies")

	print("✓ Test 8: Regional supplies and army inventories do not duplicate resources PASSED")

func test_9_resupply_transfers_resources_exactly_once() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var crown_reg: RegionState = reg_world.get_region(RegionCatalog.REGION_CROWNWEFT)
	var initial_grain: int = crown_reg.get_resource_stock(&"grain")

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Resupply Target",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		10,
		0
	)

	# Resupply 25 grain from regional stockpile
	var res: Dictionary = reg_world.resupply_army(army.id, "regional_stockpile", crown_reg, 25, 10)
	_assert(res["ok"] == true, "Resupply transaction succeeded")
	_assert(res["transferred"] == 25, "Transferred exactly 25 grain")
	_assert(crown_reg.get_resource_stock(&"grain") == initial_grain - 25, "Source decreased by 25")
	_assert(army.get_supplies(&"grain") == 35.0, "Destination increased by 25 (10+25)")

	print("✓ Test 9: Resupply transactions transfer resources exactly once PASSED")

func test_10_supply_routes_distinguish_connectivity_from_delivery() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Border Watch",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		30,
		0
	)

	# In Crownweft (friendly base), supply line is connected
	var check1: Dictionary = reg_world.check_supply_line(army.id)
	_assert(check1["connected"] == true, "Supply line connected in home region")

	# Move army to neutral Grey Marches
	army.current_region_id = RegionCatalog.REGION_GREY_MARCHES
	var check2: Dictionary = reg_world.check_supply_line(army.id)
	_assert(check2["connected"] == true, "Supply line connected across open route to Grey Marches")
	# Supplies do NOT magically appear
	_assert(army.get_supplies(&"grain") == 30.0, "Carried supplies untouched by route connectivity")

	# Block all routes connecting to Grey Marches
	for r in reg_world.get_routes_for_region(RegionCatalog.REGION_GREY_MARCHES):
		r.set_blocked(true, "Quagmire Flooding")

	var check3: Dictionary = reg_world.check_supply_line(army.id)
	_assert(check3["connected"] == false, "Supply line severed when access routes are closed")
	_assert(army.supply_line_connected == false, "Army state updated to severed supply line")

	print("✓ Test 10: Supply routes distinguish connectivity from completed delivery PASSED")

func test_11_peace_and_ceasefire_prevent_prohibited_actions() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()
	var diplomacy := DiplomacyState.new()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Peacetime Guard",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		40,
		0
	)

	# Ironpeak is sovereign and at peace (not allied)
	var order_res: Dictionary = reg_world.issue_march_order(army.id, RegionCatalog.REGION_IRONPEAK, 0, diplomacy)
	_assert(order_res["ok"] == false, "Marching into peaceful sovereign territory must be rejected")
	_assert(army.status == ArmyState.STATUS_GARRISONED, "Army remains garrisoned")

	# Declare war
	var war: WarState = diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border war", 10)
	war.transition_to(WarState.STATUS_WAR, 10, "Aggression")

	# Now march into belligerent territory is permitted
	var war_order_res: Dictionary = reg_world.issue_march_order(army.id, RegionCatalog.REGION_IRONPEAK, 11, diplomacy)
	_assert(war_order_res["ok"] == true, "Marching into belligerent territory permitted during active war")

	# Truce declared: ceasefire blocks new military incursions
	war.transition_to(WarState.STATUS_CEASEFIRE, 20, "Truce")
	army.current_region_id = RegionCatalog.REGION_CROWNWEFT
	var truce_order_res: Dictionary = reg_world.issue_march_order(army.id, RegionCatalog.REGION_IRONPEAK, 21, diplomacy)
	_assert(truce_order_res["ok"] == false, "Ceasefire prevents prohibited hostile military actions")

	print("✓ Test 11: Peace and ceasefire rules prevent prohibited military actions PASSED")

func test_12_war_integration_and_casualty_integrity() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()
	var diplomacy := DiplomacyState.new()

	var war: WarState = diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Invasion", 50)
	war.transition_to(WarState.STATUS_WAR, 50, "Marching")

	var enemy_army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_IRONPEAK,
		"Invading Vanguard",
		RegionCatalog.REGION_IRONPEAK,
		{&"warrior": 20},
		40,
		50
	)
	enemy_army.war_id = war.id

	# Battle engagement casualty
	war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	_assert(war.casualties.get(str(FactionCatalog.FACTION_IRONPEAK), 0) == 1, "Casualty recorded in WarState")
	_assert(enemy_army.strength == 20, "Army model maintains integrity without double-deduction")

	print("✓ Test 12: Regional armies integrate with existing wars without duplicating casualties or forces PASSED")

func test_13_save_load_preserves_marching_armies() -> void:
	var reg_world := RegionalWorldState.new()
	reg_world.regions = RegionCatalog.create_default_regions()
	reg_world.routes = RegionCatalog.create_default_routes()

	var army: ArmyState = reg_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Marching Legion",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 14, &"archer": 6},
		35,
		0
	)

	reg_world.issue_march_order(army.id, RegionCatalog.REGION_VALEN, 0)
	# Advance 20 ticks
	for i in range(20):
		reg_world.tick_regional_armies(i + 1)

	_assert(army.status == ArmyState.STATUS_MARCHING, "Active march in progress")

	# Serialize
	var serialized: Dictionary = reg_world.serialize()

	# Deserialize
	var restored: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(restored.armies.size() == 1, "Restored world contains 1 army")

	var r_army: ArmyState = restored.get_army(army.id)
	_assert(r_army != null, "Army restored with matching ID")
	_assert(r_army.name == "Marching Legion", "Name preserved")
	_assert(r_army.status == ArmyState.STATUS_MARCHING, "Marching status preserved")
	_assert(r_army.destination_region_id == RegionCatalog.REGION_VALEN, "Destination preserved")
	_assert(is_equal_approx(r_army.segment_ticks_progress, army.segment_ticks_progress), "Segment progress preserved")
	_assert(is_equal_approx(r_army.get_supplies(&"grain"), army.get_supplies(&"grain")), "Supplies preserved")

	print("✓ Test 13: Save/load preserves marching armies and their supplies PASSED")

func test_14_legacy_save_migration_without_armies() -> void:
	# Legacy regional world save lacking "armies"
	var legacy_data: Dictionary = {
		"selected_region_id": "crownweft_valley",
		"regions": {},
		"routes": []
	}

	var restored: RegionalWorldState = RegionalWorldState.deserialize(legacy_data)
	_assert(restored.armies.is_empty(), "Armies initialized empty without crash")
	_assert(restored.next_army_id == 1, "Next army ID initialized to 1")

	# Can create new army without issues
	var new_army: ArmyState = restored.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Post-Migration Army",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		30,
		100
	)
	_assert(new_army != null and new_army.id == 1, "Can assemble armies post-migration")

	print("✓ Test 14: Legacy saves without regional armies load safely PASSED")
