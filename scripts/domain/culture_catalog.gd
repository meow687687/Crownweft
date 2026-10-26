class_name CultureCatalog
extends RefCounted

const DEFAULT_CULTURE_ID: StringName = &"valen"

const CULTURE_IDS: Array[StringName] = [
	&"valen",
	&"khorvath",
	&"sylvanari"
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[&"valen"] = {
		"id": &"valen",
		"display_name": "Valen",
		"description": "Riverine folk of cooperative agrarian settlements. Valen culture prizes civic duty, steady communal craftsmanship, and irrigation.",
		"default_doctrine_id": &"communal_labor",
		"traditions": [
			"Riverine irrigation canal stewardship",
			"Communal harvest gatherings",
			"Civic town hall assemblies"
		],
		"cultural_modifiers": {
			&"communal_cohesion": 0.05
		},
		"default_convictions": {
			&"work_ethic": 0.8,
			&"nature_conservation": 0.3,
			&"dietary_type": "omnivore",
			&"piety": 0.5
		}
	}

	_defs[&"khorvath"] = {
		"id": &"khorvath",
		"display_name": "Khorvath",
		"description": "Hardy highland clans of martial tradition, clan loyalty, and resource fortitude. Khorvath culture respects rugged self-reliance and stonecraft.",
		"default_doctrine_id": &"martial_tradition",
		"traditions": [
			"Highland crest watchtowers",
			"Clan blood oaths",
			"Substantive meat and stonecraft provisions"
		],
		"cultural_modifiers": {
			&"martial_resolve": 0.05
		},
		"default_convictions": {
			&"work_ethic": 0.75,
			&"nature_conservation": 0.2,
			&"dietary_type": "omnivore",
			&"piety": 0.3
		}
	}

	_defs[&"sylvanari"] = {
		"id": &"sylvanari",
		"display_name": "Sylvanari",
		"description": "Ancient woodland people devoted to canopy conservation, herbal medicines, and reverence for living ecosystems.",
		"default_doctrine_id": &"sylvan_harmony",
		"traditions": [
			"Canopy sanctuary ceremonies",
			"Strict plant-based herbal diets",
			"Living bough cultivation"
		],
		"cultural_modifiers": {
			&"nature_reverence": 0.10
		},
		"default_convictions": {
			&"work_ethic": 0.6,
			&"nature_conservation": 0.9,
			&"dietary_type": "vegetarian",
			&"piety": 0.8
		}
	}

static func get_def(id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(id, defs[DEFAULT_CULTURE_ID])

static func is_valid_culture(id: StringName) -> bool:
	return CULTURE_IDS.has(id)

static func validate_culture_id(id: StringName) -> StringName:
	return id if is_valid_culture(id) else DEFAULT_CULTURE_ID

static func get_display_name(id: StringName) -> String:
	var d: Dictionary = get_def(id)
	return d.get("display_name", "Valen")

static func get_default_doctrine(id: StringName) -> StringName:
	var d: Dictionary = get_def(id)
	return d.get("default_doctrine_id", &"communal_labor")
