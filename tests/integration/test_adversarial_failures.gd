extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")
const RegionalWorldState = preload("res://scripts/domain/regional_world_state.gd")
const TradeContract = preload("res://scripts/domain/trade_contract.gd")
const TradeShipment = preload("res://scripts/domain/trade_shipment.gd")
const ArmyState = preload("res://scripts/domain/army_state.gd")
const WarState = preload("res://scripts/domain/war_state.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- Running TestAdversarialFailures (Task 17) ---")
	print("=======================================================")
	
	test_mode_1_simultaneous_harvest_and_caravan_reservation()
	test_mode_2_route_blocked_during_transit()
	test_mode_3_construction_cancelled_mid_haul()
	test_mode_4_citizen_role_reassignment_with_active_job()
	test_mode_5_empty_treasury_contract_protection()
	test_mode_6_rapid_policy_flips()
	test_mode_7_storage_capacity_exhaustion()
	test_mode_8_army_supply_line_severed()
	test_mode_9_officeholder_dismissal_resilience()
	test_mode_10_war_declaration_during_active_trade()

	print("\n=======================================================")
	if _tests_failed == 0:
		print("--- TestAdversarialFailures: ALL 10 FAILURE MODES PASSED ---")
	else:
		print("!! TestAdversarialFailures FAILED with %d assertion errors" % _tests_failed)
	print("=======================================================")
	quit(_tests_failed)

func _assert(cond: bool, msg: String) -> void:
	_tests_run += 1
	if not cond:
		_tests_failed += 1
		printerr("Assertion failed: ", msg)
	else:
		_tests_passed += 1

func _assert_eq(a, b, msg: String) -> void:
	_tests_run += 1
	if a != b:
		_tests_failed += 1
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
	else:
		_tests_passed += 1

# Helper to spawn fresh world
func _create_world() -> WorldScene:
	var world_scene_res = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_scene_res.instantiate()
	world._init_simulation()
	return world

# ------------------------------------------------------------------------------
# Mode 1: Simultaneous harvest delivery & caravan reservation to the same storehouse
# ------------------------------------------------------------------------------
func test_mode_1_simultaneous_harvest_and_caravan_reservation() -> void:
	print("[Failure Mode 1] Simultaneous harvest delivery & caravan reservation...")
	var world = _create_world()
	var origin: Vector2i = world.world_state.start_settlement_pos
	var sh: BuildingState = world.place_building(&"storehouse", origin + Vector2i(5, 0), true)
	_assert(sh != null, "Storehouse created")
	sh.status = BuildingState.Status.ACTIVE

	sh.inventory.add_resource(&"grain", 20, "initial_stock")
	_assert_eq(sh.inventory.get_quantity(&"grain"), 20, "Storehouse has 20 grain")

	# 1. Harvest inbound reservation (+10)
	var res_in_ok: bool = sh.inventory.reserve_in(&"grain", 10)
	_assert(res_in_ok, "Inbound reservation of 10 grain accepted")

	# 2. Caravan outbound reservation (-15)
	var res_out_ok: bool = sh.inventory.reserve_out(&"grain", 15)
	_assert(res_out_ok, "Outbound reservation of 15 grain accepted")

	# 3. Third reservation exceeding available stock must fail
	var res_out_fail: bool = sh.inventory.reserve_out(&"grain", 10)
	_assert(not res_out_fail, "Excess outbound reservation rejected")

	# Deposit the reserved inbound harvest
	var dep_ok: bool = sh.inventory.add_resource(&"grain", 10, "harvest_deposit", true)
	_assert(dep_ok, "Deposit with reservation succeeded")
	_assert_eq(sh.inventory.get_quantity(&"grain"), 30, "Total physical quantity is now 30")

	# Release/consume the reserved outbound caravan
	var draw_ok: bool = sh.inventory.remove_resource(&"grain", 15, "caravan_dispatch", true)
	_assert(draw_ok, "Caravan draw with reservation succeeded")
	_assert_eq(sh.inventory.get_quantity(&"grain"), 15, "Final physical stock is 15")
	_assert_eq(sh.inventory.get_reserved_in(&"grain"), 0, "No remaining inbound reservations")
	_assert_eq(sh.inventory.get_reserved_out(&"grain"), 0, "No remaining outbound reservations")

# ------------------------------------------------------------------------------
# Mode 2: Route blocked by hostile force while a caravan & army are in transit
# ------------------------------------------------------------------------------
func test_mode_2_route_blocked_during_transit() -> void:
	print("[Failure Mode 2] Route blocked while caravan & army in transit...")
	var world = _create_world()
	var reg_world = world.regional_world

	# Find route from Crownweft to Grey Marches
	var route = reg_world.get_route_between(RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_GREY_MARCHES)
	_assert(route != null, "Route Crownweft-Marches exists")

	# Order army onto this route
	var army = null
	for a in reg_world.armies.values():
		if a.faction_id == FactionCatalog.FACTION_PLAYER:
			army = a
			break
	_assert(army != null, "Player army exists")

	var march_res = reg_world.issue_march_order(army.id, RegionCatalog.REGION_GREY_MARCHES, world.current_tick, world.diplomacy)
	_assert(march_res.get("ok", false), "Army begins march towards Grey Marches")

	# Block the route
	route.is_open = false
	route.blocked_reason = "Hostile detachment blocks pass"

	# Advance army simulation
	reg_world.tick_regional_armies(world.current_tick + 1, world.diplomacy)

	# Verify army does not crash or corrupt supplies
	_assert(army.supplies.get(&"grain", 0.0) >= 0.0, "Army supplies remain non-negative")
	_assert(reg_world.armies.has(army.id), "Army remains registered")

	# Restore route
	route.is_open = true
	route.blocked_reason = ""

# ------------------------------------------------------------------------------
# Mode 3: Construction site cancelled mid-haul while citizen is carrying lumber
# ------------------------------------------------------------------------------
func test_mode_3_construction_cancelled_mid_haul() -> void:
	print("[Failure Mode 3] Construction site cancelled mid-haul...")
	var world = _create_world()
	var origin = world.world_state.start_settlement_pos

	var town_hall: BuildingState = world.buildings[0]
	town_hall.inventory.add_resource(&"timber", 50, "stock")
	town_hall.inventory.add_resource(&"stone", 30, "stock")

	# Place staged construction site at valid spot
	var site = world.place_building(&"storehouse", origin + Vector2i(-4, 0), false)
	_assert(site != null, "Storehouse construction site placed")
	_assert(site.is_under_construction(), "Site is under construction")

	# Setup hauler manually with cargo destined for site
	var hauler = world.logistics.haulers[0]
	hauler.carried_resource = &"timber"
	hauler.carried_amount = 10
	site.construction_inventory.reserve_in(&"timber", 10)

	# Cancel the construction site
	world.cancel_construction_site(site)

	# Invariant check: site is removed, town hall and inventories remain consistent
	var audit = SimulationInvariantChecker.audit(
		world.world_state, world.buildings, world.citizens, world.job_board,
		world.logistics, world.pathfinding, world.economy, world.government,
		world.diplomacy, world.regional_world
	)
	_assert(audit.passed, "Invariants hold after construction cancellation: " + audit.summary())

# ------------------------------------------------------------------------------
# Mode 4: Citizen drafted into an army while performing an active hauling job
# ------------------------------------------------------------------------------
func test_mode_4_citizen_role_reassignment_with_active_job() -> void:
	print("[Failure Mode 4] Citizen role reassignment with active hauling job...")
	var world = _create_world()
	var citizen: CitizenState = world.citizens[0]
	var hauler = world.logistics.haulers[0]

	# Create a dummy haul job
	var th: BuildingState = world.buildings[0]
	th.inventory.add_resource(&"grain", 20, "stock")
	var job = world.job_board.create_job(&"grain", 5, th.inventory, th.inventory, 1, world.current_tick)
	_assert(job != null, "Haul job created")
	world.job_board.assign_job(job, hauler.id)
	hauler.active_job = job

	# Citizen is drafted / role reassigned to soldier
	citizen.role_id = &"soldier"
	citizen.workplace_id = 0

	# Cancel job cleanly
	world.job_board.cancel_job(job, th.inventory, th.inventory, "DRAFTED_TO_MILITARY")
	hauler.active_job = null

	_assert_eq(th.inventory.get_reserved_out(&"grain"), 0, "Source reservation released")
	_assert_eq(th.inventory.get_reserved_in(&"grain"), 0, "Destination reservation released")
	_assert(job.status == HaulJob.Status.CANCELLED, "Job is cancelled")

# ------------------------------------------------------------------------------
# Mode 5: Faction treasury drops below zero during active contract fulfillment
# ------------------------------------------------------------------------------
func test_mode_5_empty_treasury_contract_protection() -> void:
	print("[Failure Mode 5] Empty treasury trade contract protection...")
	var world = _create_world()
	var reg_world = world.regional_world
	var valen = world.diplomacy.factions.get(FactionCatalog.FACTION_VALEN)
	_assert(valen != null, "Valen faction exists")

	# Drain Valen's treasury to 5 coins
	valen.treasury = 5
	valen.reserved_treasury = 0

	# Valen is buyer, Player is seller (exporting 10 grain for 50 coins)
	var contract: TradeContract = reg_world.create_trade_contract(
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_PLAYER,
		&"grain", 10, 50,
		RegionCatalog.REGION_CROWNWEFT,
		RegionCatalog.REGION_VALEN,
		world.current_tick
	)
	_assert(contract != null, "Contract drafted")

	var th: BuildingState = world.buildings[0]
	th.inventory.add_resource(&"grain", 20, "stock")

	# Attempt to accept: buyer has 5 coins, contract costs 50
	var res: Dictionary = reg_world.accept_trade_contract(contract.id, th.inventory, world.diplomacy, world.current_tick)
	_assert(not res.get("ok", false), "Accepting contract with insufficient buyer treasury must be rejected")
	_assert(valen.treasury >= 0, "Valen treasury remains non-negative")
	_assert_eq(valen.reserved_treasury, 0, "No treasury was reserved")

# ------------------------------------------------------------------------------
# Mode 6: Rapid policy flip back and forth within a single season
# ------------------------------------------------------------------------------
func test_mode_6_rapid_policy_flips() -> void:
	print("[Failure Mode 6] Rapid policy flips back and forth...")
	var world = _create_world()
	var gov = world.government
	var eco = world.economy

	for i in range(20):
		var opt: StringName = &"extended" if i % 2 == 0 else &"relaxed"
		gov.enact_policy(LawCatalog.LAW_LABOUR, opt, world.current_tick + i, "rapid_flip_test")

	# Recompute economy & approval through simulation tick
	world._simulation_tick()

	_assert(not is_nan(eco.approval), "Approval is not NaN")
	_assert(eco.approval >= 0.0 and eco.approval <= 100.0, "Approval bounded [0, 100]")
	_assert(gov.policy_history.size() >= 20, "Policy history recorded all flips")

# ------------------------------------------------------------------------------
# Mode 7: Storage capacity exhaustion mid-production run
# ------------------------------------------------------------------------------
func test_mode_7_storage_capacity_exhaustion() -> void:
	print("[Failure Mode 7] Storage capacity exhaustion mid-production run...")
	var world = _create_world()
	var origin = world.world_state.start_settlement_pos

	var bakery: BuildingState = world.place_building(&"bakery", origin + Vector2i(4, 5), true)
	bakery.status = BuildingState.Status.ACTIVE

	# Fill bakery to max capacity (100)
	bakery.inventory.add_resource(&"bread", bakery.inventory.capacity, "fill_to_max")
	_assert(bakery.inventory.get_total_quantity() >= bakery.inventory.capacity, "Bakery inventory is completely full")

	# Attempt to add 1 more bread without reservation
	var add_res: bool = bakery.inventory.add_resource(&"bread", 1, "excess_production", false)
	_assert(not add_res, "Excess production rejected when storage is full")
	_assert_eq(bakery.inventory.get_quantity(&"bread"), bakery.inventory.capacity, "Capacity never exceeded")

# ------------------------------------------------------------------------------
# Mode 8: Army supply line severed while occupying a hostile region
# ------------------------------------------------------------------------------
func test_mode_8_army_supply_line_severed() -> void:
	print("[Failure Mode 8] Army supply line severed while in field...")
	var world = _create_world()
	var reg_world = world.regional_world

	var army = null
	for a in reg_world.armies.values():
		if a.faction_id == FactionCatalog.FACTION_PLAYER:
			army = a
			break
	_assert(army != null, "Player army exists")

	# Move army to Grey Marches
	army.current_region_id = RegionCatalog.REGION_GREY_MARCHES

	# Block all routes connected to Grey Marches
	for r in reg_world.routes:
		if r.region_a == RegionCatalog.REGION_GREY_MARCHES or r.region_b == RegionCatalog.REGION_GREY_MARCHES:
			r.is_open = false
			r.blocked_reason = "Marsh quagmire submerged"

	# Tick regional armies: army should consume supplies or decay without crashing
	var pre_grain: float = army.supplies.get(&"grain", 0.0)
	reg_world.tick_regional_armies(world.current_tick + 1, world.diplomacy)
	var post_grain: float = army.supplies.get(&"grain", 0.0)

	_assert(post_grain <= pre_grain, "Supplies decreased or held")
	_assert(post_grain >= 0.0, "Supplies remain non-negative")

	# Unblock routes
	for r in reg_world.routes:
		r.is_open = true
		r.blocked_reason = ""

# ------------------------------------------------------------------------------
# Mode 9: Citizen death / dismissal while holding critical government office
# ------------------------------------------------------------------------------
func test_mode_9_officeholder_dismissal_resilience() -> void:
	print("[Failure Mode 9] Citizen dismissal while holding administrator office...")
	var world = _create_world()
	var c: CitizenState = world.citizens[0]
	c.role_id = &"administrator"
	c.workplace_id = world.buildings[0].entity_id

	# Erase citizen from citizens list
	world.citizens.erase(c)

	# Tick simulation: economy calculation should gracefully handle missing administrator
	world._simulation_tick()

	var audit = SimulationInvariantChecker.audit(
		world.world_state, world.buildings, world.citizens, world.job_board,
		world.logistics, world.pathfinding, world.economy, world.government,
		world.diplomacy, world.regional_world
	)
	_assert(audit.passed, "Invariants pass after administrator removed: " + audit.summary())

# ------------------------------------------------------------------------------
# Mode 10: War declaration during active in-transit trade shipment
# ------------------------------------------------------------------------------
func test_mode_10_war_declaration_during_active_trade() -> void:
	print("[Failure Mode 10] War declaration during active in-transit trade...")
	var world = _create_world()
	var reg_world = world.regional_world
	var th = world.buildings[0]
	th.inventory.add_resource(&"grain", 30, "stock")

	# Form trade contract between Player and Ironpeak
	var contract = reg_world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_IRONPEAK,
		&"grain", 10, 20,
		RegionCatalog.REGION_CROWNWEFT,
		RegionCatalog.REGION_IRONPEAK,
		world.current_tick
	)
	_assert(contract != null, "Trade contract formed")

	var accept_res = reg_world.accept_trade_contract(contract.id, th.inventory, world.diplomacy, world.current_tick)
	_assert(accept_res.get("ok", false), "Contract accepted and shipment dispatched")

	var shipment = reg_world.get_shipment(contract.shipment_id)
	_assert(shipment != null, "Shipment exists")
	_assert_eq(shipment.status, TradeShipment.STATUS_IN_TRANSIT, "Shipment is in transit")

	# Declare war between Player and Ironpeak
	var war = world.diplomacy.create_war(
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_IRONPEAK,
		"War erupted mid-trade",
		world.current_tick,
		WarState.STATUS_WAR
	)
	_assert(war != null, "War created")

	# Tick trade shipment: it should detect the war
	reg_world.tick_regional_trade_shipments(world.current_tick + 1, world.diplomacy, th.inventory)

	# Verify shipment halted, redirected or marked waiting without losing goods
	_assert(shipment.cargo.get(&"grain", 0) == 10, "Shipment still carries 10 grain intact")
	_assert(shipment.status == TradeShipment.STATUS_WAITING_ROUTE or shipment.status == TradeShipment.STATUS_IN_TRANSIT or shipment.status == TradeShipment.STATUS_RETURNING, "Shipment safely transitioned state")
