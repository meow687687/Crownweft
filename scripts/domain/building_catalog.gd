class_name BuildingCatalog
extends RefCounted

static func get_all_defs() -> Dictionary:
	var defs: Dictionary = {}
	
	# 1. Town Hall
	defs[&"town_hall"] = {
		"id": &"town_hall",
		"display_name": "Town Hall",
		"cost": {},
		"worker_slots": 0,
		"capacity": 100,
		"accepted": [&"coin", &"bread", &"grain", &"timber", &"stone"],
		"footprint": Vector2i(3, 3),
		"color": Color(0.85, 0.75, 0.45) # Gold-tan
	}
	
	# 2. House
	defs[&"house"] = {
		"id": &"house",
		"display_name": "House",
		"cost": {&"timber": 4},
		"worker_slots": 0,
		"capacity": 10,
		"housing_capacity": 5,
		"accepted": [&"bread"],
		"footprint": Vector2i(2, 2),
		"color": Color(0.7, 0.5, 0.3) # Wood brown
	}
	
	# 3. Farm
	defs[&"farm"] = {
		"id": &"farm",
		"display_name": "Farm",
		"cost": {&"timber": 5},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"grain"],
		"recipe": RecipeDef.new(&"grow_grain", {}, {&"grain": 3}, 1, 6),
		"footprint": Vector2i(3, 3),
		"color": Color(0.9, 0.85, 0.2) # Golden yellow
	}
	
	# 4. Woodcutter Camp
	defs[&"woodcutter"] = {
		"id": &"woodcutter",
		"display_name": "Woodcutter Camp",
		"cost": {&"timber": 2},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"timber"],
		"recipe": RecipeDef.new(&"chop_wood", {}, {&"timber": 2}, 1, 4),
		"footprint": Vector2i(2, 2),
		"color": Color(0.3, 0.6, 0.25) # Forest green
	}
	
	# 5. Quarry
	defs[&"quarry"] = {
		"id": &"quarry",
		"display_name": "Quarry",
		"cost": {&"timber": 6},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"stone"],
		"recipe": RecipeDef.new(&"mine_stone", {}, {&"stone": 2}, 1, 5),
		"footprint": Vector2i(2, 2),
		"color": Color(0.55, 0.55, 0.6) # Slate grey
	}
	
	# 6. Bakery
	defs[&"bakery"] = {
		"id": &"bakery",
		"display_name": "Bakery",
		"cost": {&"timber": 4, &"stone": 4},
		"worker_slots": 2,
		"capacity": 30,
		"accepted": [&"grain", &"bread"],
		"recipe": RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 4),
		"footprint": Vector2i(2, 2),
		"color": Color(0.85, 0.5, 0.3) # Brick orange
	}
	
	# 7. Storehouse / Granary
	defs[&"storehouse"] = {
		"id": &"storehouse",
		"display_name": "Storehouse",
		"cost": {&"timber": 8, &"stone": 4},
		"worker_slots": 2, # Hauler slots
		"capacity": 150,
		"accepted": [&"grain", &"bread", &"timber", &"stone", &"coin"],
		"footprint": Vector2i(3, 2),
		"color": Color(0.4, 0.45, 0.7) # Deep blue-grey
	}
	
	# 8. Barracks
	defs[&"barracks"] = {
		"id": &"barracks",
		"display_name": "Barracks",
		"cost": {&"timber": 10, &"stone": 8},
		"worker_slots": 4,
		"capacity": 40,
		"accepted": [&"bread"],
		"footprint": Vector2i(3, 3),
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
	
	return defs
