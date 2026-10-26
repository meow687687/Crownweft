class_name DoctrineCatalog
extends RefCounted

const DEFAULT_DOCTRINE_ID: StringName = &"communal_labor"

const DOCTRINE_IDS: Array[StringName] = [
	&"communal_labor",
	&"sylvan_harmony",
	&"martial_tradition"
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[&"communal_labor"] = {
		"id": &"communal_labor",
		"display_name": "Communal Labor & Duty",
		"description": "Values industrious work, cooperative civic effort, and pragmatic resource stewardship.",
		"convictions": {
			&"work_ethic": 0.80,
			&"nature_conservation": 0.40,
			&"piety": 0.35,
			&"dietary_type": "omnivore"
		},
		"rejected_foods": []
	}

	_defs[&"sylvan_harmony"] = {
		"id": &"sylvan_harmony",
		"display_name": "Sylvan Harmony & Sanctity",
		"description": "Strict arboreal conservation, sacred communion with ancient groves, and pure plant-based sustenance.",
		"convictions": {
			&"work_ethic": 0.50,
			&"nature_conservation": 0.90,
			&"piety": 0.75,
			&"dietary_type": "vegetarian"
		},
		"rejected_foods": [&"meat"]
	}

	_defs[&"martial_tradition"] = {
		"id": &"martial_tradition",
		"display_name": "Martial Fortitude & Extraction",
		"description": "Values rigorous discipline, clan strength, rugged survival, and decisive resource utilization.",
		"convictions": {
			&"work_ethic": 0.85,
			&"nature_conservation": 0.20,
			&"piety": 0.40,
			&"dietary_type": "omnivore"
		},
		"rejected_foods": []
	}

static func get_def(id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(id, defs[DEFAULT_DOCTRINE_ID])

static func is_valid_doctrine(id: StringName) -> bool:
	return DOCTRINE_IDS.has(id)

static func validate_doctrine_id(id: StringName) -> StringName:
	return id if is_valid_doctrine(id) else DEFAULT_DOCTRINE_ID

static func get_display_name(id: StringName) -> String:
	var d: Dictionary = get_def(id)
	return d.get("display_name", "Communal Labor")

static func get_default_convictions(id: StringName) -> Dictionary:
	var d: Dictionary = get_def(id)
	var conv: Dictionary = d.get("convictions", {})
	return conv.duplicate()

static func rejects_food(doctrine_id: StringName, food_id: StringName) -> bool:
	var d: Dictionary = get_def(doctrine_id)
	var rej: Array = d.get("rejected_foods", [])
	return rej.has(food_id)
