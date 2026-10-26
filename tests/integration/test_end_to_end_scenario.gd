class_name TestEndToEndScenario
extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")
const SimulationInvariantChecker = preload("res://scripts/simulation/simulation_invariant_checker.gd")
const TradeContract = preload("res://scripts/domain/trade_contract.gd")
const TradeShipment = preload("res://scripts/domain/trade_shipment.gd")

var _failed_assertions: int = 0

func _init() -> void:
	print("\n==============================================")
	print("--- Running TestEndToEndScenario (Task 17) ---")
	print("==============================================")
	
	test_end_to_end_settlement_scenario()
	
	if _failed_assertions > 0:
		printerr("\n!! TestEndToEndScenario FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
		
	print("--- TestEndToEndScenario PASSED ---\n")
	quit(0)

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func _assert_eq(a, b, msg: String) -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_end_to_end_settlement_scenario() -> void:
	var world = load("res://scenes/world/world.tscn").instantiate()
	world._init_simulation()
	var origin: Vector2i = world.world_state.start_settlement_pos
	
	# Initial invariant check on fresh world
	var inv_check: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
		world.world_state, world.buildings, world.citizens, world.job_board,
		world.logistics, world.pathfinding, world.economy, world.government,
		world.diplomacy, world.regional_world
	)
	_assert(inv_check.passed, "Initial world must satisfy all invariants: " + inv_check.summary())
	
	# --------------------------------------------------------------------------
	# Phase A: Enact Government Policy and Culture/Belief Foundation
	# --------------------------------------------------------------------------
	print("[Phase A] Enacting government policy and cultural conviction...")
	var enact_ok: bool = world.government.enact_policy(LawCatalog.LAW_TAXATION, &"low", 1, "Promote civic goodwill")
	_assert(enact_ok, "Low taxation policy should be successfully enacted")
	_assert_eq(world.government.get_policy(LawCatalog.LAW_TAXATION), &"low", "Enacted policy should be low taxation")
	
	# Verify that a citizen has a defined culture with documented gameplay significance
	var citizen_0: CitizenState = world.citizens[0]
	_assert(citizen_0.culture_id != &"", "Citizen 0 must have an assigned culture")
	_assert(citizen_0.species_id != &"", "Citizen 0 must have an assigned species")
	_assert(citizen_0.social_status_id != &"", "Citizen 0 must have a social status")
	
	# --------------------------------------------------------------------------
	# Phase B: Farming Production Chain & Physical Hauling
	# --------------------------------------------------------------------------
	print("[Phase B] Setting up farm and staffing farmer...")
	var farm_pos := origin + Vector2i(4, 0)
	var farm: BuildingState = world.place_building(&"farm", farm_pos, true)
	_assert(farm != null, "Farm should be placed successfully")
	farm.status = BuildingState.Status.ACTIVE
	
	# Assign citizen 2 (unassigned) as farmer
	var farmer: CitizenState = world.citizens[2]
	_assert_eq(farmer.role_id, &"unassigned", "Citizen 2 starts unassigned")
	farmer.workplace_id = farm.entity_id
	farmer.role_id = &"farmer"
	farm.assigned_workers = 1
	
	# Advance simulation ticks for farm production
	print("  Simulating 60 ticks for farm production...")
	for t in range(60):
		world._simulation_tick()
		
	# Verify farmer gained farming experience and consumed energy
	_assert(farmer.energy < 100.0, "Farmer energy must decrease after work")
	_assert(farmer.get_skill_factor(&"farming") >= 0.6, "Farmer skill factor is within valid bounded range [0.6, 1.45]")
	_assert(farm.inventory.get_quantity(&"grain") > 0, "Farm should have produced grain")
	print("  Farm produced %d grain. Farmer energy: %.1f" % [farm.inventory.get_quantity(&"grain"), farmer.energy])
	
	# --------------------------------------------------------------------------
	# Phase C: Staged Construction of Storehouse Receiving Delivered Materials
	# --------------------------------------------------------------------------
	print("[Phase C] Placing staged construction site for storehouse...")
	var storehouse_pos := origin + Vector2i(-4, 0)
	# Town Hall starts with 25 timber, 10 stone
	var site: BuildingState = world.place_building(&"storehouse", storehouse_pos, false)
	_assert(site != null, "Storehouse construction site placed")
	_assert(site.is_under_construction(), "Storehouse is under construction")
	
	# Assign citizen 3 as builder
	var builder: CitizenState = world.citizens[3]
	builder.workplace_id = site.entity_id
	builder.role_id = &"builder"
	site.assigned_workers = 1
	
	print("  Simulating ticks for material delivery and construction completion...")
	var site_completed := false
	for t in range(120):
		world._simulation_tick()
		if site.status == BuildingState.Status.ACTIVE:
			site_completed = true
			break
			
	_assert(site_completed, "Storehouse construction site must complete into an active building")
	_assert(site.is_active(), "Storehouse is now active")
	_assert_eq(site.construction_inventory.get_quantity(&"timber"), 0, "Construction timber consumed")
	
	# --------------------------------------------------------------------------
	# Phase D: Fatigue, Rest and Energy Recovery in Homes
	# --------------------------------------------------------------------------
	print("[Phase D] Testing fatigue, rest, and energy recovery...")
	var house_pos := origin + Vector2i(0, 4)
	var house: BuildingState = world.place_building(&"house", house_pos, true)
	_assert(house != null, "House placed for residential resting")
	
	farmer.energy = 15.0 # Below exhaustion threshold (20)
	_assert(farmer.is_exhausted(), "Farmer should be reported as exhausted")
	
	# Position farmer at home entrance to rest
	farmer.position_tile = house.get_entrance_tile()
	
	# Run ticks to observe rest cycle
	for t in range(50):
		world._simulation_tick()
		if not farmer.is_resting and farmer.energy >= CitizenState.RECOVERY_THRESHOLD:
			break
			
	_assert(farmer.energy >= CitizenState.RECOVERY_THRESHOLD, "Farmer energy must recover past recovery threshold (80.0)")
	_assert(not farmer.is_resting, "Farmer finished resting and resumed active work state")
	print("  Farmer energy recovered to %.1f (resting=%s)" % [farmer.energy, str(farmer.is_resting)])
	
	# --------------------------------------------------------------------------
	# Phase E: Regional Trade Contract, Delivery and Single Settlement
	# --------------------------------------------------------------------------
	print("[Phase E] Forming regional trade contract with Valen...")
	var reg_world: RegionalWorldState = world.regional_world
	_assert(reg_world != null, "RegionalWorldState must be active")
	var town_hall: BuildingState = world.buildings[0]
	
	# Town Hall storehouse has coin
	var initial_th_coins: int = town_hall.inventory.get_quantity(&"coin")
	_assert(initial_th_coins >= 20, "Town Hall has sufficient coins")
	
	# Player sells 15 grain to Valen for 25 coins
	farm.inventory.add_resource(&"grain", 15, "TEST_EXPORT")
	town_hall.inventory.add_resource(&"grain", 15, "TEST_EXPORT")
	var contract: TradeContract = reg_world.create_trade_contract(
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_PLAYER,
		&"grain", 15, 25,
		RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN,
		world.current_tick
	)
	_assert(contract != null, "Contract created")
	_assert(contract.status == TradeContract.STATUS_OFFERED, "Contract offered")
	
	var accept_res: Dictionary = reg_world.accept_trade_contract(contract.id, town_hall.inventory, world.diplomacy, world.current_tick)
	_assert(accept_res.get("ok", false), "Trade contract accepted and reserved: " + str(accept_res.get("reason", "")))
	
	var shipment: TradeShipment = reg_world.get_shipment(contract.shipment_id)
	_assert(shipment != null, "Trade shipment dispatched")
	_assert_eq(shipment.status, TradeShipment.STATUS_IN_TRANSIT, "Shipment in transit")
	_assert_eq(shipment.cargo[&"grain"], 15, "Shipment carries 15 grain")
	
	# Advance caravan movement
	for t in range(20):
		reg_world.tick_regional_trade_shipments(world.current_tick + t, world.diplomacy, town_hall.inventory)
		
	# Fast-forward to destination and settle
	shipment.current_region_id = RegionCatalog.REGION_VALEN
	shipment.route_path.clear()
	var settle_res: Dictionary = reg_world.deliver_and_settle_contract(contract.id, town_hall.inventory, world.diplomacy, world.current_tick + 30)
	_assert(settle_res.get("ok", false), "Trade contract delivered and settled")
	_assert(contract.status == TradeContract.STATUS_SETTLED, "Trade contract must be settled")
	_assert_eq(town_hall.inventory.get_quantity(&"coin"), initial_th_coins + 25, "Player received 25 coins for exported grain")
	print("  Caravan arrived! Settlement verified (+25 coins).")
	
	# --------------------------------------------------------------------------
	# Phase F: Regional Army Movement & Supply Consumption
	# --------------------------------------------------------------------------
	print("[Phase F] Ordering regional army march and monitoring supplies...")
	var player_army = null
	for a in reg_world.armies.values():
		if a.faction_id == FactionCatalog.FACTION_PLAYER:
			player_army = a
			break
			
	_assert(player_army != null, "Player regional army exists")
	var initial_army_supplies: float = player_army.supplies.get(&"grain", 0.0)
	_assert(initial_army_supplies > 0.0, "Player army has initial supplies")
	
	# Order march to Grey Marches (neutral territory)
	var march_res: Dictionary = reg_world.issue_march_order(player_army.id, RegionCatalog.REGION_GREY_MARCHES, world.current_tick, world.diplomacy)
	_assert(march_res.get("ok", false), "March order accepted: " + str(march_res.get("reason", "")))
	_assert_eq(player_army.status, ArmyState.STATUS_MARCHING, "Army status is marching")
	
	for t in range(30):
		reg_world.tick_regional_armies(world.current_tick + t, world.diplomacy)
		
	var supplies_after_march: float = player_army.supplies.get(&"grain", 0.0)
	_assert(supplies_after_march < initial_army_supplies, "Army supplies must decrease while marching")
	print("  Army marched along route. Supplies: %.2f -> %.2f" % [initial_army_supplies, supplies_after_march])
	
	# --------------------------------------------------------------------------
	# Phase G: Diplomatic Proposal & Wartime Route Restriction
	# --------------------------------------------------------------------------
	print("[Phase G] Testing diplomatic events and war restrictions...")
	# Declare war between Player and Ironpeak
	var war: WarState = world.diplomacy.create_war(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_IRONPEAK, "Border incident", world.current_tick, WarState.STATUS_WAR)
	_assert(war != null, "War created between Player and Ironpeak")
	_assert(world.diplomacy.has_active_war(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_IRONPEAK), "Factions are at war")
	
	# Attempting trade contract between hostile factions must be rejected upon acceptance
	var hostile_contract: TradeContract = reg_world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_IRONPEAK,
		&"stone", 5, 10,
		RegionCatalog.REGION_IRONPEAK, RegionCatalog.REGION_CROWNWEFT,
		world.current_tick
	)
	_assert(hostile_contract != null, "Trade contract can be drafted")
	var hostile_accept: Dictionary = reg_world.accept_trade_contract(hostile_contract.id, town_hall.inventory, world.diplomacy, world.current_tick)
	_assert(not hostile_accept.get("ok", false), "Trade contract acceptance with hostile faction must be rejected")
	
	# Ceasefire negotiation
	var cease_res: Dictionary = world.diplomacy_system.negotiate_ceasefire(world.diplomacy, war.id, world.current_tick)
	_assert(cease_res.get("ok", false), "Ceasefire signed successfully: " + str(cease_res.get("reason", "")))
	_assert_eq(war.status, WarState.STATUS_CEASEFIRE, "War status transitioned to CEASEFIRE")
	
	# --------------------------------------------------------------------------
	# Phase H: Final Deep Invariant Audit
	# --------------------------------------------------------------------------
	print("[Phase H] Executing comprehensive post-scenario invariant audit...")
	var final_audit: SimulationInvariantChecker.CheckResult = SimulationInvariantChecker.audit(
		world.world_state, world.buildings, world.citizens, world.job_board,
		world.logistics, world.pathfinding, world.economy, world.government,
		world.diplomacy, world.regional_world
	)
	_assert(final_audit.passed, "Post-scenario world must satisfy all invariants: " + final_audit.summary())
	print("  %s" % final_audit.summary())
