class_name RegionalWorldState
extends RefCounted

var regions: Dictionary = {} # StringName -> RegionState
var routes: Array[RegionRoute] = []
var armies: Dictionary = {} # int -> ArmyState
var next_army_id: int = 1
var objectives: Dictionary = {} # int -> CampaignObjective
var next_objective_id: int = 1
var engagements: Dictionary = {} # int -> RegionalEngagement
var next_engagement_id: int = 1
var contracts: Dictionary = {} # int -> TradeContract
var next_contract_id: int = 1
var shipments: Dictionary = {} # int -> TradeShipment
var next_shipment_id: int = 1
var selected_region_id: StringName = &""

func _init() -> void:
	pass

func get_region(id: StringName) -> RegionState:
	return regions.get(id, null)

func has_region(id: StringName) -> bool:
	return regions.has(id)

func get_routes_for_region(region_id: StringName) -> Array[RegionRoute]:
	var res: Array[RegionRoute] = []
	for r in routes:
		if r.has_endpoint(region_id):
			res.append(r)
	return res

func get_route_between(r1: StringName, r2: StringName) -> RegionRoute:
	for r in routes:
		if r.connects(r1, r2):
			return r
	return null

func validate_graph() -> Dictionary:
	var errors: Array[String] = []
	
	if regions.is_empty():
		errors.append("Regional world has no regions defined.")
		return {"ok": false, "errors": errors}

	# Check regions and neighbour references
	for r_id in regions:
		var reg: RegionState = regions[r_id]
		if reg.id != r_id:
			errors.append("Region key '%s' does not match internal id '%s'." % [r_id, reg.id])
		for n_id in reg.neighbors:
			if not regions.has(n_id):
				errors.append("Region '%s' references nonexistent neighbour '%s'." % [r_id, n_id])

	# Check routes
	for r in routes:
		if not regions.has(r.region_a):
			errors.append("Route '%s' references nonexistent region_a '%s'." % [r.id, r.region_a])
		if not regions.has(r.region_b):
			errors.append("Route '%s' references nonexistent region_b '%s'." % [r.id, r.region_b])
		if r.region_a == r.region_b:
			errors.append("Route '%s' connects region '%s' to itself." % [r.id, r.region_a])

	# Check graph connectivity via BFS from first region
	var keys: Array = regions.keys()
	if not keys.is_empty():
		var start_id: StringName = keys[0]
		var visited: Dictionary = {start_id: true}
		var queue: Array[StringName] = [start_id]
		while not queue.is_empty():
			var curr: StringName = queue.pop_front()
			for r in routes:
				if r.has_endpoint(curr):
					var other: StringName = r.get_other_region(curr)
					if not visited.has(other):
						visited[other] = true
						queue.append(other)
		if visited.size() != regions.size():
			errors.append("Regional graph is disconnected. Visited %d of %d regions." % [visited.size(), regions.size()])

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}

func find_route(from_id: StringName, to_id: StringName, options: Dictionary = {}) -> Dictionary:
	if not regions.has(from_id):
		return {"ok": false, "reason": "Origin region '%s' does not exist" % from_id}
	if not regions.has(to_id):
		return {"ok": false, "reason": "Destination region '%s' does not exist" % to_id}
	if from_id == to_id:
		return {
			"ok": true,
			"path": [from_id],
			"routes": [],
			"total_ticks": 0,
			"total_supply_cost": 0
		}

	var criterion: String = options.get("criterion", "ticks")
	var ignore_closed: bool = bool(options.get("ignore_closed", false))
	var avoid_factions: Array = options.get("avoid_factions", [])

	# Dijkstra's shortest path algorithm
	var dist: Dictionary = {}
	var prev_region: Dictionary = {}
	var prev_route: Dictionary = {}
	var unvisited: Dictionary = {}

	for r_id in regions:
		dist[r_id] = 999999999
		unvisited[r_id] = true

	dist[from_id] = 0

	while not unvisited.is_empty():
		# Find min dist node in unvisited
		var current: StringName = &""
		var min_d: int = 999999999
		for r_id in unvisited:
			var d: int = int(dist[r_id])
			if d < min_d:
				min_d = d
				current = r_id

		if current == &"" or min_d >= 999999999:
			break # Remaining nodes unreachable
		if current == to_id:
			break # Found shortest path to destination

		unvisited.erase(current)

		for route in routes:
			if not route.has_endpoint(current):
				continue
			if not route.is_open and not ignore_closed:
				continue

			var neighbor_id: StringName = route.get_other_region(current)
			if not unvisited.has(neighbor_id):
				continue

			# Check avoided factions (unless it's the target destination)
			if neighbor_id != to_id and not avoid_factions.is_empty():
				var n_reg: RegionState = regions[neighbor_id]
				var eff_controller: StringName = n_reg.get_effective_controller()
				if avoid_factions.has(eff_controller):
					continue

			var weight: int = route.travel_ticks if criterion == "ticks" else route.supply_cost_coin
			var new_dist: int = min_d + weight

			if new_dist < int(dist[neighbor_id]):
				dist[neighbor_id] = new_dist
				prev_region[neighbor_id] = current
				prev_route[neighbor_id] = route

	if not prev_region.has(to_id):
		return {
			"ok": false,
			"reason": "No accessible route found between '%s' and '%s'" % [from_id, to_id]
		}

	# Reconstruct path
	var path: Array[StringName] = []
	var route_list: Array[StringName] = []
	var curr: StringName = to_id
	var total_ticks: int = 0
	var total_cost: int = 0

	while curr != from_id:
		path.push_front(curr)
		var r: RegionRoute = prev_route[curr]
		route_list.push_front(r.id)
		total_ticks += r.travel_ticks
		total_cost += r.supply_cost_coin
		curr = prev_region[curr]

	path.push_front(from_id)

	return {
		"ok": true,
		"path": path,
		"routes": route_list,
		"total_ticks": total_ticks,
		"total_supply_cost": total_cost
	}

func transfer_control(
	region_id: StringName,
	new_controller: StringName,
	reason: String,
	current_tick: int,
	force: bool = false
) -> Dictionary:
	if not regions.has(region_id):
		return {"ok": false, "reason": "Region '%s' does not exist" % region_id}

	var reg: RegionState = regions[region_id]
	if reg.controlling_faction == new_controller and reg.occupying_faction == &"":
		return {"ok": false, "reason": "Faction '%s' already controls region '%s'" % [new_controller, region_id]}

	if not force:
		if new_controller != &"" and not FactionCatalog.FACTION_IDS.has(new_controller):
			return {"ok": false, "reason": "Unrecognized faction '%s'" % new_controller}
		if reason.is_empty():
			return {"ok": false, "reason": "Valid diplomatic/strategic justification required for control transfer"}

	var prev: StringName = reg.controlling_faction
	reg.set_control(new_controller, reason, current_tick, true)

	return {
		"ok": true,
		"region_id": region_id,
		"previous_controller": prev,
		"new_controller": new_controller,
		"reason": reason
	}

func set_occupation(
	region_id: StringName,
	occupier: StringName,
	reason: String,
	current_tick: int
) -> Dictionary:
	if not regions.has(region_id):
		return {"ok": false, "reason": "Region '%s' does not exist" % region_id}

	var reg: RegionState = regions[region_id]
	if occupier != &"" and not FactionCatalog.FACTION_IDS.has(occupier):
		return {"ok": false, "reason": "Unrecognized occupier faction '%s'" % occupier}

	if occupier == &"":
		reg.clear_occupation(reason, current_tick)
	else:
		reg.set_occupation(occupier, reason, current_tick)

	return {"ok": true, "region_id": region_id, "occupier": occupier}

# =========================================================================
# REGIONAL ARMY MANAGEMENT & SIMULATION
# =========================================================================

func get_army(army_id: int) -> ArmyState:
	return armies.get(army_id, null)

func get_armies_for_region(region_id: StringName) -> Array[ArmyState]:
	var res: Array[ArmyState] = []
	for a in armies.values():
		if a.is_active() and a.current_region_id == region_id:
			res.append(a)
	return res

func create_army(
	faction_id: StringName,
	army_name: String,
	region_id: StringName,
	roster: Dictionary,
	supplies: int,
	current_tick: int
) -> ArmyState:
	if not FactionCatalog.FACTION_IDS.has(faction_id):
		return null
	if not regions.has(region_id):
		return null

	var reg: RegionState = regions[region_id]
	# An army can only be assembled in a region controlled by the faction, friendly territory, or unclaimed buffer
	if reg.controlling_faction != &"" and reg.controlling_faction != faction_id:
		# Check if occupied by this faction
		if reg.occupying_faction != faction_id:
			return null

	var army := ArmyState.new(
		next_army_id,
		faction_id,
		army_name,
		region_id,
		roster,
		supplies,
		current_tick
	)
	next_army_id += 1
	armies[army.id] = army
	return army

func issue_march_order(
	army_id: int,
	destination_id: StringName,
	current_tick: int,
	diplomacy: DiplomacyState = null
) -> Dictionary:
	var army: ArmyState = get_army(army_id)
	if army == null or not army.is_active():
		return {"ok": false, "reason": "Army not found or inactive"}

	if not regions.has(destination_id):
		return {"ok": false, "reason": "Destination region '%s' does not exist" % destination_id}

	var dest_reg: RegionState = regions[destination_id]

	# Peace / Ceasefire constraints
	if diplomacy != null and dest_reg.controlling_faction != &"" and dest_reg.controlling_faction != army.faction_id:
		var dest_fac: StringName = dest_reg.controlling_faction
		var active_war: WarState = diplomacy.get_active_war(army.faction_id, dest_fac)
		var is_open_war: bool = (active_war != null and active_war.status == WarState.STATUS_WAR)
		var rel: DiplomaticRelationship = diplomacy.get_relationship(army.faction_id, dest_fac)
		var is_allied: bool = (rel != null and rel.trust >= 50.0) # Allied access permitted

		if not is_open_war and not is_allied:
			return {
				"ok": false,
				"reason": "Cannot march into sovereign territory of %s during peace or ceasefire" % str(dest_fac)
			}

	# Destination is current region: Halt
	if destination_id == army.current_region_id:
		return halt_army(army_id, "Ordered to hold current region", current_tick)

	# If already marching to this exact destination, do NOT reset progress
	if army.status in [ArmyState.STATUS_MARCHING, ArmyState.STATUS_SUPPLY_STRAINED] and army.destination_region_id == destination_id:
		return {
			"ok": true,
			"path": army.route_path,
			"resumed": true,
			"status": army.status
		}

	# Pathfinding
	var route_res: Dictionary = find_route(army.current_region_id, destination_id)
	if not route_res["ok"]:
		return {"ok": false, "reason": route_res.get("reason", "No accessible route found")}

	var path: Array[StringName] = []
	for p in route_res["path"]:
		path.append(StringName(p))

	army.destination_region_id = destination_id
	army.route_path = path
	army.path_index = 0
	army.segment_ticks_progress = 0.0

	var first_step: StringName = path[1]
	var seg_route: RegionRoute = get_route_between(path[0], first_step)
	army.segment_total_ticks = seg_route.travel_ticks if seg_route != null else 60

	if army.supplies.get(&"grain", 0.0) > 0.0:
		army.transition_to(ArmyState.STATUS_MARCHING, "March order issued to %s" % str(destination_id), current_tick)
	else:
		army.transition_to(ArmyState.STATUS_SUPPLY_STRAINED, "March order issued without supplies", current_tick)

	army.record_event(current_tick, "march_order", "Order received to march to %s via %s." % [str(destination_id), str(path)])
	return {
		"ok": true,
		"path": path,
		"total_ticks": route_res["total_ticks"],
		"total_supply_cost": route_res["total_supply_cost"]
	}

func halt_army(army_id: int, reason: String, current_tick: int) -> Dictionary:
	var army: ArmyState = get_army(army_id)
	if army == null:
		return {"ok": false, "reason": "Army not found"}

	army.destination_region_id = army.current_region_id
	army.route_path.clear()
	army.path_index = 0
	army.segment_ticks_progress = 0.0
	army.segment_total_ticks = 0
	army.transition_to(ArmyState.STATUS_GARRISONED, reason, current_tick)
	army.record_event(current_tick, "halted", reason)
	return {"ok": true, "status": army.status}

func resupply_army(
	army_id: int,
	source_type: String,
	source_obj: Variant,
	amount: int,
	current_tick: int
) -> Dictionary:
	var army: ArmyState = get_army(army_id)
	if army == null:
		return {"ok": false, "reason": "Army not found"}

	var transferred: int = 0
	if source_type == "regional_stockpile":
		var reg: RegionState = source_obj as RegionState
		if reg == null:
			return {"ok": false, "reason": "Invalid regional stockpile source"}
		var available: int = reg.get_resource_stock(&"grain")
		var room: int = int(maxf(0.0, float(army.max_supply_capacity) - army.get_supplies(&"grain")))
		transferred = mini(amount, mini(available, room))
		if transferred > 0:
			reg.regional_resources[&"grain"] = available - transferred
			army.add_supplies(&"grain", transferred, current_tick)
	elif source_type == "local_inventory":
		var inv: Inventory = source_obj as Inventory
		if inv == null:
			return {"ok": false, "reason": "Invalid inventory source"}
		var available: int = inv.get_available_outgoing(&"grain")
		var room: int = int(maxf(0.0, float(army.max_supply_capacity) - army.get_supplies(&"grain")))
		transferred = mini(amount, mini(available, room))
		if transferred > 0:
			inv.remove_resource(&"grain", transferred, "Regional Army Resupply")
			army.add_supplies(&"grain", transferred, current_tick)
	else:
		return {"ok": false, "reason": "Unsupported source type '%s'" % source_type}

	return {
		"ok": true,
		"transferred": transferred,
		"army_supplies": army.get_supplies(&"grain"),
		"status": army.status
	}

func check_supply_line(army_id: int, diplomacy: DiplomacyState = null) -> Dictionary:
	var army: ArmyState = get_army(army_id)
	if army == null:
		return {"connected": false, "reason": "Army not found"}

	var curr_reg: RegionState = regions.get(army.current_region_id, null)
	if curr_reg == null:
		army.supply_line_connected = false
		return {"connected": false, "reason": "Current region invalid"}

	# A friendly base is a region controlled by the army's faction with a settlement
	var friendly_bases: Array[StringName] = []
	for r_id in regions:
		var r: RegionState = regions[r_id]
		if r.controlling_faction == army.faction_id and r.has_settlement():
			friendly_bases.append(r.id)

	if friendly_bases.is_empty():
		army.supply_line_connected = false
		return {"connected": false, "reason": "No friendly settlement base exists in realm"}

	if friendly_bases.has(army.current_region_id):
		army.supply_line_connected = true
		army.supply_source_region_id = army.current_region_id
		return {"connected": true, "source": army.current_region_id, "path": [army.current_region_id]}

	# Trace path to any friendly base via open routes, avoiding belligerent territory
	for base_id in friendly_bases:
		var avoid_factions: Array = []
		if diplomacy != null:
			for f_id in diplomacy.factions:
				if diplomacy.has_active_war(army.faction_id, f_id):
					avoid_factions.append(f_id)

		var path_res: Dictionary = find_route(army.current_region_id, base_id, {
			"ignore_closed": false,
			"avoid_factions": avoid_factions
		})

		if path_res["ok"]:
			army.supply_line_connected = true
			army.supply_source_region_id = base_id
			return {
				"connected": true,
				"source": base_id,
				"path": path_res["path"]
			}

	army.supply_line_connected = false
	army.supply_source_region_id = &""
	return {
		"connected": false,
		"reason": "Supply line severed: No open, secure path to friendly base"
	}

func tick_regional_armies(current_tick: int, diplomacy: DiplomacyState = null) -> void:
	for army in armies.values():
		if not army.is_active():
			continue

		var is_marching: bool = (army.status in [ArmyState.STATUS_MARCHING, ArmyState.STATUS_SUPPLY_STRAINED, ArmyState.STATUS_RETREATING] and not army.route_path.is_empty())
		army.consume_supplies(is_marching, current_tick)

		# Supply line connectivity check
		check_supply_line(army.id, diplomacy)

		if not is_marching:
			continue

		# Process active route segment
		if army.path_index >= army.route_path.size() - 1:
			# Arrived at destination
			army.current_region_id = army.destination_region_id
			army.route_path.clear()
			army.path_index = 0
			army.transition_to(ArmyState.STATUS_GARRISONED, "Reached destination", current_tick)
			continue

		var from_node: StringName = army.route_path[army.path_index]
		var to_node: StringName = army.route_path[army.path_index + 1]
		var active_route: RegionRoute = get_route_between(from_node, to_node)

		if active_route == null or not active_route.is_open:
			# Route blocked! Attempt deterministic detour
			var detour_res: Dictionary = find_route(from_node, army.destination_region_id)
			if detour_res["ok"] and detour_res["path"].size() >= 2:
				var new_path: Array[StringName] = []
				for p in detour_res["path"]:
					new_path.append(StringName(p))
				army.route_path = new_path
				army.path_index = 0
				army.segment_ticks_progress = 0.0
				var new_route: RegionRoute = get_route_between(new_path[0], new_path[1])
				army.segment_total_ticks = new_route.travel_ticks if new_route != null else 60
				army.record_event(current_tick, "detour", "Route to %s blocked; detouring via %s." % [str(to_node), str(new_path[1])])
				to_node = new_path[1]
				active_route = new_route
			else:
				# Cannot detour: Halt
				army.transition_to(ArmyState.STATUS_GARRISONED, "Route to %s blocked; no detour available" % str(to_node), current_tick)
				army.blocked_reason = "Blocked route between %s and %s" % [str(from_node), str(to_node)]
				army.route_path.clear()
				continue

		# Movement speed calculation
		var target_reg: RegionState = regions.get(to_node, null)
		var terrain_factor: float = target_reg.travel_difficulty if target_reg != null else 1.0
		var supply_speed_penalty: float = 0.5 if army.status == ArmyState.STATUS_SUPPLY_STRAINED else 1.0

		army.segment_ticks_progress += (1.0 / maxf(0.1, terrain_factor)) * supply_speed_penalty

		if army.segment_ticks_progress >= float(army.segment_total_ticks):
			# Step into next region
			army.path_index += 1
			army.current_region_id = to_node
			army.segment_ticks_progress = 0.0
			army.record_event(current_tick, "region_entered", "Arrived at %s." % str(to_node))

			if army.current_region_id == army.destination_region_id:
				# Final destination reached!
				army.route_path.clear()
				army.path_index = 0
				var arr_reason: String = "Retreat completed at %s" % str(to_node) if army.status == ArmyState.STATUS_RETREATING else ("Arrived at destination %s" % str(to_node))
				army.transition_to(ArmyState.STATUS_GARRISONED, arr_reason, current_tick)
			else:
				# Setup next segment
				var next_target: StringName = army.route_path[army.path_index + 1]
				var next_route: RegionRoute = get_route_between(army.current_region_id, next_target)
				army.segment_total_ticks = next_route.travel_ticks if next_route != null else 60

# =========================================================================
# CAMPAIGN OBJECTIVES & REGIONAL ENGAGEMENTS
# =========================================================================

func get_objective(obj_id: int) -> CampaignObjective:
	return objectives.get(obj_id, null)

func get_active_objectives(faction: StringName = &"") -> Array[CampaignObjective]:
	var res: Array[CampaignObjective] = []
	for obj in objectives.values():
		if obj.status == CampaignObjective.STATUS_IN_PROGRESS:
			if faction == &"" or obj.faction_id == faction:
				res.append(obj)
	return res

func create_objective(
	p_faction: StringName,
	p_type: StringName,
	p_target_region: StringName = &"",
	p_target_army: int = 0,
	p_war_id: int = -1,
	p_tick: int = 0
) -> CampaignObjective:
	var desc: String = ""
	match p_type:
		CampaignObjective.TYPE_DEFEND_REGION:
			desc = "Defend %s against hostile incursions" % str(p_target_region)
		CampaignObjective.TYPE_OCCUPY_REGION:
			desc = "Occupy and secure %s" % str(p_target_region)
		CampaignObjective.TYPE_CONTEST_REGION:
			desc = "Contest control of %s" % str(p_target_region)
		CampaignObjective.TYPE_REPEL_ARMY:
			desc = "Repel hostile army %d from the theater" % p_target_army
		CampaignObjective.TYPE_SECURE_ROUTE:
			desc = "Secure supply and travel route through %s" % str(p_target_region)
		_:
			desc = "Military objective for %s" % str(p_faction)

	var obj := CampaignObjective.new(
		next_objective_id,
		p_faction,
		p_type,
		desc,
		p_target_region,
		p_target_army,
		p_war_id,
		p_tick
	)
	next_objective_id += 1
	objectives[obj.id] = obj
	return obj

func get_engagement(eng_id: int) -> RegionalEngagement:
	return engagements.get(eng_id, null)

func get_engagements_for_region(region_id: StringName) -> Array[RegionalEngagement]:
	var res: Array[RegionalEngagement] = []
	for eng in engagements.values():
		if eng.region_id == region_id:
			res.append(eng)
	return res

func detect_and_resolve_engagements(diplomacy: DiplomacyState, current_tick: int) -> Array[RegionalEngagement]:
	var resolved_engagements: Array[RegionalEngagement] = []
	if diplomacy == null:
		return resolved_engagements

	for reg_id in regions:
		var reg: RegionState = regions[reg_id]
		var armies_in_reg: Array[ArmyState] = []
		for a in armies.values():
			if a.is_active() and a.current_region_id == reg_id and a.status != ArmyState.STATUS_RETREATING and a.status != ArmyState.STATUS_ENGAGED:
				armies_in_reg.append(a)

		if armies_in_reg.size() < 2:
			continue

		var factions_present: Array[StringName] = []
		for a in armies_in_reg:
			if not factions_present.has(a.faction_id):
				factions_present.append(a.faction_id)

		if factions_present.size() < 2:
			continue

		for i in range(factions_present.size()):
			var f_a: StringName = factions_present[i]
			for j in range(i + 1, factions_present.size()):
				var f_b: StringName = factions_present[j]
				var war: WarState = diplomacy.get_active_war(f_a, f_b)
				if war == null or war.status != WarState.STATUS_WAR:
					continue

				var army_a: ArmyState = null
				var army_b: ArmyState = null
				for a in armies_in_reg:
					if a.faction_id == f_a and a.is_active() and a.status != ArmyState.STATUS_RETREATING and army_a == null:
						army_a = a
					elif a.faction_id == f_b and a.is_active() and a.status != ArmyState.STATUS_RETREATING and army_b == null:
						army_b = a

				if army_a == null or army_b == null:
					continue

				# Check cooldown between these armies in this region (30 ticks)
				var recently_engaged: bool = false
				for prev_eng in engagements.values():
					if prev_eng.region_id == reg_id and prev_eng.is_resolved():
						if (prev_eng.attacker_army_id == army_a.id and prev_eng.defender_army_id == army_b.id) or (prev_eng.attacker_army_id == army_b.id and prev_eng.defender_army_id == army_a.id):
							if current_tick - prev_eng.resolution_tick < 30:
								recently_engaged = true
								break
				if recently_engaged:
					continue

				var att: ArmyState = army_a
				var def: ArmyState = army_b
				if reg.get_effective_controller() == f_a:
					def = army_a
					att = army_b
				elif reg.get_effective_controller() == f_b:
					def = army_b
					att = army_a
				elif army_a.status == ArmyState.STATUS_GARRISONED and army_b.status != ArmyState.STATUS_GARRISONED:
					def = army_a
					att = army_b
				elif army_b.status == ArmyState.STATUS_GARRISONED and army_a.status != ArmyState.STATUS_GARRISONED:
					def = army_b
					att = army_a

				var eng := RegionalEngagement.new(
					next_engagement_id,
					reg_id,
					att.id,
					att.faction_id,
					def.id,
					def.faction_id,
					war.id,
					current_tick
				)
				next_engagement_id += 1
				engagements[eng.id] = eng

				att.transition_to(ArmyState.STATUS_ENGAGED, "Engaging %s forces at %s" % [str(def.faction_id), reg.display_name], current_tick)
				def.transition_to(ArmyState.STATUS_ENGAGED, "Defending against %s at %s" % [str(att.faction_id), reg.display_name], current_tick)

				var att_supp_factor: float = 1.15 if att.get_supplies(&"grain") >= 15.0 else (0.70 if att.get_supplies(&"grain") <= 0.0 or att.status == ArmyState.STATUS_SUPPLY_STRAINED else 1.0)
				var def_supp_factor: float = 1.15 if def.get_supplies(&"grain") >= 15.0 else (0.70 if def.get_supplies(&"grain") <= 0.0 or def.status == ArmyState.STATUS_SUPPLY_STRAINED else 1.0)
				var terrain_factor: float = reg.defensive_advantage
				eng.record_initial_metrics(att.strength, def.strength, att_supp_factor, def_supp_factor, terrain_factor)

				var result: Dictionary = resolve_regional_engagement(eng.id, diplomacy, current_tick)
				if result.get("ok", false):
					resolved_engagements.append(eng)

	return resolved_engagements

func resolve_regional_engagement(eng_id: int, diplomacy: DiplomacyState, current_tick: int) -> Dictionary:
	var eng: RegionalEngagement = engagements.get(eng_id, null)
	if eng == null:
		return {"ok": false, "reason": "Engagement not found"}
	if eng.state == RegionalEngagement.STATE_RESOLVED:
		return {"ok": false, "reason": "Engagement already resolved"}

	var att: ArmyState = armies.get(eng.attacker_army_id, null)
	var def: ArmyState = armies.get(eng.defender_army_id, null)
	var reg: RegionState = regions.get(eng.region_id, null)

	if att == null or def == null:
		eng.resolve_engagement(RegionalEngagement.OUTCOME_STALEMATE, 0, 0, current_tick)
		return {"ok": false, "reason": "Missing army participants"}

	# Power calculations
	var P_att: float = float(att.strength) * eng.attacker_supply_factor
	var P_def: float = float(def.strength) * eng.defender_supply_factor * eng.terrain_defensive_factor
	var total_P: float = P_att + P_def
	var ratio: float = P_att / maxf(1.0, total_P)

	var outcome: StringName = RegionalEngagement.OUTCOME_STALEMATE
	if ratio > 0.55:
		outcome = RegionalEngagement.OUTCOME_ATTACKER_VICTORY
	elif ratio < 0.45:
		outcome = RegionalEngagement.OUTCOME_DEFENDER_VICTORY
	else:
		outcome = RegionalEngagement.OUTCOME_STALEMATE

	# Bounded casualties (20% to 45%)
	var att_loss_pct: float = clampf(0.20 + (1.0 - ratio) * 0.25, 0.20, 0.45)
	var def_loss_pct: float = clampf(0.20 + ratio * 0.25, 0.20, 0.45)

	var att_losses: int = clampi(int(round(float(att.strength) * att_loss_pct)), 1, att.strength)
	var def_losses: int = clampi(int(round(float(def.strength) * def_loss_pct)), 1, def.strength)

	# Apply casualties exactly once
	var actual_att_losses: int = att.apply_casualties(att_losses, "Battle of %s" % (reg.display_name if reg != null else str(eng.region_id)), current_tick)
	var actual_def_losses: int = def.apply_casualties(def_losses, "Battle of %s" % (reg.display_name if reg != null else str(eng.region_id)), current_tick)

	# Register single casualty accounting in WarState
	var war: WarState = null
	if diplomacy != null:
		war = diplomacy.get_war_by_id(eng.war_id)
		if war == null:
			war = diplomacy.get_active_war(att.faction_id, def.faction_id)

	if war != null:
		war.record_casualty(att.faction_id, actual_att_losses)
		war.record_casualty(def.faction_id, actual_def_losses)
		var battle_desc: String = "Battle of %s: %s (%d casualties) vs %s (%d casualties)" % [
			reg.display_name if reg != null else str(eng.region_id),
			att.name, actual_att_losses,
			def.name, actual_def_losses
		]
		war.record_battle(current_tick, battle_desc, actual_att_losses, actual_def_losses, outcome)

	if diplomacy != null:
		var outcome_text: String = "attacker victory" if outcome == RegionalEngagement.OUTCOME_ATTACKER_VICTORY else ("defender victory" if outcome == RegionalEngagement.OUTCOME_DEFENDER_VICTORY else "stalemate")
		diplomacy.add_chronicle(current_tick, "Engagement at %s concluded with %s: %s lost %d, %s lost %d troops." % [
			reg.display_name if reg != null else str(eng.region_id),
			outcome_text,
			att.name, actual_att_losses,
			def.name, actual_def_losses
		], &"battle")

	# Post-engagement consequences & retreat handling
	if outcome == RegionalEngagement.OUTCOME_ATTACKER_VICTORY:
		if att.strength > 0:
			att.transition_to(ArmyState.STATUS_GARRISONED, "Victorious in battle at %s" % (reg.display_name if reg != null else ""), current_tick)
		if reg != null:
			if reg.controlling_faction != att.faction_id:
				reg.set_occupation(att.faction_id, "Occupied following military victory in battle", current_tick)
			else:
				reg.clear_occupation("Liberated by friendly forces", current_tick)
		if def.strength > 0:
			_order_retreat(def, reg, current_tick)

	elif outcome == RegionalEngagement.OUTCOME_DEFENDER_VICTORY:
		if def.strength > 0:
			def.transition_to(ArmyState.STATUS_GARRISONED, "Successfully defended %s" % (reg.display_name if reg != null else ""), current_tick)
		if reg != null and reg.occupying_faction == att.faction_id:
			reg.clear_occupation("Occupier repelled by defender victory", current_tick)
		if att.strength > 0:
			_order_retreat(att, reg, current_tick)

	else: # STALEMATE
		if att.strength > 0:
			att.transition_to(ArmyState.STATUS_GARRISONED, "Stalemate at %s" % (reg.display_name if reg != null else ""), current_tick)
		if def.strength > 0:
			def.transition_to(ArmyState.STATUS_GARRISONED, "Stalemate at %s" % (reg.display_name if reg != null else ""), current_tick)
		if reg != null:
			reg.set_contested(true)

	eng.resolve_engagement(outcome, actual_att_losses, actual_def_losses, current_tick)

	return {
		"ok": true,
		"engagement_id": eng_id,
		"outcome": outcome,
		"attacker_losses": actual_att_losses,
		"defender_losses": actual_def_losses
	}

func _order_retreat(army: ArmyState, current_region: RegionState, current_tick: int) -> void:
	if current_region == null:
		return

	var best_dest: StringName = &""
	var neighbors: Array[StringName] = current_region.neighbors

	# Priority 1: Adjacent region controlled by own faction with open route
	for n_id in neighbors:
		var n_reg: RegionState = regions.get(n_id, null)
		var r: RegionRoute = get_route_between(current_region.id, n_id)
		if n_reg != null and r != null and r.is_open:
			if n_reg.controlling_faction == army.faction_id and n_reg.occupying_faction == &"":
				best_dest = n_id
				break

	# Priority 2: Adjacent unclaimed or buffer region with open route
	if best_dest == &"":
		for n_id in neighbors:
			var n_reg: RegionState = regions.get(n_id, null)
			var r: RegionRoute = get_route_between(current_region.id, n_id)
			if n_reg != null and r != null and r.is_open:
				if n_reg.controlling_faction == &"":
					best_dest = n_id
					break

	# Priority 3: Any adjacent region with open route
	if best_dest == &"":
		for n_id in neighbors:
			var r: RegionRoute = get_route_between(current_region.id, n_id)
			if r != null and r.is_open:
				best_dest = n_id
				break

	if best_dest != &"":
		army.destination_region_id = best_dest
		army.route_path = [current_region.id, best_dest]
		army.path_index = 0
		army.segment_ticks_progress = 0.0
		var route: RegionRoute = get_route_between(current_region.id, best_dest)
		army.segment_total_ticks = route.travel_ticks if route != null else 60
		army.transition_to(ArmyState.STATUS_RETREATING, "Retreating to %s" % str(best_dest), current_tick)
	else:
		army.apply_casualties(army.strength, "Cut off with no retreat route available", current_tick)

func update_campaign_objectives(diplomacy: DiplomacyState, current_tick: int) -> void:
	for obj in objectives.values():
		if obj.status != CampaignObjective.STATUS_IN_PROGRESS:
			continue

		var war: WarState = null
		if diplomacy != null and obj.war_id > 0:
			war = diplomacy.get_war_by_id(obj.war_id)

		var reg: RegionState = regions.get(obj.target_region_id, null)

		match obj.type:
			CampaignObjective.TYPE_DEFEND_REGION:
				if reg != null:
					if reg.occupying_faction != &"" and reg.occupying_faction != obj.faction_id:
						obj.fail("Target region was occupied by enemy forces", current_tick)
					elif war != null and not war.is_active():
						if reg.controlling_faction == obj.faction_id and reg.occupying_faction == &"":
							obj.complete("Region defended successfully through campaign conclusion", current_tick)
						else:
							obj.fail("Region lost at campaign conclusion", current_tick)
					elif obj.target_tick > 0 and current_tick >= obj.target_tick:
						if reg.controlling_faction == obj.faction_id and reg.occupying_faction == &"":
							obj.complete("Region defended for designated duration", current_tick)

			CampaignObjective.TYPE_OCCUPY_REGION:
				if reg != null:
					if reg.occupying_faction == obj.faction_id:
						obj.complete("Target region occupied successfully", current_tick)
					elif war != null and not war.is_active():
						obj.fail("War concluded before target region could be occupied", current_tick)

			CampaignObjective.TYPE_CONTEST_REGION:
				if reg != null:
					if reg.is_contested or reg.occupying_faction == obj.faction_id:
						obj.complete("Target region successfully contested", current_tick)
					elif war != null and not war.is_active():
						obj.fail("War ended before region contested", current_tick)

			CampaignObjective.TYPE_REPEL_ARMY:
				var target_army: ArmyState = armies.get(obj.target_army_id, null)
				if target_army == null or not target_army.is_active() or target_army.status == ArmyState.STATUS_DESTROYED:
					obj.complete("Target hostile army destroyed", current_tick)
				elif reg != null and target_army.current_region_id != reg.id and target_army.status == ArmyState.STATUS_RETREATING:
					obj.complete("Target hostile army repelled from region", current_tick)
				elif war != null and not war.is_active():
					obj.complete("War concluded with enemy force repelled", current_tick)

			CampaignObjective.TYPE_SECURE_ROUTE:
				if reg != null:
					var secure: bool = true
					var r_list: Array[RegionRoute] = get_routes_for_region(reg.id)
					for r in r_list:
						if not r.is_open:
							secure = false
							break
					if secure and reg.controlling_faction == obj.faction_id:
						obj.complete("Supply route secured", current_tick)

# =========================================================================
# REGIONAL TRADE CONVOYS & ECONOMIC LOGISTICS
# =========================================================================

func get_contract(contract_id: int) -> TradeContract:
	return contracts.get(contract_id, null)

func get_shipment(shipment_id: int) -> TradeShipment:
	return shipments.get(shipment_id, null)

func get_active_contracts(faction_id: StringName = &"") -> Array[TradeContract]:
	var res: Array[TradeContract] = []
	for c in contracts.values():
		if c.is_active():
			if faction_id == &"" or c.buyer_faction_id == faction_id or c.seller_faction_id == faction_id:
				res.append(c)
	return res

func get_active_shipments(faction_id: StringName = &"") -> Array[TradeShipment]:
	var res: Array[TradeShipment] = []
	for s in shipments.values():
		if s.is_active():
			if faction_id == &"" or s.carrier_faction_id == faction_id:
				res.append(s)
	return res

func get_shipments_for_region(region_id: StringName) -> Array[TradeShipment]:
	var res: Array[TradeShipment] = []
	for s in shipments.values():
		if s.is_active() and s.current_region_id == region_id:
			res.append(s)
	return res

func create_trade_contract(
	p_buyer: StringName,
	p_seller: StringName,
	p_resource: StringName,
	p_amount: int,
	p_total_price: int,
	p_origin: StringName,
	p_dest: StringName,
	p_tick: int
) -> TradeContract:
	if p_buyer == p_seller or p_buyer == &"" or p_seller == &"":
		return null
	if not FactionCatalog.FACTION_IDS.has(p_buyer) or not FactionCatalog.FACTION_IDS.has(p_seller):
		return null
	if p_amount <= 0 or p_total_price < 0:
		return null
	if not regions.has(p_origin) or not regions.has(p_dest) or p_origin == p_dest:
		return null

	var c := TradeContract.new(
		next_contract_id,
		p_buyer,
		p_seller,
		p_resource,
		p_amount,
		p_total_price,
		p_origin,
		p_dest,
		p_tick
	)
	next_contract_id += 1
	contracts[c.id] = c
	return c

func accept_trade_contract(
	contract_id: int,
	player_inventory: Inventory,
	diplomacy: DiplomacyState,
	current_tick: int
) -> Dictionary:
	var c: TradeContract = get_contract(contract_id)
	if c == null:
		return {"ok": false, "reason": "Contract not found"}
	if c.status != TradeContract.STATUS_OFFERED:
		return {"ok": false, "reason": "Contract is not in offered state"}

	# 1. War check between buyer and seller
	if diplomacy != null and diplomacy.has_active_war(c.buyer_faction_id, c.seller_faction_id):
		var war: WarState = diplomacy.get_active_war(c.buyer_faction_id, c.seller_faction_id)
		if war != null and war.status == WarState.STATUS_WAR:
			c.transition_to(TradeContract.STATUS_FAILED, "Trade prohibited while at war", current_tick)
			return {"ok": false, "reason": "Trade prohibited while at war"}

	# 2. Route validation
	var route_res: Dictionary = find_route(c.origin_region_id, c.destination_region_id)
	if not route_res["ok"]:
		c.transition_to(TradeContract.STATUS_FAILED, "No accessible route between trading regions", current_tick)
		return {"ok": false, "reason": "No accessible route between %s and %s" % [str(c.origin_region_id), str(c.destination_region_id)]}

	# 3. Seller goods availability check
	if c.seller_faction_id == FactionCatalog.FACTION_PLAYER:
		if player_inventory == null or player_inventory.get_available_outgoing(c.resource_id) < c.resource_amount:
			return {"ok": false, "reason": "Insufficient goods in storage to fulfill trade"}
	else:
		var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null) if diplomacy != null else null
		if seller_fac == null or seller_fac.get_available_resource(c.resource_id) < c.resource_amount:
			return {"ok": false, "reason": "Seller possesses insufficient resource stock"}

	# 4. Buyer payment availability check
	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER:
		if player_inventory == null or player_inventory.get_available_outgoing(&"coin") < c.total_price:
			return {"ok": false, "reason": "Insufficient coins in storage to purchase goods"}
	else:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null) if diplomacy != null else null
		if buyer_fac == null or buyer_fac.get_available_treasury() < c.total_price:
			return {"ok": false, "reason": "Buyer possesses insufficient treasury funds"}

	# 5. Destination storage capacity check
	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER:
		if player_inventory == null or not player_inventory.can_accept(c.resource_id, c.resource_amount):
			return {"ok": false, "reason": "Insufficient storage capacity to receive trade goods"}

	# 6. Apply atomic reservations
	if c.seller_faction_id == FactionCatalog.FACTION_PLAYER:
		player_inventory.reserve_out(c.resource_id, c.resource_amount)
	else:
		var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null)
		seller_fac.reserve_resource(c.resource_id, c.resource_amount)

	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER:
		player_inventory.reserve_out(&"coin", c.total_price)
		player_inventory.reserve_in(c.resource_id, c.resource_amount)
	else:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null)
		buyer_fac.reserve_treasury(c.total_price)

	c.transition_to(TradeContract.STATUS_ACCEPTED, "", current_tick)
	c.status = TradeContract.STATUS_RESERVED

	# 7. Create shipment & load cargo
	var loaded_cargo: Dictionary = {c.resource_id: c.resource_amount}
	if c.seller_faction_id == FactionCatalog.FACTION_PLAYER:
		player_inventory.remove_resource(c.resource_id, c.resource_amount, "TRADE SHIPMENT LOADED", true)
	else:
		var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null)
		seller_fac.resources[c.resource_id] = maxi(0, int(seller_fac.resources.get(c.resource_id, 0)) - c.resource_amount)
		seller_fac.release_reserved_resource(c.resource_id, c.resource_amount)

	var shipment := TradeShipment.new(
		next_shipment_id,
		c.id,
		c.seller_faction_id,
		c.origin_region_id,
		c.destination_region_id,
		loaded_cargo,
		current_tick
	)
	next_shipment_id += 1

	var path: Array[StringName] = []
	for p in route_res["path"]:
		path.append(StringName(p))

	shipment.route_path = path
	shipment.path_index = 0
	shipment.segment_ticks_progress = 0.0
	var first_step: StringName = path[1]
	var seg_route: RegionRoute = get_route_between(path[0], first_step)
	shipment.segment_total_ticks = seg_route.travel_ticks if seg_route != null else 60

	shipment.transition_to(TradeShipment.STATUS_IN_TRANSIT, "Caravan departed origin", current_tick)
	c.shipment_id = shipment.id
	c.transition_to(TradeContract.STATUS_IN_TRANSIT, "", current_tick)
	shipments[shipment.id] = shipment

	return {
		"ok": true,
		"contract_id": c.id,
		"shipment_id": shipment.id,
		"route": path,
		"total_ticks": route_res["total_ticks"]
	}

func tick_regional_trade_shipments(
	current_tick: int,
	diplomacy: DiplomacyState = null,
	player_inventory: Inventory = null
) -> void:
	for shipment in shipments.values():
		if not shipment.is_active():
			continue

		if shipment.status == TradeShipment.STATUS_IN_TRANSIT:
			if shipment.path_index >= shipment.route_path.size() - 1:
				shipment.current_region_id = shipment.destination_region_id
				shipment.route_path.clear()
				shipment.path_index = 0
				shipment.transition_to(TradeShipment.STATUS_DELIVERED, "Arrived at destination", current_tick)
				deliver_and_settle_contract(shipment.contract_id, player_inventory, diplomacy, current_tick)
				continue

			var from_node: StringName = shipment.route_path[shipment.path_index]
			var to_node: StringName = shipment.route_path[shipment.path_index + 1]
			var active_route: RegionRoute = get_route_between(from_node, to_node)

			# War restriction on target region
			var dest_reg: RegionState = regions.get(to_node, null)
			if diplomacy != null and dest_reg != null and dest_reg.controlling_faction != &"":
				if diplomacy.has_active_war(shipment.carrier_faction_id, dest_reg.controlling_faction):
					var war: WarState = diplomacy.get_active_war(shipment.carrier_faction_id, dest_reg.controlling_faction)
					if war != null and war.status == WarState.STATUS_WAR:
						active_route = null

			if active_route == null or not active_route.is_open:
				var detour_res: Dictionary = find_route(from_node, shipment.destination_region_id)
				if detour_res["ok"] and detour_res["path"].size() >= 2:
					var new_path: Array[StringName] = []
					for p in detour_res["path"]:
						new_path.append(StringName(p))
					shipment.route_path = new_path
					shipment.path_index = 0
					shipment.segment_ticks_progress = 0.0
					var new_route: RegionRoute = get_route_between(new_path[0], new_path[1])
					shipment.segment_total_ticks = new_route.travel_ticks if new_route != null else 60
					shipment.record_event(current_tick, "detour", "Route to %s blocked; detouring via %s." % [str(to_node), str(new_path[1])])
					to_node = new_path[1]
					active_route = new_route
				else:
					shipment.transition_to(TradeShipment.STATUS_WAITING_ROUTE, "Route to %s blocked; no detour available" % str(to_node), current_tick)
					shipment.blocked_reason = "Blocked route between %s and %s" % [str(from_node), str(to_node)]
					continue

			var target_reg: RegionState = regions.get(to_node, null)
			var terrain_factor: float = target_reg.travel_difficulty if target_reg != null else 1.0
			shipment.segment_ticks_progress += (1.0 / maxf(0.1, terrain_factor))

			if shipment.segment_ticks_progress >= float(shipment.segment_total_ticks):
				shipment.path_index += 1
				shipment.current_region_id = to_node
				shipment.segment_ticks_progress = 0.0
				shipment.record_event(current_tick, "region_entered", "Caravan entered %s." % str(to_node))

				if shipment.current_region_id == shipment.destination_region_id:
					shipment.route_path.clear()
					shipment.path_index = 0
					shipment.transition_to(TradeShipment.STATUS_DELIVERED, "Arrived at destination %s" % str(to_node), current_tick)
					deliver_and_settle_contract(shipment.contract_id, player_inventory, diplomacy, current_tick)
				else:
					var next_target: StringName = shipment.route_path[shipment.path_index + 1]
					var next_route: RegionRoute = get_route_between(shipment.current_region_id, next_target)
					shipment.segment_total_ticks = next_route.travel_ticks if next_route != null else 60

		elif shipment.status == TradeShipment.STATUS_RETURNING:
			if shipment.current_region_id == shipment.origin_region_id or shipment.route_path.is_empty():
				_finalize_returned_shipment(shipment, player_inventory, diplomacy, current_tick)
				continue

			var from_node: StringName = shipment.route_path[shipment.path_index]
			var to_node: StringName = shipment.route_path[shipment.path_index + 1]
			var active_route: RegionRoute = get_route_between(from_node, to_node)
			if active_route == null or not active_route.is_open:
				var detour_res: Dictionary = find_route(from_node, shipment.origin_region_id)
				if detour_res["ok"] and detour_res["path"].size() >= 2:
					var new_path: Array[StringName] = []
					for p in detour_res["path"]:
						new_path.append(StringName(p))
					shipment.route_path = new_path
					shipment.path_index = 0
					shipment.segment_ticks_progress = 0.0
					var new_route: RegionRoute = get_route_between(new_path[0], new_path[1])
					shipment.segment_total_ticks = new_route.travel_ticks if new_route != null else 60
					to_node = new_path[1]
				else:
					continue

			var target_reg: RegionState = regions.get(to_node, null)
			var terrain_factor: float = target_reg.travel_difficulty if target_reg != null else 1.0
			shipment.segment_ticks_progress += (1.0 / maxf(0.1, terrain_factor))

			if shipment.segment_ticks_progress >= float(shipment.segment_total_ticks):
				shipment.path_index += 1
				shipment.current_region_id = to_node
				shipment.segment_ticks_progress = 0.0
				if shipment.current_region_id == shipment.origin_region_id:
					_finalize_returned_shipment(shipment, player_inventory, diplomacy, current_tick)
				else:
					var next_target: StringName = shipment.route_path[shipment.path_index + 1]
					var next_route: RegionRoute = get_route_between(shipment.current_region_id, next_target)
					shipment.segment_total_ticks = next_route.travel_ticks if next_route != null else 60

func deliver_and_settle_contract(
	contract_id: int,
	player_inventory: Inventory,
	diplomacy: DiplomacyState,
	current_tick: int
) -> Dictionary:
	var c: TradeContract = get_contract(contract_id)
	if c == null:
		return {"ok": false, "reason": "Contract not found"}
	if c.is_settled():
		return {"ok": false, "reason": "Contract already settled"}

	var s: TradeShipment = get_shipment(c.shipment_id)
	if s == null:
		return {"ok": false, "reason": "Shipment not found"}

	# Atomic Goods Delivery
	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER:
		if player_inventory != null:
			player_inventory.add_resource(c.resource_id, c.resource_amount, "TRADE SHIPMENT DELIVERED", true)
	else:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null) if diplomacy != null else null
		if buyer_fac != null:
			buyer_fac.resources[c.resource_id] = int(buyer_fac.resources.get(c.resource_id, 0)) + c.resource_amount

	# Atomic Financial Settlement
	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER:
		if player_inventory != null:
			player_inventory.remove_resource(&"coin", c.total_price, "TRADE CONTRACT SETTLEMENT", true)
		var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null) if diplomacy != null else null
		if seller_fac != null:
			seller_fac.treasury += c.total_price
	else:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null) if diplomacy != null else null
		if buyer_fac != null:
			buyer_fac.treasury = maxi(0, buyer_fac.treasury - c.total_price)
			buyer_fac.release_reserved_treasury(c.total_price)
		if c.seller_faction_id == FactionCatalog.FACTION_PLAYER and player_inventory != null:
			player_inventory.add_resource(&"coin", c.total_price, "TRADE CONTRACT PAYMENT RECEIVED")

	s.cargo.clear()
	s.transition_to(TradeShipment.STATUS_DELIVERED, "Delivered and settled", current_tick)
	c.transition_to(TradeContract.STATUS_SETTLED, "Delivered and settled", current_tick)

	if diplomacy != null:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null)
		var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null)
		var buyer_name: String = buyer_fac.display_name if buyer_fac != null else str(c.buyer_faction_id)
		var seller_name: String = seller_fac.display_name if seller_fac != null else str(c.seller_faction_id)
		diplomacy.add_chronicle(
			current_tick,
			"Trade convoy completed: %s delivered %d %s to %s for %d coins." % [
				seller_name, c.resource_amount, str(c.resource_id).capitalize(), buyer_name, c.total_price
			],
			&"trade_completed"
		)

	return {
		"ok": true,
		"contract_id": c.id,
		"shipment_id": s.id,
		"status": c.status
	}

func cancel_trade_contract(
	contract_id: int,
	reason: String,
	player_inventory: Inventory,
	diplomacy: DiplomacyState,
	current_tick: int
) -> Dictionary:
	var c: TradeContract = get_contract(contract_id)
	if c == null:
		return {"ok": false, "reason": "Contract not found"}
	if c.status in [TradeContract.STATUS_SETTLED, TradeContract.STATUS_CANCELLED, TradeContract.STATUS_FAILED]:
		return {"ok": false, "reason": "Contract already in terminal status"}

	var s: TradeShipment = get_shipment(c.shipment_id)

	# 1. Cancel before dispatch / loading
	if c.status in [TradeContract.STATUS_OFFERED, TradeContract.STATUS_ACCEPTED, TradeContract.STATUS_RESERVED]:
		if c.seller_faction_id == FactionCatalog.FACTION_PLAYER and player_inventory != null:
			player_inventory.release_reserved_out(c.resource_id, c.resource_amount)
		elif diplomacy != null:
			var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null)
			if seller_fac != null:
				seller_fac.release_reserved_resource(c.resource_id, c.resource_amount)

		if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER and player_inventory != null:
			player_inventory.release_reserved_out(&"coin", c.total_price)
			player_inventory.release_reserved_in(c.resource_id, c.resource_amount)
		elif diplomacy != null:
			var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null)
			if buyer_fac != null:
				buyer_fac.release_reserved_treasury(c.total_price)

		c.transition_to(TradeContract.STATUS_CANCELLED, reason, current_tick)
		if s != null:
			s.transition_to(TradeShipment.STATUS_CANCELLED, reason, current_tick)

		return {"ok": true, "contract_id": c.id, "refunded": true}

	# 2. Cancel in transit
	if s != null and s.is_active():
		c.transition_to(TradeContract.STATUS_CANCELLED, reason, current_tick)
		if s.current_region_id == s.origin_region_id:
			_finalize_returned_shipment(s, player_inventory, diplomacy, current_tick)
		else:
			s.transition_to(TradeShipment.STATUS_RETURNING, reason, current_tick)
			var ret_route: Dictionary = find_route(s.current_region_id, s.origin_region_id)
			if ret_route["ok"] and ret_route["path"].size() >= 2:
				var path: Array[StringName] = []
				for p in ret_route["path"]:
					path.append(StringName(p))
				s.route_path = path
				s.path_index = 0
				s.segment_ticks_progress = 0.0
				var seg_route: RegionRoute = get_route_between(path[0], path[1])
				s.segment_total_ticks = seg_route.travel_ticks if seg_route != null else 60
			else:
				_finalize_returned_shipment(s, player_inventory, diplomacy, current_tick)

		return {"ok": true, "contract_id": c.id, "returning": true}

	c.transition_to(TradeContract.STATUS_CANCELLED, reason, current_tick)
	return {"ok": true, "contract_id": c.id}

func _finalize_returned_shipment(
	s: TradeShipment,
	player_inventory: Inventory,
	diplomacy: DiplomacyState,
	current_tick: int
) -> void:
	var c: TradeContract = get_contract(s.contract_id)
	if c == null:
		return

	# Return cargo to seller
	for res_id in s.cargo:
		var amt: int = s.cargo[res_id]
		if amt <= 0:
			continue
		if c.seller_faction_id == FactionCatalog.FACTION_PLAYER and player_inventory != null:
			player_inventory.add_resource(res_id, amt, "TRADE SHIPMENT RETURNED TO STORAGE")
		elif diplomacy != null:
			var seller_fac: FactionState = diplomacy.factions.get(c.seller_faction_id, null)
			if seller_fac != null:
				seller_fac.resources[res_id] = int(seller_fac.resources.get(res_id, 0)) + amt

	s.cargo.clear()
	s.transition_to(TradeShipment.STATUS_RETURNED, "Cargo safely returned to origin", current_tick)

	# Release buyer reservations (refund)
	if c.buyer_faction_id == FactionCatalog.FACTION_PLAYER and player_inventory != null:
		player_inventory.release_reserved_out(&"coin", c.total_price)
		player_inventory.release_reserved_in(c.resource_id, c.resource_amount)
	elif diplomacy != null:
		var buyer_fac: FactionState = diplomacy.factions.get(c.buyer_faction_id, null)
		if buyer_fac != null:
			buyer_fac.release_reserved_treasury(c.total_price)

func serialize() -> Dictionary:
	var reg_dict: Dictionary = {}
	for k in regions:
		reg_dict[str(k)] = regions[k].serialize()
	var route_arr: Array = []
	for r in routes:
		route_arr.append(r.serialize())
	var army_dict: Dictionary = {}
	for k in armies:
		army_dict[str(k)] = armies[k].serialize()
	var obj_dict: Dictionary = {}
	for k in objectives:
		obj_dict[str(k)] = objectives[k].serialize()
	var eng_dict: Dictionary = {}
	for k in engagements:
		eng_dict[str(k)] = engagements[k].serialize()
	var contract_dict: Dictionary = {}
	for k in contracts:
		contract_dict[str(k)] = contracts[k].serialize()
	var shipment_dict: Dictionary = {}
	for k in shipments:
		shipment_dict[str(k)] = shipments[k].serialize()

	return {
		"selected_region_id": str(selected_region_id),
		"next_army_id": next_army_id,
		"next_objective_id": next_objective_id,
		"next_engagement_id": next_engagement_id,
		"next_contract_id": next_contract_id,
		"next_shipment_id": next_shipment_id,
		"regions": reg_dict,
		"routes": route_arr,
		"armies": army_dict,
		"objectives": obj_dict,
		"engagements": eng_dict,
		"contracts": contract_dict,
		"shipments": shipment_dict
	}

static func deserialize(data: Dictionary) -> RegionalWorldState:
	var state := RegionalWorldState.new()
	state.selected_region_id = StringName(data.get("selected_region_id", ""))
	state.next_army_id = int(data.get("next_army_id", 1))
	state.next_objective_id = int(data.get("next_objective_id", 1))
	state.next_engagement_id = int(data.get("next_engagement_id", 1))
	state.next_contract_id = int(data.get("next_contract_id", 1))
	state.next_shipment_id = int(data.get("next_shipment_id", 1))

	state.regions.clear()
	var raw_reg: Dictionary = data.get("regions", {})
	for k in raw_reg:
		var reg: RegionState = RegionState.deserialize(raw_reg[k])
		state.regions[reg.id] = reg

	state.routes.clear()
	var raw_routes: Array = data.get("routes", [])
	for item in raw_routes:
		if item is Dictionary:
			state.routes.append(RegionRoute.deserialize(item))

	# If regions are missing or invalid, generate default initial world
	if state.regions.is_empty():
		state.regions = RegionCatalog.create_default_regions()
		state.routes = RegionCatalog.create_default_routes()

	state.armies.clear()
	var raw_armies: Dictionary = data.get("armies", {})
	for k in raw_armies:
		var army: ArmyState = ArmyState.deserialize(raw_armies[k])
		state.armies[army.id] = army
		if army.id >= state.next_army_id:
			state.next_army_id = army.id + 1

	state.objectives.clear()
	var raw_objs: Dictionary = data.get("objectives", {})
	for k in raw_objs:
		var obj: CampaignObjective = CampaignObjective.deserialize(raw_objs[k])
		state.objectives[obj.id] = obj
		if obj.id >= state.next_objective_id:
			state.next_objective_id = obj.id + 1

	state.engagements.clear()
	var raw_engs: Dictionary = data.get("engagements", {})
	for k in raw_engs:
		var eng: RegionalEngagement = RegionalEngagement.deserialize(raw_engs[k])
		state.engagements[eng.id] = eng
		if eng.id >= state.next_engagement_id:
			state.next_engagement_id = eng.id + 1

	state.contracts.clear()
	var raw_contracts: Dictionary = data.get("contracts", {})
	for k in raw_contracts:
		var c: TradeContract = TradeContract.deserialize(raw_contracts[k])
		state.contracts[c.id] = c
		if c.id >= state.next_contract_id:
			state.next_contract_id = c.id + 1

	state.shipments.clear()
	var raw_shipments: Dictionary = data.get("shipments", {})
	for k in raw_shipments:
		var s: TradeShipment = TradeShipment.deserialize(raw_shipments[k])
		state.shipments[s.id] = s
		if s.id >= state.next_shipment_id:
			state.next_shipment_id = s.id + 1

	return state
