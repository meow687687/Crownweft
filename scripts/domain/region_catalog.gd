class_name RegionCatalog
extends RefCounted

const REGION_CROWNWEFT: StringName = &"crownweft_valley"
const REGION_VALEN: StringName = &"valen_lowlands"
const REGION_OLD_GROVE: StringName = &"whispering_canopy"
const REGION_IRONPEAK: StringName = &"ironpeak_crags"
const REGION_GREY_MARCHES: StringName = &"grey_marches"
const REGION_SHATTERED_PASS: StringName = &"shattered_pass"

const ALL_REGION_IDS: Array[StringName] = [
	REGION_CROWNWEFT,
	REGION_VALEN,
	REGION_OLD_GROVE,
	REGION_IRONPEAK,
	REGION_GREY_MARCHES,
	REGION_SHATTERED_PASS
]

static func create_default_regions() -> Dictionary:
	var regions: Dictionary = {}

	# 1. Player Capital Region
	var r_crown := RegionState.new(
		REGION_CROWNWEFT,
		"Crownweft Valley",
		Vector2(320, 260),
		&"river_valley",
		1.0, # Normal defense
		1.0, # Normal travel
		"Crownweft Capital",
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_PLAYER
	)
	r_crown.primary_resources = [&"grain", &"timber"]
	r_crown.regional_resources = {&"grain": 400, &"timber": 500, &"stone": 250}
	r_crown.neighbors = [REGION_VALEN, REGION_OLD_GROVE, REGION_SHATTERED_PASS, REGION_GREY_MARCHES]
	regions[REGION_CROWNWEFT] = r_crown

	# 2. Valen Trade Compact Region
	var r_valen := RegionState.new(
		REGION_VALEN,
		"Valen Lowlands",
		Vector2(140, 160),
		&"coastal_basin",
		1.05,
		0.9, # Easy travel along paved trade roads
		"Port Valen",
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_VALEN
	)
	r_valen.primary_resources = [&"fish", &"grain", &"coin"]
	r_valen.regional_resources = {&"fish": 600, &"grain": 350, &"coin": 500}
	r_valen.neighbors = [REGION_CROWNWEFT, REGION_OLD_GROVE, REGION_SHATTERED_PASS]
	regions[REGION_VALEN] = r_valen

	# 3. Old Grove Commune Region
	var r_grove := RegionState.new(
		REGION_OLD_GROVE,
		"Whispering Canopy",
		Vector2(160, 400),
		&"ancient_forest",
		1.25, # High natural canopy defense
		1.3,  # Thick root systems slow transit
		"Verdant Hearth",
		FactionCatalog.FACTION_OLD_GROVE,
		FactionCatalog.FACTION_OLD_GROVE
	)
	r_grove.primary_resources = [&"timber", &"herbs"]
	r_grove.regional_resources = {&"timber": 800, &"herbs": 300, &"grain": 200}
	r_grove.neighbors = [REGION_CROWNWEFT, REGION_VALEN, REGION_GREY_MARCHES]
	regions[REGION_OLD_GROVE] = r_grove

	# 4. Ironpeak Clans Region
	var r_iron := RegionState.new(
		REGION_IRONPEAK,
		"Ironpeak Crags",
		Vector2(520, 130),
		&"rugged_peaks",
		1.40, # Formidable mountain fortifications
		1.5,  # Steep, rocky mountain trails
		"Craghold Keep",
		FactionCatalog.FACTION_IRONPEAK,
		FactionCatalog.FACTION_IRONPEAK
	)
	r_iron.primary_resources = [&"iron_ore", &"stone"]
	r_iron.regional_resources = {&"iron_ore": 600, &"stone": 700, &"timber": 150}
	r_iron.neighbors = [REGION_SHATTERED_PASS, REGION_GREY_MARCHES]
	regions[REGION_IRONPEAK] = r_iron

	# 5. Neutral Buffer Region (Unclaimed)
	var r_marches := RegionState.new(
		REGION_GREY_MARCHES,
		"The Grey Marches",
		Vector2(480, 360),
		&"marshland",
		1.10,
		1.6, # Treacherous marsh quagmires
		"Ruined Outpost",
		&"", # Unclaimed
		&""  # No recognized sovereign claim
	)
	r_marches.primary_resources = [&"peat", &"bog_iron"]
	r_marches.regional_resources = {&"peat": 300, &"bog_iron": 200}
	r_marches.neighbors = [REGION_CROWNWEFT, REGION_OLD_GROVE, REGION_IRONPEAK]
	regions[REGION_GREY_MARCHES] = r_marches

	# 6. Contested Gateway Region
	var r_pass := RegionState.new(
		REGION_SHATTERED_PASS,
		"Shattered Pass",
		Vector2(380, 160),
		&"mountain_pass",
		1.35, # Strategic high-ground choke point
		1.4,
		"Contested Watchtower",
		&"", # Contested
		FactionCatalog.FACTION_IRONPEAK # Ironpeak claims historic dominion
	)
	r_pass.set_contested(true)
	r_pass.primary_resources = [&"stone", &"iron_ore"]
	r_pass.regional_resources = {&"stone": 400, &"iron_ore": 250}
	r_pass.neighbors = [REGION_CROWNWEFT, REGION_VALEN, REGION_IRONPEAK]
	regions[REGION_SHATTERED_PASS] = r_pass

	return regions

static func create_default_routes() -> Array[RegionRoute]:
	var routes: Array[RegionRoute] = []

	# 1. Crownweft <-> Valen
	routes.append(RegionRoute.new(
		&"route_crownweft_valen",
		REGION_CROWNWEFT,
		REGION_VALEN,
		60,
		RegionRoute.CONSTRAINT_PAVED_ROAD,
		4
	))

	# 2. Crownweft <-> Canopy
	routes.append(RegionRoute.new(
		&"route_crownweft_canopy",
		REGION_CROWNWEFT,
		REGION_OLD_GROVE,
		75,
		RegionRoute.CONSTRAINT_FOREST_TRAIL,
		5
	))

	# 3. Crownweft <-> Shattered Pass
	routes.append(RegionRoute.new(
		&"route_crownweft_pass",
		REGION_CROWNWEFT,
		REGION_SHATTERED_PASS,
		80,
		RegionRoute.CONSTRAINT_MOUNTAIN_PASS,
		8
	))

	# 4. Crownweft <-> Grey Marches
	routes.append(RegionRoute.new(
		&"route_crownweft_marches",
		REGION_CROWNWEFT,
		REGION_GREY_MARCHES,
		90,
		RegionRoute.CONSTRAINT_MARSH_CROSSING,
		10
	))

	# 5. Valen <-> Shattered Pass
	routes.append(RegionRoute.new(
		&"route_valen_pass",
		REGION_VALEN,
		REGION_SHATTERED_PASS,
		85,
		RegionRoute.CONSTRAINT_PAVED_ROAD,
		6
	))

	# 6. Valen <-> Canopy
	routes.append(RegionRoute.new(
		&"route_valen_canopy",
		REGION_VALEN,
		REGION_OLD_GROVE,
		100,
		RegionRoute.CONSTRAINT_FOREST_TRAIL,
		7
	))

	# 7. Shattered Pass <-> Ironpeak
	routes.append(RegionRoute.new(
		&"route_pass_ironpeak",
		REGION_SHATTERED_PASS,
		REGION_IRONPEAK,
		50,
		RegionRoute.CONSTRAINT_MOUNTAIN_PASS,
		6
	))

	# 8. Grey Marches <-> Ironpeak
	routes.append(RegionRoute.new(
		&"route_marches_ironpeak",
		REGION_GREY_MARCHES,
		REGION_IRONPEAK,
		110,
		RegionRoute.CONSTRAINT_MARSH_CROSSING,
		12
	))

	# 9. Canopy <-> Grey Marches
	routes.append(RegionRoute.new(
		&"route_canopy_marches",
		REGION_OLD_GROVE,
		REGION_GREY_MARCHES,
		120,
		RegionRoute.CONSTRAINT_FOREST_TRAIL,
		8
	))

	return routes
