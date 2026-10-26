class_name SpeciesCatalog
extends RefCounted

const DEFAULT_SPECIES_ID: StringName = &"human"

const SPECIES_IDS: Array[StringName] = [
	&"human",
	&"stoneborn",
	&"greenwarden"
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[&"human"] = {
		"id": &"human",
		"display_name": "Human",
		"description": "Adaptable and versatile. Possesses balanced capabilities across all trades with steady endurance and no severe specialisation.",
		"starting_skill_modifiers": {},
		"performance_modifiers": {},
		"energy_drain_modifier": 1.0,
		"energy_recovery_modifier": 1.0,
		"advantages": [
			"Balanced and versatile across all industries",
			"Standard energy recovery and rest requirements"
		],
		"disadvantages": [
			"Lacks specialized peak output in heavy quarrying or forestry"
		]
	}

	_defs[&"stoneborn"] = {
		"id": &"stoneborn",
		"display_name": "Stoneborn",
		"description": "Stout folk of ancient subterranean tradition. Outstanding endurance in masonry, stone extraction, and physical hauling, with reduced affinity for agriculture and forestry.",
		"starting_skill_modifiers": {
			&"masonry": 10.0,
			&"hauling": 5.0,
			&"forestry": -5.0,
			&"farming": -5.0
		},
		"performance_modifiers": {
			&"masonry": 0.12,
			&"hauling": 0.08,
			&"forestry": -0.08,
			&"farming": -0.08
		},
		"energy_drain_modifier": 0.90, # 10% less fatigue during work
		"energy_recovery_modifier": 0.95, # 5% slower rest recovery
		"advantages": [
			"+12% Masonry labor and construction speed",
			"+8% Hauling efficiency and stamina",
			"10% reduced energy drain while working"
		],
		"disadvantages": [
			"-8% Farming and Forestry productivity",
			"5% slower energy recovery when resting"
		]
	}

	_defs[&"greenwarden"] = {
		"id": &"greenwarden",
		"display_name": "Greenwarden",
		"description": "Attuned to soil and canopy. Exceptional cultivators and foresters with rapid physical recovery, but less suited to underground stone dressing.",
		"starting_skill_modifiers": {
			&"farming": 10.0,
			&"forestry": 10.0,
			&"masonry": -8.0,
			&"crafting": -4.0
		},
		"performance_modifiers": {
			&"farming": 0.12,
			&"forestry": 0.12,
			&"masonry": -0.10,
			&"crafting": -0.05
		},
		"energy_drain_modifier": 1.0,
		"energy_recovery_modifier": 1.15, # 15% faster rest recovery
		"advantages": [
			"+12% Farming crop yield and harvesting speed",
			"+12% Forestry timber harvesting speed",
			"15% faster rest and energy recovery at home"
		],
		"disadvantages": [
			"-10% Masonry and stone construction labor speed",
			"-5% Crafting output speed"
		]
	}

static func get_def(species_id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(species_id, defs.get(DEFAULT_SPECIES_ID, {}))

static func is_valid_species(species_id: StringName) -> bool:
	return get_all_defs().has(species_id)

static func validate_species_id(species_id: StringName) -> StringName:
	if is_valid_species(species_id):
		return species_id
	return DEFAULT_SPECIES_ID

static func get_display_name(species_id: StringName) -> String:
	return str(get_def(species_id).get("display_name", "Human"))

static func get_starting_skill_modifier(species_id: StringName, skill_name: StringName) -> float:
	var def: Dictionary = get_def(species_id)
	var mods: Dictionary = def.get("starting_skill_modifiers", {})
	return float(mods.get(skill_name, 0.0))

static func get_performance_modifier(species_id: StringName, skill_name: StringName) -> float:
	var def: Dictionary = get_def(species_id)
	var mods: Dictionary = def.get("performance_modifiers", {})
	return float(mods.get(skill_name, 0.0))

static func get_energy_drain_modifier(species_id: StringName) -> float:
	var def: Dictionary = get_def(species_id)
	return float(def.get("energy_drain_modifier", 1.0))

static func get_energy_recovery_modifier(species_id: StringName) -> float:
	var def: Dictionary = get_def(species_id)
	return float(def.get("energy_recovery_modifier", 1.0))
