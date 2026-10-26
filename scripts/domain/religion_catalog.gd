class_name ReligionCatalog
extends RefCounted

const DEFAULT_RELIGION_ID: StringName = &"pantheon"

const RELIGION_IDS: Array[StringName] = [
	&"pantheon",
	&"old_grove",
	&"secular"
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[&"pantheon"] = {
		"id": &"pantheon",
		"display_name": "Settlement Pantheon",
		"description": "Veneration of the patron deities of harvest, hearth, stonecraft, and fair trade.",
		"values": ["Hearth devotion", "Civic piety", "Harvest tithes"]
	}

	_defs[&"old_grove"] = {
		"id": &"old_grove",
		"display_name": "Old Grove Animism",
		"description": "Spiritual reverence for deepwood spirits, living trees, and primeval ecological balance.",
		"values": ["Sacred grove protection", "Herbal communion", "Animist silence"]
	}

	_defs[&"secular"] = {
		"id": &"secular",
		"display_name": "Secular Philosophy",
		"description": "Pragmatic rationalism prioritizing empirical craftsmanship, civic laws, and human reason.",
		"values": ["Pragmatic inquiry", "Civic law", "Secular duty"]
	}

static func get_def(id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(id, defs[DEFAULT_RELIGION_ID])

static func is_valid_religion(id: StringName) -> bool:
	return RELIGION_IDS.has(id)

static func validate_religion_id(id: StringName) -> StringName:
	return id if is_valid_religion(id) else DEFAULT_RELIGION_ID

static func get_display_name(id: StringName) -> String:
	var d: Dictionary = get_def(id)
	return d.get("display_name", "Settlement Pantheon")
