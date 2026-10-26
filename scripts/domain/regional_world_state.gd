class_name RegionalWorldState
extends RefCounted

var regions: Dictionary = {} # StringName -> RegionState
var routes: Array[RegionRoute] = []
var armies: Dictionary = {} # int -> ArmyState
var next_army_id: int = 1
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

		var is_marching: bool = (army.status in [ArmyState.STATUS_MARCHING, ArmyState.STATUS_SUPPLY_STRAINED] and not army.route_path.is_empty())
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
				army.transition_to(ArmyState.STATUS_GARRISONED, "Arrived at destination %s" % str(to_node), current_tick)
			else:
				# Setup next segment
				var next_target: StringName = army.route_path[army.path_index + 1]
				var next_route: RegionRoute = get_route_between(army.current_region_id, next_target)
				army.segment_total_ticks = next_route.travel_ticks if next_route != null else 60

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

	return {
		"selected_region_id": str(selected_region_id),
		"next_army_id": next_army_id,
		"regions": reg_dict,
		"routes": route_arr,
		"armies": army_dict
	}

static func deserialize(data: Dictionary) -> RegionalWorldState:
	var state := RegionalWorldState.new()
	state.selected_region_id = StringName(data.get("selected_region_id", ""))
	state.next_army_id = int(data.get("next_army_id", 1))

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

	return state
