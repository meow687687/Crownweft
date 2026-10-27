class_name ScenarioCatalog
extends RefCounted

const SCENARIO_FOUNDING: StringName = &"crownweft_founding"
const SCENARIO_BORDER_MARCH: StringName = &"border_march"
const SCENARIO_MERCHANTS_CROSSROADS: StringName = &"merchants_crossroads"

const ALL_SCENARIO_IDS: Array[StringName] = [
	SCENARIO_FOUNDING,
	SCENARIO_BORDER_MARCH,
	SCENARIO_MERCHANTS_CROSSROADS
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func get_scenario_def(scenario_id: StringName) -> Dictionary:
	var all = get_all_defs()
	if all.has(scenario_id):
		return all[scenario_id]
	return all[SCENARIO_FOUNDING]

static func _init_defs() -> void:
	# --------------------------------------------------------------------------
	# Scenario A: The Founding of Crownweft Valley
	# --------------------------------------------------------------------------
	_defs[SCENARIO_FOUNDING] = {
		"id": SCENARIO_FOUNDING,
		"name": "The Founding of Crownweft Valley",
		"tagline": "Establish a self-sufficient agrarian realm in fertile river plains.",
		"description": "Lead the original pioneers of Crownweft. Stabilize the settlement with farming, build a local grain-to-bread supply chain, and establish initial regional trade with the Valen Trade Compact.",
		"strategic_focus": "Settlement Stabilization & Food Chain Integration",
		"difficulty": "Standard",
		"constraints": [
			"Modest initial treasury and raw materials.",
			"Must establish agriculture and baking before expanding regional footprint."
		],
		"starting_supplies": {
			&"coin": 60,
			&"bread": 25,
			&"timber": 30,
			&"stone": 15
		},
		"starting_buildings": [
			{
				"def_id": &"town_hall",
				"offset": Vector2i.ZERO,
				"active": true
			},
			{
				"def_id": &"farm",
				"offset": Vector2i(-4, -4),
				"active": true,
				"assigned_workers": 0
			}
		],
		"starting_citizens": [
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"greenwarden", "status": &"artisan", "culture": &"sylvanari", "religion": &"old_grove", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"artisan", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"administrator", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"scholar", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"merchant", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"greenwarden", "status": &"commoner", "culture": &"sylvanari", "religion": &"old_grove", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"commoner", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"commoner", "culture": &"sylvanari", "religion": &"pantheon", "role": &"unassigned"}
		],
		"starting_military": {
			"local_units": [],
			"crown_guard_supplies": 40
		},
		"diplomacy_mod": {
			FactionCatalog.FACTION_VALEN: {"trust": 50.0, "threat": 10.0, "economic_cooperation": 50.0},
			FactionCatalog.FACTION_OLD_GROVE: {"trust": 50.0, "threat": 15.0, "economic_cooperation": 40.0},
			FactionCatalog.FACTION_IRONPEAK: {"trust": 30.0, "threat": 25.0, "economic_cooperation": 20.0}
		},
		"objectives": [
			&"obj_staff_farm",
			&"obj_produce_grain",
			&"obj_place_bakery",
			&"obj_construct_bakery",
			&"obj_produce_bread",
			&"obj_propose_trade",
			&"obj_settle_trade"
		]
	}

	# --------------------------------------------------------------------------
	# Scenario B: The Border March
	# --------------------------------------------------------------------------
	_defs[SCENARIO_BORDER_MARCH] = {
		"id": SCENARIO_BORDER_MARCH,
		"name": "The Border March",
		"tagline": "Fortify a tense frontier post under the shadow of the Ironpeak Clans.",
		"description": "Stationed along the rugged edge of Shattered Pass and the Grey Marches, your settlement serves as the realm's military shield. Train local garrison troops, manage critical army supply lines, and deter mountain clan incursions.",
		"strategic_focus": "Military Readiness, Garrison Defense & Frontier Supply Lines",
		"difficulty": "Challenging",
		"constraints": [
			"Strained diplomatic relations with the martial Ironpeak Clans.",
			"Royal Crown Guard has critically depleted field supplies (15 / 100) requiring immediate resupply.",
			"Defensive commitments require allocating workforce to military training rather than pure farming."
		],
		"starting_supplies": {
			&"coin": 40,
			&"bread": 10,
			&"timber": 20,
			&"stone": 25
		},
		"starting_buildings": [
			{
				"def_id": &"town_hall",
				"offset": Vector2i.ZERO,
				"active": true
			},
			{
				"def_id": &"barracks",
				"offset": Vector2i(-5, -4),
				"active": true,
				"assigned_workers": 0
			},
			{
				"def_id": &"farm",
				"offset": Vector2i(4, -4),
				"active": true,
				"assigned_workers": 0
			}
		],
		"starting_citizens": [
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"stoneborn", "status": &"artisan", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"artisan", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"administrator", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"scholar", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"greenwarden", "status": &"commoner", "culture": &"sylvanari", "religion": &"old_grove", "role": &"unassigned"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"commoner", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"}
		],
		"starting_military": {
			"local_units": [
				{"def_id": &"warrior", "offset": Vector2i(-5, -1)},
				{"def_id": &"archer", "offset": Vector2i(-4, -1)}
			],
			"crown_guard_supplies": 15 # Depleted initial supply requiring resupply order
		},
		"diplomacy_mod": {
			FactionCatalog.FACTION_VALEN: {"trust": 40.0, "threat": 20.0, "economic_cooperation": 35.0},
			FactionCatalog.FACTION_OLD_GROVE: {"trust": 45.0, "threat": 20.0, "economic_cooperation": 35.0},
			FactionCatalog.FACTION_IRONPEAK: {"trust": 15.0, "threat": 65.0, "economic_cooperation": 10.0} # Strained frontier
		},
		"objectives": [
			&"obj_staff_garrison",
			&"obj_stock_rations",
			&"obj_resupply_army",
			&"obj_patrol_frontier",
			&"obj_secure_frontier"
		]
	}

	# --------------------------------------------------------------------------
	# Scenario C: The Merchant's Crossroads
	# --------------------------------------------------------------------------
	_defs[SCENARIO_MERCHANTS_CROSSROADS] = {
		"id": SCENARIO_MERCHANTS_CROSSROADS,
		"name": "The Merchant's Crossroads",
		"tagline": "Build a bustling commercial entrepôt connecting regional factions.",
		"description": "Constructed at the convergence of trade routes between Port Valen and the Whispering Canopy, your settlement must master physical storage reservations, high-volume hauling, and fulfilling competing trade treaties.",
		"strategic_focus": "Storage Reservations, High-Throughput Hauling & Faction Commerce",
		"difficulty": "Complex",
		"constraints": [
			"High logistical volume demands dedicated storehouse management and 4 haulers.",
			"Must fulfill export commitments while avoiding domestic timber and bread shortages.",
			"Export contracts reserve inventory at origin; failing to fulfill locks valuable cargo."
		],
		"starting_supplies": {
			&"coin": 120,
			&"bread": 20,
			&"timber": 10,
			&"stone": 10,
			&"grain": 10
		},
		"starting_buildings": [
			{
				"def_id": &"town_hall",
				"offset": Vector2i.ZERO,
				"active": true
			},
			{
				"def_id": &"storehouse",
				"offset": Vector2i(-5, -4),
				"active": true,
				"assigned_workers": 0
			},
			{
				"def_id": &"farm",
				"offset": Vector2i(4, -4),
				"active": true,
				"assigned_workers": 0
			}
		],
		"starting_citizens": [
			{"species": &"human", "status": &"merchant", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"hauler"},
			{"species": &"greenwarden", "status": &"commoner", "culture": &"sylvanari", "religion": &"old_grove", "role": &"hauler"},
			{"species": &"stoneborn", "status": &"commoner", "culture": &"khorvath", "religion": &"secular", "role": &"hauler"},
			{"species": &"human", "status": &"administrator", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"human", "status": &"merchant", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"greenwarden", "status": &"artisan", "culture": &"sylvanari", "religion": &"old_grove", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"artisan", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"scholar", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"},
			{"species": &"human", "status": &"commoner", "culture": &"valen", "religion": &"pantheon", "role": &"unassigned"},
			{"species": &"greenwarden", "status": &"commoner", "culture": &"sylvanari", "religion": &"old_grove", "role": &"unassigned"},
			{"species": &"stoneborn", "status": &"commoner", "culture": &"khorvath", "religion": &"secular", "role": &"unassigned"}
		],
		"starting_military": {
			"local_units": [],
			"crown_guard_supplies": 40
		},
		"diplomacy_mod": {
			FactionCatalog.FACTION_VALEN: {"trust": 65.0, "threat": 5.0, "economic_cooperation": 65.0},
			FactionCatalog.FACTION_OLD_GROVE: {"trust": 60.0, "threat": 10.0, "economic_cooperation": 55.0},
			FactionCatalog.FACTION_IRONPEAK: {"trust": 35.0, "threat": 25.0, "economic_cooperation": 30.0}
		},
		"objectives": [
			&"obj_inspect_storehouse",
			&"obj_produce_surplus",
			&"obj_ratify_valen_export",
			&"obj_dispatch_communal_trade",
			&"obj_settle_merchant_emporium"
		]
	}
