class_name RegionRoute
extends RefCounted

const CONSTRAINT_PAVED_ROAD: StringName = &"paved_road"
const CONSTRAINT_FOREST_TRAIL: StringName = &"forest_trail"
const CONSTRAINT_MOUNTAIN_PASS: StringName = &"mountain_pass"
const CONSTRAINT_MARSH_CROSSING: StringName = &"marsh_crossing"
const CONSTRAINT_RIVER_CROSSING: StringName = &"river_crossing"

var id: StringName = &""
var region_a: StringName = &""
var region_b: StringName = &""
var travel_ticks: int = 60
var traversal_constraint: StringName = CONSTRAINT_PAVED_ROAD
var supply_cost_coin: int = 5
var is_open: bool = true
var blocked_reason: String = ""

func _init(
	p_id: StringName = &"",
	p_a: StringName = &"",
	p_b: StringName = &"",
	p_ticks: int = 60,
	p_constraint: StringName = CONSTRAINT_PAVED_ROAD,
	p_supply_cost: int = 5,
	p_open: bool = true,
	p_blocked_reason: String = ""
) -> void:
	id = p_id
	region_a = p_a
	region_b = p_b
	travel_ticks = maxi(1, p_ticks)
	traversal_constraint = p_constraint
	supply_cost_coin = maxi(0, p_supply_cost)
	is_open = p_open
	blocked_reason = p_blocked_reason

func connects(r1: StringName, r2: StringName) -> bool:
	return (region_a == r1 and region_b == r2) or (region_a == r2 and region_b == r1)

func has_endpoint(r: StringName) -> bool:
	return region_a == r or region_b == r

func get_other_region(r: StringName) -> StringName:
	if region_a == r:
		return region_b
	elif region_b == r:
		return region_a
	return &""

func set_blocked(blocked: bool, reason: String = "") -> void:
	is_open = not blocked
	blocked_reason = reason if blocked else ""

func serialize() -> Dictionary:
	return {
		"id": str(id),
		"region_a": str(region_a),
		"region_b": str(region_b),
		"travel_ticks": travel_ticks,
		"traversal_constraint": str(traversal_constraint),
		"supply_cost_coin": supply_cost_coin,
		"is_open": is_open,
		"blocked_reason": blocked_reason
	}

static func deserialize(data: Dictionary) -> RegionRoute:
	return RegionRoute.new(
		StringName(data.get("id", "")),
		StringName(data.get("region_a", "")),
		StringName(data.get("region_b", "")),
		int(data.get("travel_ticks", 60)),
		StringName(data.get("traversal_constraint", "paved_road")),
		int(data.get("supply_cost_coin", 5)),
		bool(data.get("is_open", true)),
		str(data.get("blocked_reason", ""))
	)
