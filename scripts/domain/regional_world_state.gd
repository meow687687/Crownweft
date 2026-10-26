class_name RegionalWorldState
extends RefCounted

var regions: Dictionary = {} # StringName -> RegionState
var routes: Array[RegionRoute] = []
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

func serialize() -> Dictionary:
	var reg_dict: Dictionary = {}
	for k in regions:
		reg_dict[str(k)] = regions[k].serialize()
	var route_arr: Array = []
	for r in routes:
		route_arr.append(r.serialize())
	return {
		"selected_region_id": str(selected_region_id),
		"regions": reg_dict,
		"routes": route_arr
	}

static func deserialize(data: Dictionary) -> RegionalWorldState:
	var state := RegionalWorldState.new()
	state.selected_region_id = StringName(data.get("selected_region_id", ""))
	
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

	return state
