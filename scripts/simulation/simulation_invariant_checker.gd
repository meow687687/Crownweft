class_name SimulationInvariantChecker
extends RefCounted

# Result of an invariant check run
class CheckResult:
	var passed: bool = true
	var violations: Array[String] = []

	func add_violation(entity_type: String, entity_id: Variant, rule: String, reason: String) -> void:
		passed = false
		violations.append("[%s id=%s] %s: %s" % [entity_type, str(entity_id), rule, reason])

	func summary() -> String:
		if passed:
			return "ALL INVARIANTS PASSED (0 violations)"
		var text := "INVARIANT FAILURES DETECTED (%d violations):\n" % violations.size()
		for v in violations:
			text += "  - " + v + "\n"
		return text

# Runs all invariant audits against the provided simulation state
static func audit(
	world_state: WorldState,
	buildings: Array[BuildingState],
	citizens: Array[CitizenState],
	job_board: JobBoard,
	logistics: LogisticsSystem,
	pathfinding: PathfindingService,
	economy: EconomyState = null,
	government: GovernmentState = null,
	diplomacy: DiplomacyState = null,
	regional_world: RegionalWorldState = null
) -> CheckResult:
	var result := CheckResult.new()
	
	_check_identities_and_uniqueness(result, buildings, citizens, logistics, regional_world)
	_check_citizens_and_workforce(result, citizens, buildings, logistics)
	_check_inventories_and_transactions(result, buildings, job_board, logistics)
	_check_buildings_and_spatial(result, buildings, world_state, pathfinding)
	_check_diplomacy_and_wars(result, diplomacy, regional_world)
	_check_regional_trade(result, regional_world, diplomacy)
	
	return result

# 1. Identities and Uniqueness
static func _check_identities_and_uniqueness(
	result: CheckResult,
	buildings: Array[BuildingState],
	citizens: Array[CitizenState],
	logistics: LogisticsSystem,
	regional_world: RegionalWorldState
) -> void:
	var b_ids: Dictionary = {}
	var inv_ids: Dictionary = {}
	for b in buildings:
		if b == null:
			result.add_violation("Building", "null", "NULL_REFERENCE", "Building entry in array is null")
			continue
		if b_ids.has(b.entity_id):
			result.add_violation("Building", b.entity_id, "DUPLICATE_ID", "Duplicate building entity_id")
		b_ids[b.entity_id] = true
		
		if b.inventory != null:
			if inv_ids.has(b.inventory.owner_id):
				result.add_violation("Inventory", b.inventory.owner_id, "DUPLICATE_INVENTORY_ID", "Primary inventory owner_id duplicated")
			inv_ids[b.inventory.owner_id] = true
		if b.construction_inventory != null:
			if inv_ids.has(b.construction_inventory.owner_id):
				result.add_violation("ConstructionInventory", b.construction_inventory.owner_id, "DUPLICATE_INVENTORY_ID", "Construction inventory owner_id duplicated")
			inv_ids[b.construction_inventory.owner_id] = true

	var c_ids: Dictionary = {}
	for c in citizens:
		if c == null:
			result.add_violation("Citizen", "null", "NULL_REFERENCE", "Citizen entry in array is null")
			continue
		if c_ids.has(c.id):
			result.add_violation("Citizen", c.id, "DUPLICATE_ID", "Duplicate citizen id")
		c_ids[c.id] = true

	if regional_world != null:
		var army_ids: Dictionary = {}
		for a in regional_world.armies.values():
			if army_ids.has(a.id):
				result.add_violation("Army", a.id, "DUPLICATE_ID", "Duplicate army id")
			army_ids[a.id] = true
			
		var contract_ids: Dictionary = {}
		for con in regional_world.contracts.values():
			if contract_ids.has(con.id):
				result.add_violation("TradeContract", con.id, "DUPLICATE_ID", "Duplicate trade contract id")
			contract_ids[con.id] = true
			
		var shipment_ids: Dictionary = {}
		for sh in regional_world.shipments.values():
			if shipment_ids.has(sh.id):
				result.add_violation("TradeShipment", sh.id, "DUPLICATE_ID", "Duplicate trade shipment id")
			shipment_ids[sh.id] = true

# 2. Citizens and Workforce
static func _check_citizens_and_workforce(
	result: CheckResult,
	citizens: Array[CitizenState],
	buildings: Array[BuildingState],
	logistics: LogisticsSystem
) -> void:
	var building_map: Dictionary = {}
	for b in buildings:
		if b != null:
			building_map[b.entity_id] = b

	var hauler_citizens: Dictionary = {}
	if logistics != null:
		for h in logistics.haulers:
			hauler_citizens[h.id] = h

	var workers_per_building: Dictionary = {}
	var occupants_per_home: Dictionary = {}

	for c in citizens:
		if c == null:
			continue
		# Energy range
		if c.energy < 0.0 or c.energy > 105.0: # allow small float tolerance
			result.add_violation("Citizen", c.id, "ENERGY_OUT_OF_BOUNDS", "Energy value %.2f out of [0, 100]" % c.energy)

		# Workplace validity
		if c.workplace_id > 0:
			var wp: BuildingState = building_map.get(c.workplace_id, null)
			if wp == null:
				result.add_violation("Citizen", c.id, "INVALID_WORKPLACE", "Assigned workplace_id %d does not exist" % c.workplace_id)
			elif wp.is_destroyed:
				result.add_violation("Citizen", c.id, "DESTROYED_WORKPLACE", "Assigned workplace_id %d is marked destroyed" % c.workplace_id)
			else:
				workers_per_building[c.workplace_id] = workers_per_building.get(c.workplace_id, 0) + 1
		elif c.workplace_id == 0:
			if c.role_id != &"unassigned" and c.role_id != &"hauler":
				result.add_violation("Citizen", c.id, "ROLE_MISMATCH", "Unemployed citizen has specialized role %s" % str(c.role_id))

		# Home validity
		if c.home_building_id > 0:
			var home: BuildingState = building_map.get(c.home_building_id, null)
			if home == null or home.is_destroyed:
				result.add_violation("Citizen", c.id, "INVALID_HOME", "Home building id %d missing or destroyed" % c.home_building_id)
			elif home.status != BuildingState.Status.ACTIVE:
				result.add_violation("Citizen", c.id, "INACTIVE_HOME", "Home building id %d is under construction or planned" % c.home_building_id)
			else:
				occupants_per_home[c.home_building_id] = occupants_per_home.get(c.home_building_id, 0) + 1

		# Rest and hauling consistency
		if c.is_resting:
			var h = hauler_citizens.get(c.id, null)
			if h != null and h.carried_amount > 0:
				result.add_violation("Citizen", c.id, "RESTING_WHILE_CARRYING", "Citizen is resting while holding carried cargo %s (%d)" % [str(h.carried_resource), h.carried_amount])

	# Check building assigned_workers agreement and housing capacity
	for b in buildings:
		if b == null or b.is_destroyed:
			continue
		var counted_workers: int = workers_per_building.get(b.entity_id, 0)
		if b.assigned_workers != counted_workers:
			result.add_violation("Building", b.entity_id, "WORKER_COUNT_MISMATCH", "Building records %d assigned workers, but %d citizens reference it" % [b.assigned_workers, counted_workers])
		
		var housing_cap: int = b.get_housing_capacity()
		var occupants: int = occupants_per_home.get(b.entity_id, 0)
		if occupants > housing_cap:
			result.add_violation("Building", b.entity_id, "OVERCROWDED_HOUSING", "Building housing capacity %d exceeded by %d occupants" % [housing_cap, occupants])

# 3. Inventories and Transactions
static func _check_inventories_and_transactions(
	result: CheckResult,
	buildings: Array[BuildingState],
	job_board: JobBoard,
	logistics: LogisticsSystem
) -> void:
	var all_inventories: Array[Inventory] = []
	for b in buildings:
		if b != null:
			if b.inventory != null:
				all_inventories.append(b.inventory)
			if b.construction_inventory != null:
				all_inventories.append(b.construction_inventory)

	for inv in all_inventories:
		# Check quantities nonnegative
		for res_id in inv.quantities:
			var qty: int = inv.quantities[res_id]
			if qty < 0:
				result.add_violation("Inventory", inv.owner_id, "NEGATIVE_QUANTITY", "Resource %s quantity is negative (%d)" % [str(res_id), qty])
		
		# Check capacity (skip overflow ground piles)
		var total_qty: int = inv.get_total_quantity()
		if inv.capacity > 0 and total_qty > inv.capacity:
			result.add_violation("Inventory", inv.owner_id, "CAPACITY_EXCEEDED", "Total items %d exceeds capacity %d" % [total_qty, inv.capacity])

		# Check reservations
		for res_id in inv.reserved_out:
			var res_out: int = inv.reserved_out[res_id]
			if res_out < 0:
				result.add_violation("Inventory", inv.owner_id, "NEGATIVE_RESERVE_OUT", "Reserved out %s is %d" % [str(res_id), res_out])
			var current_qty: int = inv.get_quantity(res_id)
			if res_out > current_qty:
				result.add_violation("Inventory", inv.owner_id, "RESERVE_OUT_EXCEEDS_QTY", "Reserved out %s (%d) exceeds available quantity (%d)" % [str(res_id), res_out, current_qty])

		for res_id in inv.reserved_in:
			var res_in: int = inv.reserved_in[res_id]
			if res_in < 0:
				result.add_violation("Inventory", inv.owner_id, "NEGATIVE_RESERVE_IN", "Reserved in %s is %d" % [str(res_id), res_in])

	# Check haul jobs and haulers
	if job_board != null:
		for job in job_board.jobs.values():
			if job == null:
				continue
			if job.amount <= 0:
				result.add_violation("HaulJob", job.id, "INVALID_JOB_AMOUNT", "HaulJob amount is <= 0 (%d)" % job.amount)
			if job.status == HaulJob.Status.REQUESTED or job.status == HaulJob.Status.ASSIGNED:
				if job.reserved_amount < 0:
					result.add_violation("HaulJob", job.id, "NEGATIVE_RESERVED_AMOUNT", "HaulJob reserved_amount < 0")

	if logistics != null:
		for hauler in logistics.haulers:
			if hauler.carried_amount < 0:
				result.add_violation("Hauler", hauler.id, "NEGATIVE_CARRIED_CARGO", "Carried cargo is negative (%d)" % hauler.carried_amount)
			if hauler.carried_amount > 0 and hauler.carried_resource == &"":
				result.add_violation("Hauler", hauler.id, "CARGO_WITHOUT_RESOURCE_ID", "Hauler carries %d items without a resource_id" % hauler.carried_amount)

# 4. Buildings and Spatial Integrity
static func _check_buildings_and_spatial(
	result: CheckResult,
	buildings: Array[BuildingState],
	world_state: WorldState,
	pathfinding: PathfindingService
) -> void:
	if world_state == null:
		return
	for b in buildings:
		if b == null or b.is_destroyed:
			continue
		var fp: Vector2i = b.get_footprint()
		if fp.x <= 0 or fp.y <= 0:
			result.add_violation("Building", b.entity_id, "INVALID_FOOTPRINT", "Building footprint is non-positive: %s" % str(fp))
			continue

		for dy in range(fp.y):
			for dx in range(fp.x):
				var coord: Vector2i = b.tile_origin + Vector2i(dx, dy)
				if not world_state.is_valid_coord(coord):
					result.add_violation("Building", b.entity_id, "OUT_OF_BOUNDS", "Tile %s is outside map boundaries" % str(coord))
					continue
				var tile: WorldTile = world_state.get_tile(coord)
				if tile == null:
					result.add_violation("Building", b.entity_id, "NULL_TILE", "Tile %s is null" % str(coord))
					continue
				if tile.building_id != b.entity_id:
					result.add_violation("Building", b.entity_id, "TILE_BUILDING_ID_MISMATCH", "Tile %s building_id is %d, expected %d" % [str(coord), tile.building_id, b.entity_id])
				if tile.is_walkable:
					result.add_violation("Building", b.entity_id, "SOLID_FOOTPRINT_WALKABLE", "Tile %s under active building is marked walkable" % str(coord))
				if pathfinding != null and not pathfinding.astar_grid.is_point_solid(coord):
					result.add_violation("Building", b.entity_id, "ASTAR_GRID_NOT_SOLID", "Tile %s under active building is not solid in A* grid" % str(coord))

# 5. Diplomacy, Wars and Armies
static func _check_diplomacy_and_wars(
	result: CheckResult,
	diplomacy: DiplomacyState,
	regional_world: RegionalWorldState
) -> void:
	if diplomacy == null:
		return

	# Self war check
	for faction_id in diplomacy.factions:
		var f: FactionState = diplomacy.factions[faction_id]
		if f.treasury < 0:
			result.add_violation("Faction", faction_id, "NEGATIVE_TREASURY", "Faction treasury is negative: %d" % f.treasury)
		if f.reserved_treasury < 0:
			result.add_violation("Faction", faction_id, "NEGATIVE_RESERVED_TREASURY", "Reserved treasury is negative: %d" % f.reserved_treasury)
		if f.reserved_treasury > f.treasury:
			result.add_violation("Faction", faction_id, "RESERVED_EXCEEDS_TREASURY", "Reserved treasury (%d) exceeds total treasury (%d)" % [f.reserved_treasury, f.treasury])

	for war in diplomacy.active_wars:
		if war.initiating_faction == war.target_faction:
			result.add_violation("WarState", war.id, "SELF_WAR", "Faction %s is at war with itself" % str(war.initiating_faction))
		if not diplomacy.factions.has(war.initiating_faction):
			result.add_violation("WarState", war.id, "UNKNOWN_ATTACKER", "Initiating faction %s not in factions catalog" % str(war.initiating_faction))
		if not diplomacy.factions.has(war.target_faction):
			result.add_violation("WarState", war.id, "UNKNOWN_DEFENDER", "Target faction %s not in factions catalog" % str(war.target_faction))

	if regional_world != null:
		for army in regional_world.armies.values():
			var total_supplies: float = 0.0
			for res_id in army.supplies:
				var s_amt: float = float(army.supplies[res_id])
				if s_amt < 0.0:
					result.add_violation("Army", army.id, "NEGATIVE_SUPPLIES", "Army supply %s is negative: %.2f" % [str(res_id), s_amt])
				total_supplies += s_amt
			if army.max_supply_capacity <= 0:
				result.add_violation("Army", army.id, "INVALID_MAX_SUPPLIES", "Army max supplies is <= 0: %d" % army.max_supply_capacity)
			if total_supplies > float(army.max_supply_capacity):
				result.add_violation("Army", army.id, "SUPPLIES_EXCEED_MAX", "Army total supplies %.2f exceeds max %d" % [total_supplies, army.max_supply_capacity])
			if not diplomacy.factions.has(army.faction_id):
				result.add_violation("Army", army.id, "UNKNOWN_ARMY_FACTION", "Army owner faction %s does not exist" % str(army.faction_id))

# 6. Regional Trade Contracts and Shipments
static func _check_regional_trade(
	result: CheckResult,
	regional_world: RegionalWorldState,
	diplomacy: DiplomacyState
) -> void:
	if regional_world == null:
		return

	var contract_map: Dictionary = {}
	for con in regional_world.contracts.values():
		contract_map[con.id] = con
		if con.resource_amount <= 0:
			result.add_violation("TradeContract", con.id, "INVALID_CONTRACT_QUANTITY", "Quantity <= 0: %d" % con.resource_amount)
		if con.total_price < 0:
			result.add_violation("TradeContract", con.id, "NEGATIVE_CONTRACT_PRICE", "Total price < 0: %d" % con.total_price)
		if con.buyer_faction_id == con.seller_faction_id:
			result.add_violation("TradeContract", con.id, "SAME_BUYER_SELLER", "Contract buyer and seller are identical: %s" % str(con.buyer_faction_id))

	for sh in regional_world.shipments.values():
		var con: TradeContract = contract_map.get(sh.contract_id, null)
		if con == null:
			result.add_violation("TradeShipment", sh.id, "MISSING_CONTRACT", "Shipment references non-existent contract %d" % sh.contract_id)
		else:
			if sh.status == TradeShipment.STATUS_DELIVERED:
				if con.status != TradeContract.STATUS_DELIVERED and con.status != TradeContract.STATUS_SETTLED:
					result.add_violation("TradeShipment", sh.id, "CONTRACT_STATUS_MISMATCH", "Shipment is %s but contract is %s" % [sh.status, con.status])
		for res_id in sh.cargo:
			var amount: int = sh.cargo[res_id]
			if amount < 0:
				result.add_violation("TradeShipment", sh.id, "NEGATIVE_CARGO", "Shipment cargo %s is negative: %d" % [str(res_id), amount])
