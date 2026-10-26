class_name ArmyState
extends RefCounted

const STATUS_GARRISONED: StringName = &"garrisoned"
const STATUS_PREPARING: StringName = &"preparing"
const STATUS_MARCHING: StringName = &"marching"
const STATUS_SUPPLY_STRAINED: StringName = &"supply_strained"
const STATUS_ENGAGED: StringName = &"engaged"
const STATUS_RETREATING: StringName = &"retreating"
const STATUS_DISBANDED: StringName = &"disbanded"
const STATUS_DESTROYED: StringName = &"destroyed"

const SUPPLY_RATE_MARCHING: float = 0.20  # 1 grain every 5 ticks
const SUPPLY_RATE_GARRISONED: float = 0.05 # 1 grain every 20 ticks

var id: int = 0
var faction_id: StringName = &""
var name: String = ""
var current_region_id: StringName = &""
var destination_region_id: StringName = &""

# Route navigation
var route_path: Array[StringName] = []
var path_index: int = 0
var segment_ticks_progress: float = 0.0
var segment_total_ticks: int = 0

var status: StringName = STATUS_GARRISONED
var unit_roster: Dictionary = {} # StringName -> int
var strength: int = 0

# Supplies
var supplies: Dictionary = {} # StringName -> float
var max_supply_capacity: int = 100
var supply_line_connected: bool = true
var supply_source_region_id: StringName = &""
var blocked_reason: String = ""

# Campaign link
var war_id: int = -1
var created_tick: int = 0
var events: Array[Dictionary] = []

func _init(
	p_id: int = 0,
	p_faction: StringName = &"",
	p_name: String = "",
	p_region: StringName = &"",
	p_roster: Dictionary = {},
	p_supplies: int = 30,
	p_tick: int = 0
) -> void:
	id = p_id
	faction_id = p_faction
	name = p_name
	current_region_id = p_region
	destination_region_id = p_region
	created_tick = p_tick
	status = STATUS_GARRISONED

	unit_roster = p_roster.duplicate()
	strength = _calculate_strength()

	supplies[&"grain"] = float(p_supplies)
	record_event(p_tick, "assembled", "Army %s assembled at %s." % [name, str(p_region)])

func _calculate_strength() -> int:
	var total: int = 0
	for k in unit_roster:
		total += int(unit_roster[k])
	return maxi(total, 1)

func can_transition_to(target: StringName) -> bool:
	if status == target:
		return true
	if status in [STATUS_DISBANDED, STATUS_DESTROYED]:
		return false # Terminal states

	match status:
		STATUS_GARRISONED:
			return target in [STATUS_PREPARING, STATUS_MARCHING, STATUS_DISBANDED]
		STATUS_PREPARING:
			return target in [STATUS_MARCHING, STATUS_GARRISONED, STATUS_DISBANDED]
		STATUS_MARCHING:
			return target in [STATUS_SUPPLY_STRAINED, STATUS_ENGAGED, STATUS_RETREATING, STATUS_GARRISONED, STATUS_DESTROYED]
		STATUS_SUPPLY_STRAINED:
			return target in [STATUS_MARCHING, STATUS_RETREATING, STATUS_GARRISONED, STATUS_ENGAGED, STATUS_DESTROYED]
		STATUS_ENGAGED:
			return target in [STATUS_MARCHING, STATUS_RETREATING, STATUS_GARRISONED, STATUS_DESTROYED]
		STATUS_RETREATING:
			return target in [STATUS_GARRISONED, STATUS_SUPPLY_STRAINED, STATUS_DESTROYED]
		_:
			return false

func transition_to(target: StringName, reason: String, current_tick: int) -> bool:
	if not can_transition_to(target):
		return false
	var prev: StringName = status
	status = target
	record_event(current_tick, "status_change", "Transitioned from %s to %s: %s" % [prev, target, reason])
	return true

func consume_supplies(is_moving: bool, current_tick: int) -> void:
	var rate: float = SUPPLY_RATE_MARCHING if is_moving else SUPPLY_RATE_GARRISONED
	var current: float = float(supplies.get(&"grain", 0.0))
	var updated: float = maxf(0.0, current - rate)
	supplies[&"grain"] = updated

	if updated <= 0.001 and status == STATUS_MARCHING:
		transition_to(STATUS_SUPPLY_STRAINED, "Rations fully exhausted", current_tick)
		blocked_reason = "Exhausted supplies"

func add_supplies(resource: StringName, amount: int, current_tick: int) -> int:
	if amount <= 0:
		return 0
	var current: float = float(supplies.get(resource, 0.0))
	var room: float = maxf(0.0, float(max_supply_capacity) - current)
	var to_add: float = minf(float(amount), room)
	supplies[resource] = current + to_add

	record_event(current_tick, "resupplied", "Received %d %s (Current: %.1f/%d)" % [int(to_add), str(resource), supplies[resource], max_supply_capacity])

	if status == STATUS_SUPPLY_STRAINED and float(supplies.get(&"grain", 0.0)) >= 5.0:
		if destination_region_id != &"" and destination_region_id != current_region_id:
			transition_to(STATUS_MARCHING, "Resupplied with emergency rations", current_tick)
			blocked_reason = ""
		else:
			transition_to(STATUS_GARRISONED, "Resupplied at garrison", current_tick)
			blocked_reason = ""

	return int(to_add)

func get_supplies(resource: StringName = &"grain") -> float:
	return float(supplies.get(resource, 0.0))

func record_event(tick: int, event_type: String, details: String) -> void:
	events.append({
		"tick": tick,
		"event": event_type,
		"region": str(current_region_id),
		"details": details
	})

func is_active() -> bool:
	return status not in [STATUS_DISBANDED, STATUS_DESTROYED]

func serialize() -> Dictionary:
	var path_arr: Array = []
	for p in route_path:
		path_arr.append(str(p))
	var roster_dict: Dictionary = {}
	for k in unit_roster:
		roster_dict[str(k)] = int(unit_roster[k])
	var supp_dict: Dictionary = {}
	for k in supplies:
		supp_dict[str(k)] = float(supplies[k])

	return {
		"id": id,
		"faction_id": str(faction_id),
		"name": name,
		"current_region_id": str(current_region_id),
		"destination_region_id": str(destination_region_id),
		"route_path": path_arr,
		"path_index": path_index,
		"segment_ticks_progress": segment_ticks_progress,
		"segment_total_ticks": segment_total_ticks,
		"status": str(status),
		"unit_roster": roster_dict,
		"strength": strength,
		"supplies": supp_dict,
		"max_supply_capacity": max_supply_capacity,
		"supply_line_connected": supply_line_connected,
		"supply_source_region_id": str(supply_source_region_id),
		"blocked_reason": blocked_reason,
		"war_id": war_id,
		"created_tick": created_tick,
		"events": events.duplicate(true)
	}

static func deserialize(data: Dictionary) -> ArmyState:
	var roster: Dictionary = {}
	var raw_roster: Dictionary = data.get("unit_roster", {})
	for k in raw_roster:
		roster[StringName(k)] = int(raw_roster[k])

	var army := ArmyState.new(
		int(data.get("id", 0)),
		StringName(data.get("faction_id", "")),
		str(data.get("name", "")),
		StringName(data.get("current_region_id", "")),
		roster,
		0,
		int(data.get("created_tick", 0))
	)

	army.destination_region_id = StringName(data.get("destination_region_id", ""))
	army.status = StringName(data.get("status", STATUS_GARRISONED))
	army.strength = int(data.get("strength", army.strength))
	army.path_index = int(data.get("path_index", 0))
	army.segment_ticks_progress = float(data.get("segment_ticks_progress", 0.0))
	army.segment_total_ticks = int(data.get("segment_total_ticks", 0))
	army.max_supply_capacity = int(data.get("max_supply_capacity", 100))
	army.supply_line_connected = bool(data.get("supply_line_connected", true))
	army.supply_source_region_id = StringName(data.get("supply_source_region_id", ""))
	army.blocked_reason = str(data.get("blocked_reason", ""))
	army.war_id = int(data.get("war_id", -1))

	army.route_path.clear()
	for p in data.get("route_path", []):
		army.route_path.append(StringName(p))

	army.supplies.clear()
	var raw_supp: Dictionary = data.get("supplies", {})
	for k in raw_supp:
		army.supplies[StringName(k)] = float(raw_supp[k])

	army.events.clear()
	for ev in data.get("events", []):
		if ev is Dictionary:
			army.events.append(ev.duplicate(true))

	return army
