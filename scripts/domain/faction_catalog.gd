class_name FactionCatalog
extends RefCounted

const FACTION_PLAYER: StringName = &"player"
const FACTION_VALEN: StringName = &"valen_compact"
const FACTION_OLD_GROVE: StringName = &"old_grove_commune"
const FACTION_IRONPEAK: StringName = &"ironpeak_clans"

const FACTION_IDS: Array[StringName] = [
	FACTION_PLAYER,
	FACTION_VALEN,
	FACTION_OLD_GROVE,
	FACTION_IRONPEAK
]

const NEIGHBOUR_FACTION_IDS: Array[StringName] = [
	FACTION_VALEN,
	FACTION_OLD_GROVE,
	FACTION_IRONPEAK
]

const GOAL_SECURE_FOOD: StringName = &"secure_food"
const GOAL_ECONOMIC_STABILITY: StringName = &"economic_stability"
const GOAL_PROTECT_BORDERS: StringName = &"protect_borders"
const GOAL_ESTABLISH_TRADE: StringName = &"establish_trade"
const GOAL_STRENGTHEN_RELATIONS: StringName = &"strengthen_relations"
const GOAL_PRESERVE_RESOURCES: StringName = &"preserve_resources"

const GOAL_IDS: Array[StringName] = [
	GOAL_SECURE_FOOD,
	GOAL_ECONOMIC_STABILITY,
	GOAL_PROTECT_BORDERS,
	GOAL_ESTABLISH_TRADE,
	GOAL_STRENGTHEN_RELATIONS,
	GOAL_PRESERVE_RESOURCES
]

static func get_all_defs() -> Dictionary:
	var defs: Dictionary = {}

	defs[FACTION_PLAYER] = {
		"id": FACTION_PLAYER,
		"display_name": "The Crown",
		"culture": &"valen",
		"religion": &"pantheon",
		"doctrine": &"communal_labor",
		"color": Color(0.95, 0.85, 0.35), # Imperial Gold
		"description": "Your fledgling realm, striving for self-sufficiency, security, and prestige.",
		"default_goals": [GOAL_SECURE_FOOD, GOAL_ECONOMIC_STABILITY],
		"initial_treasury": 50,
		"initial_resources": {&"grain": 30, &"bread": 20, &"timber": 40, &"stone": 20},
		"initial_military": 20
	}

	defs[FACTION_VALEN] = {
		"id": FACTION_VALEN,
		"display_name": "Valen Trade Compact",
		"culture": &"valen",
		"religion": &"pantheon",
		"doctrine": &"communal_labor",
		"color": Color(0.35, 0.65, 0.95), # Azure Blue
		"description": "A wealthy mercantile league of river cities emphasizing reliable trade contracts, coin accumulation, and mutual commercial treaties.",
		"default_goals": [GOAL_ESTABLISH_TRADE, GOAL_ECONOMIC_STABILITY],
		"initial_treasury": 120,
		"initial_resources": {&"grain": 50, &"timber": 35, &"stone": 25},
		"initial_military": 25
	}

	defs[FACTION_OLD_GROVE] = {
		"id": FACTION_OLD_GROVE,
		"display_name": "Old Grove Commune",
		"culture": &"sylvanari",
		"religion": &"old_grove",
		"doctrine": &"sylvan_harmony",
		"color": Color(0.35, 0.85, 0.45), # Verdant Emerald
		"description": "A secluded forest society guided by ancestral reverence. They strictly ration timber harvesting, value reciprocal grain aid during blights, and disdain deforestation.",
		"default_goals": [GOAL_PRESERVE_RESOURCES, GOAL_SECURE_FOOD],
		"initial_treasury": 35,
		"initial_resources": {&"grain": 20, &"timber": 60, &"stone": 10},
		"initial_military": 18
	}

	defs[FACTION_IRONPEAK] = {
		"id": FACTION_IRONPEAK,
		"display_name": "Ironpeak Clans",
		"culture": &"khorvath",
		"religion": &"secular",
		"doctrine": &"martial_tradition",
		"color": Color(0.85, 0.4, 0.35), # Crimson Iron
		"description": "A martial highland federation of stone-masons and veterans. They prioritize secure borders, stockpile mineral wealth, and respect strength, direct speech, and mutual defense agreements.",
		"default_goals": [GOAL_PROTECT_BORDERS, GOAL_STRENGTHEN_RELATIONS],
		"initial_treasury": 60,
		"initial_resources": {&"grain": 15, &"timber": 25, &"stone": 70},
		"initial_military": 40
	}

	return defs

static func get_faction_def(faction_id: StringName) -> Dictionary:
	return get_all_defs().get(faction_id, {})

static func is_valid_faction(faction_id: StringName) -> bool:
	return FACTION_IDS.has(faction_id)

static func is_valid_goal(goal_id: StringName) -> bool:
	return GOAL_IDS.has(goal_id)

static func get_goal_display_name(goal_id: StringName) -> String:
	match goal_id:
		GOAL_SECURE_FOOD:
			return "Secure Essential Food"
		GOAL_ECONOMIC_STABILITY:
			return "Accumulate Treasury Reserves"
		GOAL_PROTECT_BORDERS:
			return "Fortify & Protect Borders"
		GOAL_ESTABLISH_TRADE:
			return "Establish Active Trade"
		GOAL_STRENGTHEN_RELATIONS:
			return "Strengthen Regional Alliances"
		GOAL_PRESERVE_RESOURCES:
			return "Preserve Natural Resources"
		_:
			return str(goal_id).capitalize()

static func get_numeric_faction_id(faction_id: StringName) -> int:
	match faction_id:
		FACTION_PLAYER:
			return 0
		FACTION_VALEN:
			return 2
		FACTION_OLD_GROVE:
			return 3
		FACTION_IRONPEAK:
			return 4
		_:
			return 1

static func get_faction_id_from_numeric(num_id: int) -> StringName:
	match num_id:
		0:
			return FACTION_PLAYER
		2:
			return FACTION_VALEN
		3:
			return FACTION_OLD_GROVE
		4:
			return FACTION_IRONPEAK
		_:
			return &"raiders"
