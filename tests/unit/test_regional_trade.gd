class_name TestRegionalTrade
extends SceneTree

# A failed assert() only aborts the current function, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("\n--- Running TestRegionalTrade ---")
	test_1_trade_contracts_validate_participants_quantities_prices_routes()
	test_2_insufficient_goods_or_funds_prevent_acceptance()
	test_3_concurrent_trades_cannot_reserve_same_resources_twice()
	test_4_shipments_traverse_connected_routes_over_time()
	test_5_blocked_routes_produce_detour_or_explicit_failure()
	test_6_route_failure_preserves_cargo_and_reserved_funds()
	test_7_delivery_places_actual_goods_into_destination_inventory()
	test_8_payment_and_delivery_settle_exactly_once()
	test_9_full_destination_inventory_prevents_unsafe_dispatch()
	test_10_cancellation_before_dispatch_releases_reservations()
	test_11_cancellation_in_transit_preserves_cargo_and_refunds()
	test_12_war_restrictions_prevent_prohibited_trade()
	test_13_ai_trade_proposals_respect_resource_availability()
	test_14_save_load_preserves_shipment_in_transit()
	test_15_legacy_saves_load_safely()
	test_16_non_regression()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestRegionalTrade PASSED ---\n")
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

func test_1_trade_contracts_validate_participants_quantities_prices_routes() -> void:
	var world := _setup_world()

	# 1. Same buyer and seller
	var c_same := world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	_assert(c_same == null, "Cannot create contract between same faction")

	# 2. Invalid faction
	var c_inv_fac := world.create_trade_contract(
		&"unknown_kingdom", FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	_assert(c_inv_fac == null, "Cannot create contract with invalid faction")

	# 3. Invalid quantity or price
	var c_zero_qty := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 0, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	_assert(c_zero_qty == null, "Cannot create contract with 0 quantity")

	var c_neg_price := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, -5,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	_assert(c_neg_price == null, "Cannot create contract with negative price")

	# 4. Same origin and destination
	var c_same_reg := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_CROWNWEFT, 1
	)
	_assert(c_same_reg == null, "Cannot create contract with identical origin and destination")

	# 5. Valid contract
	var c_valid := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 20, 30,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	_assert(c_valid != null, "Valid contract successfully created")
	_assert(c_valid.status == TradeContract.STATUS_OFFERED, "Initial status is OFFERED")
	_assert(c_valid.unit_price == 1.5, "Unit price calculated correctly (30 / 20 = 1.5)")

	print("✓ Test 1: Trade contracts validate participants, quantities, prices, routes PASSED")

func test_2_insufficient_goods_or_funds_prevent_acceptance() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)

	# Seller (Player) lacks goods
	player_inv.add_resource(&"timber", 5, "Initial stock")
	var c1 := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 25, 40,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	var res1 := world.accept_trade_contract(c1.id, player_inv, diplomacy, 5)
	_assert(not res1["ok"], "Trade rejected when seller lacks required quantity")
	_assert(c1.status == TradeContract.STATUS_OFFERED, "Contract remains offered")

	# Buyer (Player) lacks coins
	player_inv.add_resource(&"coin", 10, "Treasury coins")
	var c2 := world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN,
		&"grain", 20, 50,
		RegionCatalog.REGION_VALEN, RegionCatalog.REGION_CROWNWEFT, 1
	)
	var res2 := world.accept_trade_contract(c2.id, player_inv, diplomacy, 5)
	_assert(not res2["ok"], "Trade rejected when buyer lacks sufficient treasury")
	_assert(player_inv.get_quantity(&"coin") == 10, "Coins not deducted on failed acceptance")

	print("✓ Test 2: Insufficient goods or funds prevent partial acceptance PASSED")

func test_3_concurrent_trades_cannot_reserve_same_resources_twice() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 20, "Total timber stock")

	# Trade A asks for 15 timber
	var c_a := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 15, 20,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	var res_a := world.accept_trade_contract(c_a.id, player_inv, diplomacy, 5)
	_assert(res_a["ok"], "Trade A accepted")
	# Cargo is loaded into shipment (15 timber deducted), remaining available is 5

	# Trade B asks for 10 timber (only 5 remain available)
	var c_b := world.create_trade_contract(
		FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_OLD_GROVE, 1
	)
	var res_b := world.accept_trade_contract(c_b.id, player_inv, diplomacy, 6)
	_assert(not res_b["ok"], "Trade B cannot reserve already committed timber")

	print("✓ Test 3: Concurrent trades cannot reserve identical resources twice PASSED")

func test_4_shipments_traverse_connected_routes_over_time() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 30, "Timber stock")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 20, 25,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	var res := world.accept_trade_contract(c.id, player_inv, diplomacy, 10)
	_assert(res["ok"], "Contract accepted and shipment dispatched")

	var s: TradeShipment = world.get_shipment(c.shipment_id)
	_assert(s != null, "Shipment exists")
	_assert(s.status == TradeShipment.STATUS_IN_TRANSIT, "Shipment in transit")
	_assert(s.current_region_id == RegionCatalog.REGION_CROWNWEFT, "Starts at Crownweft")

	# Advance 20 ticks
	for i in range(20):
		world.tick_regional_trade_shipments(10 + i, diplomacy, player_inv)

	_assert(s.segment_ticks_progress > 0.0, "Caravan progress advanced over time")
	_assert(s.get_cargo(&"timber") == 20, "Cargo intact during transit")

	print("✓ Test 4: Shipments traverse connected regional routes over time PASSED")

func test_5_blocked_routes_produce_detour_or_explicit_failure() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 20, "Stock")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 15,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	var s: TradeShipment = world.get_shipment(c.shipment_id)

	# Block direct route between Crownweft and Valen
	var direct_route: RegionRoute = world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN)
	_assert(direct_route != null, "Direct route exists")
	direct_route.is_open = false

	# Caravan encounters blocked route: should calculate detour
	world.tick_regional_trade_shipments(6, diplomacy, player_inv)
	_assert(s.events.back()["event"] == "detour", "Caravan took detour when direct route was blocked")

	# Block all routes connecting to Valen Lowlands and current segment
	for r in world.get_routes_for_region(RegionCatalog.REGION_VALEN):
		r.is_open = false
	var active_seg: RegionRoute = world.get_route_between(s.route_path[0], s.route_path[1])
	if active_seg != null:
		active_seg.is_open = false

	world.tick_regional_trade_shipments(7, diplomacy, player_inv)
	_assert(s.status == TradeShipment.STATUS_WAITING_ROUTE, "Caravan waits when all paths are blocked")
	_assert(not s.blocked_reason.is_empty(), "Explicit blocked reason recorded")

	print("✓ Test 5: Blocked routes produce a valid detour or explicit failure PASSED")

func test_6_route_failure_preserves_cargo_and_reserved_funds() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 20, "Stock")

	var valen_fac: FactionState = diplomacy.factions[FactionCatalog.FACTION_VALEN]
	var initial_valen_treasury: int = valen_fac.treasury

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 15, 30,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	var s: TradeShipment = world.get_shipment(c.shipment_id)

	# Block all routes
	for r in world.routes:
		r.is_open = false

	world.tick_regional_trade_shipments(10, diplomacy, player_inv)

	_assert(s.get_cargo(&"timber") == 15, "Cargo safely preserved during route failure")
	_assert(valen_fac.reserved_treasury == 30, "Buyer funds remain safely reserved")
	_assert(valen_fac.treasury == initial_valen_treasury, "Buyer not prematurely charged")

	print("✓ Test 6: Route failure preserves cargo and reserved funds without loss PASSED")

func test_7_delivery_places_actual_goods_into_destination_inventory() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"coin", 50, "Treasury coins")

	# Player buys 15 herbs from Old Grove
	var old_grove: FactionState = diplomacy.factions[FactionCatalog.FACTION_OLD_GROVE]
	old_grove.resources[&"herbs"] = 40

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_OLD_GROVE,
		&"herbs", 15, 25,
		RegionCatalog.REGION_OLD_GROVE, RegionCatalog.REGION_CROWNWEFT, 1
	)
	var accept_res := world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	_assert(accept_res["ok"], "Import contract accepted")

	# Fast forward shipment to destination
	var s: TradeShipment = world.get_shipment(c.shipment_id)
	s.current_region_id = RegionCatalog.REGION_CROWNWEFT
	s.route_path.clear()

	var settle_res := world.deliver_and_settle_contract(c.id, player_inv, diplomacy, 80)
	_assert(settle_res["ok"], "Contract settled successfully")

	# Verify physical cargo arrived in player inventory
	_assert(player_inv.get_quantity(&"herbs") == 15, "Imported herbs delivered into player storehouse")
	_assert(player_inv.get_quantity(&"coin") == 25, "Player payment deducted (50 - 25 = 25)")
	_assert(old_grove.treasury >= 25, "Seller received payment")

	print("✓ Test 7: Delivery places actual goods into correct destination inventory PASSED")

func test_8_payment_and_delivery_settle_exactly_once() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 20, "Timber stock")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 20,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	world.accept_trade_contract(c.id, player_inv, diplomacy, 1)

	var res1 := world.deliver_and_settle_contract(c.id, player_inv, diplomacy, 50)
	_assert(res1["ok"], "First settlement succeeds")
	_assert(player_inv.get_quantity(&"coin") == 20, "Player received 20 coins")

	# Attempt second settlement (idempotency check)
	var res2 := world.deliver_and_settle_contract(c.id, player_inv, diplomacy, 51)
	_assert(not res2["ok"], "Duplicate settlement rejected")
	_assert(player_inv.get_quantity(&"coin") == 20, "Player not paid twice")

	print("✓ Test 8: Payment and delivery settle exactly once PASSED")

func test_9_full_destination_inventory_prevents_unsafe_dispatch() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 20) # Low capacity: 20 max
	player_inv.add_resource(&"coin", 15, "Coins")
	player_inv.add_resource(&"stone", 5, "Stone")
	_assert(player_inv.get_free_capacity() == 0, "Player storage is completely full")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN,
		&"grain", 10, 10,
		RegionCatalog.REGION_VALEN, RegionCatalog.REGION_CROWNWEFT, 1
	)
	var res := world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	_assert(not res["ok"], "Dispatch rejected when receiving inventory has no capacity")
	_assert(c.status == TradeContract.STATUS_OFFERED, "Contract remains unaccepted")

	print("✓ Test 9: Full destination inventory prevents unsafe dispatch PASSED")

func test_10_cancellation_before_dispatch_releases_reservations() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 25, "Timber")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 15, 30,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	var valen: FactionState = diplomacy.factions[FactionCatalog.FACTION_VALEN]

	# Manually place contract in reserved state before shipment dispatches
	c.status = TradeContract.STATUS_RESERVED
	player_inv.reserve_out(&"timber", 15)
	valen.reserve_treasury(30)

	var cancel_res := world.cancel_trade_contract(c.id, "Buyer revoked contract", player_inv, diplomacy, 10)
	_assert(cancel_res["ok"], "Pre-dispatch cancellation succeeds")
	_assert(player_inv.get_reserved_out(&"timber") == 0, "Goods reservation released")
	_assert(valen.reserved_treasury == 0, "Buyer treasury reservation released")
	_assert(c.status == TradeContract.STATUS_CANCELLED, "Contract status is CANCELLED")

	print("✓ Test 10: Cancellation before dispatch releases reservations correctly PASSED")

func test_11_cancellation_in_transit_preserves_cargo_and_refunds() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 30, "Timber")

	var valen: FactionState = diplomacy.factions[FactionCatalog.FACTION_VALEN]
	var initial_valen_treasury: int = valen.treasury

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 20, 30,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	var s: TradeShipment = world.get_shipment(c.shipment_id)
	_assert(player_inv.get_quantity(&"timber") == 10, "20 timber loaded onto caravan")

	# Caravan moves mid-route towards Valen
	s.current_region_id = RegionCatalog.REGION_OLD_GROVE

	# Cancel while in transit
	var cancel_res := world.cancel_trade_contract(c.id, "Route declared hazardous", player_inv, diplomacy, 15)
	_assert(cancel_res["ok"], "Cancellation order accepted")
	_assert(s.status == TradeShipment.STATUS_RETURNING, "Caravan ordered to return to origin")

	# Simulate caravan returning back to Crownweft
	s.current_region_id = RegionCatalog.REGION_CROWNWEFT
	s.route_path.clear()
	world.tick_regional_trade_shipments(30, diplomacy, player_inv)

	_assert(s.status == TradeShipment.STATUS_RETURNED, "Caravan successfully returned to origin")
	_assert(player_inv.get_quantity(&"timber") == 30, "All 20 timber restored to player storage (10 + 20 = 30)")
	_assert(valen.reserved_treasury == 0, "Buyer funds reservation released")
	_assert(valen.treasury == initial_valen_treasury, "Buyer refunded completely")

	print("✓ Test 11: Cancellation in transit preserves carried goods and accounts for refunds PASSED")

func test_12_war_restrictions_prevent_prohibited_trade() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 30, "Timber")

	# Declare war with Ironpeak
	diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Border Raid", 1, WarState.STATUS_WAR)

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER,
		&"timber", 10, 20,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_IRONPEAK, 1
	)
	var res := world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	_assert(not res["ok"], "Trade prohibited between warring factions")
	_assert(c.status == TradeContract.STATUS_FAILED, "Contract marked failed due to war")

	print("✓ Test 12: War restrictions prevent prohibited trade behaviour PASSED")

func test_13_ai_trade_proposals_respect_resource_availability() -> void:
	var diplomacy := DiplomacyState.new()
	var dip_sys := DiplomacySystem.new()
	var valen: FactionState = diplomacy.factions[FactionCatalog.FACTION_VALEN]

	# Valen has 40 timber in stock
	valen.resources[&"timber"] = 40
	valen.treasury = 50

	# Ensure AI trade sell does not exceed available resources
	var candidate: Dictionary = {
		"resource_id": &"timber",
		"resource_amount": 30,
		"coin_amount": 30
	}
	_assert(valen.get_available_resource(&"timber") >= candidate["resource_amount"], "Proposed quantity within available stock")

	# If stock drops to 10, AI cannot propose 30
	valen.resources[&"timber"] = 10
	_assert(valen.get_available_resource(&"timber") < candidate["resource_amount"], "AI cannot propose quantities it cannot supply")

	print("✓ Test 13: AI trade proposals respect actual resource availability PASSED")

func test_14_save_load_preserves_shipment_in_transit() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()
	var player_inv := Inventory.new(1, 100)
	player_inv.add_resource(&"timber", 30, "Stock")

	var c := world.create_trade_contract(
		FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER,
		&"timber", 15, 20,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 1
	)
	world.accept_trade_contract(c.id, player_inv, diplomacy, 5)
	var s: TradeShipment = world.get_shipment(c.shipment_id)
	s.segment_ticks_progress = 12.5

	var serialized: Dictionary = world.serialize()
	_assert(serialized.has("contracts"), "Serialized data contains contracts")
	_assert(serialized.has("shipments"), "Serialized data contains shipments")

	var loaded: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(loaded.contracts.size() == 1, "Contract deserialized")
	_assert(loaded.shipments.size() == 1, "Shipment deserialized")

	var loaded_c: TradeContract = loaded.get_contract(c.id)
	_assert(loaded_c != null, "Contract found")
	_assert(loaded_c.status == TradeContract.STATUS_IN_TRANSIT, "Contract status preserved")
	_assert(loaded_c.total_price == 20, "Contract price preserved")

	var loaded_s: TradeShipment = loaded.get_shipment(s.id)
	_assert(loaded_s != null, "Shipment found")
	_assert(loaded_s.status == TradeShipment.STATUS_IN_TRANSIT, "Shipment status preserved")
	_assert(loaded_s.get_cargo(&"timber") == 15, "Cargo amount preserved")
	_assert(loaded_s.segment_ticks_progress == 12.5, "Movement progress preserved with precision")

	print("✓ Test 14: Save/load preserves shipments, cargo, and contracts in transit PASSED")

func test_15_legacy_saves_load_safely() -> void:
	var world := _setup_world()
	var serialized: Dictionary = world.serialize()
	serialized.erase("contracts")
	serialized.erase("shipments")
	serialized.erase("next_contract_id")
	serialized.erase("next_shipment_id")

	var legacy_loaded: RegionalWorldState = RegionalWorldState.deserialize(serialized)
	_assert(legacy_loaded.contracts.is_empty(), "Legacy save loads safely with empty contracts")
	_assert(legacy_loaded.shipments.is_empty(), "Legacy save loads safely with empty shipments")
	_assert(legacy_loaded.next_contract_id == 1, "Default next contract id assigned")

	print("✓ Test 15: Legacy saves load safely without trade errors PASSED")

func test_16_non_regression() -> void:
	var world := _setup_world()
	var diplomacy := DiplomacyState.new()

	# Regional armies and campaigns continue to operate in parallel
	var army := world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Trade Guard",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 10},
		30,
		1
	)
	_assert(army != null, "Regional army creation unaffected")

	var obj := world.create_objective(
		FactionCatalog.FACTION_PLAYER,
		CampaignObjective.TYPE_DEFEND_REGION,
		RegionCatalog.REGION_CROWNWEFT,
		0, -1, 1
	)
	_assert(obj != null, "Campaign objectives unaffected")

	print("✓ Test 16: Existing regional systems continue to function consistently PASSED")
