class_name BuildingCatalog
extends RefCounted

static func get_all_defs() -> Dictionary:
	var defs: Dictionary = {}
	
	# 1. Town Hall
	defs[&"town_hall"] = {
		"id": &"town_hall",
		"health": 300,
		"display_name": "Town Hall",
		"cost": {},
		"worker_slots": 0,
		"capacity": 150,
		"accepted": [&"coin", &"bread", &"grain", &"timber", &"stone"],
		"footprint": Vector2i(3, 3),
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 12,
		"color": Color(0.85, 0.75, 0.45) # Gold-tan
	}
	
	# 2. House
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
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 6,
		"color": Color(0.7, 0.5, 0.3) # Wood brown
	}
	
	# 3. Farm
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
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 8,
		"color": Color(0.9, 0.85, 0.2) # Golden yellow
	}
	
	# 4. Woodcutter Camp
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
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 6,
		"color": Color(0.3, 0.6, 0.25) # Forest green
	}
	
	# 5. Quarry
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
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 8,
		"color": Color(0.55, 0.55, 0.6) # Slate grey
	}
	
	# 6. Bakery
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
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 3)],
		"build_time": 8,
		"color": Color(0.85, 0.5, 0.3) # Brick orange
	}
	
	# 7. Storehouse / Granary
	defs[&"storehouse"] = {
		"id": &"storehouse",
		"health": 140,
		"display_name": "Storehouse",
		"cost": {&"timber": 8, &"stone": 4},
		"worker_slots": 2, # Hauler slots
		"capacity": 150,
		"accepted": [&"grain", &"bread", &"timber", &"stone", &"coin"],
		"footprint": Vector2i(3, 2),
		"entrance_offset": Vector2i(1, 2),
		"doorway_tile": Vector2i(1, 1),
		"staging_offsets": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 2), Vector2i(1, 3)],
		"build_time": 10,
		"color": Color(0.4, 0.45, 0.7) # Deep blue-grey
	}
	
	# 8. Barracks
	defs[&"barracks"] = {
		"id": &"barracks",
		"health": 160,
		"display_name": "Barracks",
		"cost": {&"timber": 10, &"stone": 8},
		"worker_slots": 4,
		"capacity": 40,
		"accepted": [&"bread"],
		"footprint": Vector2i(3, 3),
		"entrance_offset": Vector2i(1, 3),
		"doorway_tile": Vector2i(1, 2),
		"staging_offsets": [Vector2i(1, 3), Vector2i(0, 3), Vector2i(2, 3), Vector2i(1, 4)],
		"build_time": 10,
		"color": Color(0.7, 0.2, 0.2) # Crimson
	}
	
	# 9. Road
	defs[&"road"] = {
		"id": &"road",
		"display_name": "Dirt Road",
		"cost": {&"timber": 0}, # Basic dirt road is free / labor only
		"worker_slots": 0,
		"capacity": 0,
		"accepted": [],
		"footprint": Vector2i(1, 1),
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
		"accepted": [], # Accepts all resources
		"footprint": Vector2i(1, 1),
		"entrance_offset": Vector2i(0, 1),
		"doorway_tile": Vector2i(0, 0),
		"staging_offsets": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)],
		"build_time": 0,
		"color": Color(0.7, 0.6, 0.4) # Burlap tan
	}
	
	return defs
