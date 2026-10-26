class_name BuildingCatalog
extends RefCounted

static func get_all_defs() -> Dictionary:
	var defs: Dictionary = {}
	
	# 1. Town Hall (Fixed)
	defs[&"town_hall"] = {
		"id": &"town_hall",
		"health": 300,
		"display_name": "Town Hall",
		"cost": {},
		"worker_slots": 0,
		"capacity": 150,
		"accepted": [&"coin", &"bread", &"grain", &"timber", &"stone"],
		"footprint": Vector2i(3, 3),
		"is_resizable": false,
		"min_footprint": Vector2i(3, 3),
		"max_footprint": Vector2i(3, 3),
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 12,
		"color": Color(0.85, 0.75, 0.45) # Gold-tan
	}
	
	# 2. House (Fixed)
	defs[&"house"] = {
		"id": &"house",
		"health": 80,
		"display_name": "House",
		"cost": {&"timber": 4},
		"worker_slots": 0,
		"capacity": 10,
		"housing_capacity": 5,
		"accepted": [&"bread"],
		"footprint": Vector2i(2, 2),
		"is_resizable": false,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(2, 2),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 6,
		"color": Color(0.7, 0.5, 0.3) # Wood brown
	}
	
	# 3. Farm (Resizable)
	defs[&"farm"] = {
		"id": &"farm",
		"health": 90,
		"display_name": "Farm",
		"cost": {&"timber": 5},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"grain"],
		"recipe": RecipeDef.new(&"grow_grain", {}, {&"grain": 3}, 1, 6),
		"footprint": Vector2i(3, 3),
		"is_resizable": true,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(6, 6),
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 8,
		"color": Color(0.9, 0.85, 0.2) # Golden yellow
	}
	
	# 4. Woodcutter Camp (Fixed)
	defs[&"woodcutter"] = {
		"id": &"woodcutter",
		"health": 100,
		"display_name": "Woodcutter Camp",
		"cost": {&"timber": 2},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"timber"],
		"recipe": RecipeDef.new(&"chop_wood", {}, {&"timber": 2}, 1, 4),
		"harvest_deposit": &"trees",
		"footprint": Vector2i(2, 2),
		"is_resizable": false,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(2, 2),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 6,
		"color": Color(0.3, 0.6, 0.25) # Forest green
	}
	
	# 5. Quarry (Fixed)
	defs[&"quarry"] = {
		"id": &"quarry",
		"health": 130,
		"display_name": "Quarry",
		"cost": {&"timber": 6},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"stone"],
		"recipe": RecipeDef.new(&"mine_stone", {}, {&"stone": 2}, 1, 5),
		"harvest_deposit": &"stone_deposit",
		"footprint": Vector2i(2, 2),
		"is_resizable": false,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(2, 2),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 8,
		"color": Color(0.55, 0.55, 0.6) # Slate grey
	}
	
	# 6. Bakery (Fixed)
	defs[&"bakery"] = {
		"id": &"bakery",
		"health": 100,
		"display_name": "Bakery",
		"cost": {&"timber": 4, &"stone": 4},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"grain", &"bread"],
		"recipe": RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 4),
		"footprint": Vector2i(2, 2),
		"is_resizable": false,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(2, 2),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 8,
		"color": Color(0.85, 0.5, 0.3) # Brick orange
	}
	
	# 7. Storehouse / Granary (Resizable)
	defs[&"storehouse"] = {
		"id": &"storehouse",
		"health": 140,
		"display_name": "Storehouse",
		"cost": {&"timber": 8, &"stone": 4},
		"worker_slots": 2,
		"capacity": 150,
		"accepted": [&"grain", &"bread", &"timber", &"stone", &"coin"],
		"footprint": Vector2i(3, 2),
		"is_resizable": true,
		"min_footprint": Vector2i(2, 2),
		"max_footprint": Vector2i(5, 4),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 2), Vector2i(1, 3)],
		"build_time": 10,
		"color": Color(0.4, 0.45, 0.7) # Deep blue-grey
	}
	
	# 8. Barracks (Fixed)
	defs[&"barracks"] = {
		"id": &"barracks",
		"health": 160,
		"display_name": "Barracks",
		"cost": {&"timber": 10, &"stone": 8},
		"worker_slots": 4,
		"capacity": 40,
		"accepted": [&"bread"],
		"footprint": Vector2i(3, 3),
		"is_resizable": false,
		"min_footprint": Vector2i(3, 3),
		"max_footprint": Vector2i(3, 3),
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 10,
		"color": Color(0.7, 0.2, 0.2) # Crimson
	}
	
	# 9. Road (Fixed)
	defs[&"road"] = {
		"id": &"road",
		"display_name": "Dirt Road",
		"cost": {&"timber": 0},
		"worker_slots": 0,
		"capacity": 0,
		"accepted": [],
		"footprint": Vector2i(1, 1),
		"is_resizable": false,
		"min_footprint": Vector2i(1, 1),
		"max_footprint": Vector2i(1, 1),
		"color": Color(0.65, 0.55, 0.4) # Dirt tan
	}
	
	# 10. Ground Pile (Salvage / Overflow storage)
	defs[&"ground_pile"] = {
		"id": &"ground_pile",
		"health": 50,
		"display_name": "Resource Pile",
		"cost": {},
		"worker_slots": 0,
		"capacity": 500,
		"accepted": [],
		"footprint": Vector2i(1, 1),
		"is_resizable": false,
		"min_footprint": Vector2i(1, 1),
		"max_footprint": Vector2i(1, 1),
		"entrance_offset": Vector2i(0, 1),
		"doorway_tile": Vector2i(0, 0),
		"staging_offsets": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)],
		"build_time": 0,
		"color": Color(0.7, 0.6, 0.4) # Burlap tan
	}
	
	return defs

static func is_building_resizable(def_id: StringName) -> bool:
	return get_all_defs().get(def_id, {}).get("is_resizable", false)

static func get_min_footprint(def_id: StringName) -> Vector2i:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	return def_info.get("min_footprint", def_info.get("footprint", Vector2i(2, 2)))

static func get_max_footprint(def_id: StringName) -> Vector2i:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	return def_info.get("max_footprint", def_info.get("footprint", Vector2i(2, 2)))

static func clamp_footprint(def_id: StringName, fp: Vector2i) -> Vector2i:
	var min_fp: Vector2i = get_min_footprint(def_id)
	var max_fp: Vector2i = get_max_footprint(def_id)
	return Vector2i(clampi(fp.x, min_fp.x, max_fp.x), clampi(fp.y, min_fp.y, max_fp.y))

static func get_cost_for_footprint(def_id: StringName, fp: Vector2i) -> Dictionary:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	var base_fp: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	var base_cost: Dictionary = def_info.get("cost", {})
	if not def_info.get("is_resizable", false) or base_cost.is_empty():
		return base_cost.duplicate()
	var base_area: float = float(maxi(1, base_fp.x * base_fp.y))
	var actual_area: float = float(fp.x * fp.y)
	var scaled_cost: Dictionary = {}
	for res_id: StringName in base_cost:
		var base_amount: int = base_cost[res_id]
		if base_amount <= 0:
			scaled_cost[res_id] = 0
			continue
		var min_cost: int = maxi(1, int(ceil(float(base_amount) * 0.5)))
		var calculated: int = int(round(float(base_amount) * (actual_area / base_area)))
		scaled_cost[res_id] = maxi(min_cost, calculated)
	return scaled_cost

static func get_capacity_for_footprint(def_id: StringName, fp: Vector2i) -> int:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	var base_fp: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	var base_cap: int = int(def_info.get("capacity", 30))
	if not def_info.get("is_resizable", false) or base_cap <= 0:
		return base_cap
	var base_area: float = float(maxi(1, base_fp.x * base_fp.y))
	var actual_area: float = float(fp.x * fp.y)
	return maxi(10, int(round(float(base_cap) * (actual_area / base_area))))

static func get_worker_slots_for_footprint(def_id: StringName, fp: Vector2i) -> int:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	var base_slots: int = int(def_info.get("worker_slots", 0))
	if not def_info.get("is_resizable", false) or base_slots <= 0:
		return base_slots
	var actual_area: int = fp.x * fp.y
	if def_id == &"farm":
		# 1 slot at 4 tiles, 2 at 9 tiles, up to 6 slots at 36 tiles
		return clampi(1 + int(actual_area / 6), 1, 6)
	if def_id == &"storehouse":
		return clampi(2 + int(maxi(0, actual_area - 6) / 8), 2, 4)
	return base_slots

static func get_build_time_for_footprint(def_id: StringName, fp: Vector2i) -> int:
	var def_info: Dictionary = get_all_defs().get(def_id, {})
	var base_time: int = int(def_info.get("build_time", 8))
	if not def_info.get("is_resizable", false) or base_time <= 0:
		return base_time
	var base_fp: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	var base_area: float = float(maxi(1, base_fp.x * base_fp.y))
	var actual_area: float = float(fp.x * fp.y)
	var min_time: int = maxi(4, int(ceil(float(base_time) * 0.5)))
	return maxi(min_time, int(round(float(base_time) * (actual_area / base_area))))
