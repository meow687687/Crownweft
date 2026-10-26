class_name TradeShipment
extends RefCounted

const STATUS_PREPARING: StringName = &"preparing"
const STATUS_IN_TRANSIT: StringName = &"in_transit"
const STATUS_WAITING_ROUTE: StringName = &"waiting_route"
const STATUS_DELIVERED: StringName = &"delivered"
const STATUS_RETURNING: StringName = &"returning"
const STATUS_RETURNED: StringName = &"returned"
const STATUS_CANCELLED: StringName = &"cancelled"

var id: int = 0
var contract_id: int = 0
var carrier_faction_id: StringName = &""
var origin_region_id: StringName = &""
var destination_region_id: StringName = &""
var current_region_id: StringName = &""

var route_path: Array[StringName] = []
var path_index: int = 0
var segment_ticks_progress: float = 0.0
var segment_total_ticks: int = 0

var cargo: Dictionary = {} # StringName -> int
var status: StringName = STATUS_PREPARING
var blocked_reason: String = ""
var events: Array[Dictionary] = []
var created_tick: int = 0

func _init(
	p_id: int = 0,
	p_contract_id: int = 0,
	p_carrier: StringName = &"",
	p_origin: StringName = &"",
	p_dest: StringName = &"",
	p_cargo: Dictionary = {},
	p_tick: int = 0
) -> void:
	id = p_id
	contract_id = p_contract_id
	carrier_faction_id = p_carrier
	origin_region_id = p_origin
	destination_region_id = p_dest
	current_region_id = p_origin
	cargo = p_cargo.duplicate()
	created_tick = p_tick
	status = STATUS_PREPARING
	record_event(p_tick, "assembled", "Trade caravan assembled at %s carrying %s." % [str(p_origin), str(cargo)])

func is_active() -> bool:
	return status in [STATUS_PREPARING, STATUS_IN_TRANSIT, STATUS_WAITING_ROUTE, STATUS_RETURNING]

func can_transition_to(target: StringName) -> bool:
	if status == target:
		return true
	if status in [STATUS_DELIVERED, STATUS_RETURNED, STATUS_CANCELLED]:
		return false # Terminal states

	match status:
		STATUS_PREPARING:
			return target in [STATUS_IN_TRANSIT, STATUS_WAITING_ROUTE, STATUS_CANCELLED]
		STATUS_IN_TRANSIT:
			return target in [STATUS_WAITING_ROUTE, STATUS_DELIVERED, STATUS_RETURNING, STATUS_CANCELLED]
		STATUS_WAITING_ROUTE:
			return target in [STATUS_IN_TRANSIT, STATUS_RETURNING, STATUS_CANCELLED]
		STATUS_RETURNING:
			return target in [STATUS_RETURNED, STATUS_WAITING_ROUTE, STATUS_CANCELLED]
		_:
			return false

func transition_to(target: StringName, reason: String, current_tick: int) -> bool:
	if not can_transition_to(target):
		return false
	var prev: StringName = status
	status = target
	record_event(current_tick, "status_change", "Transitioned from %s to %s: %s" % [prev, target, reason])
	return true

func get_cargo(resource_id: StringName) -> int:
	return int(cargo.get(resource_id, 0))

func get_total_cargo() -> int:
	var total: int = 0
	for amt in cargo.values():
		total += int(amt)
	return total

func record_event(tick: int, event_type: String, details: String) -> void:
	events.append({
		"tick": tick,
		"event": event_type,
		"region": str(current_region_id),
		"details": details
	})

func serialize() -> Dictionary:
	var path_arr: Array = []
	for p in route_path:
		path_arr.append(str(p))
	var cargo_dict: Dictionary = {}
	for k in cargo:
		cargo_dict[str(k)] = int(cargo[k])

	return {
		"id": id,
		"contract_id": contract_id,
		"carrier_faction_id": str(carrier_faction_id),
		"origin_region_id": str(origin_region_id),
		"destination_region_id": str(destination_region_id),
		"current_region_id": str(current_region_id),
		"route_path": path_arr,
		"path_index": path_index,
		"segment_ticks_progress": segment_ticks_progress,
		"segment_total_ticks": segment_total_ticks,
		"cargo": cargo_dict,
		"status": str(status),
		"blocked_reason": blocked_reason,
		"created_tick": created_tick,
		"events": events.duplicate(true)
	}

static func deserialize(data: Dictionary) -> TradeShipment:
	var cargo_dict: Dictionary = {}
	var raw_cargo: Dictionary = data.get("cargo", {})
	for k in raw_cargo:
		cargo_dict[StringName(k)] = int(raw_cargo[k])

	var s := TradeShipment.new(
		int(data.get("id", 0)),
		int(data.get("contract_id", 0)),
		StringName(data.get("carrier_faction_id", "")),
		StringName(data.get("origin_region_id", "")),
		StringName(data.get("destination_region_id", "")),
		cargo_dict,
		int(data.get("created_tick", 0))
	)
	s.current_region_id = StringName(data.get("current_region_id", ""))

	s.route_path.clear()
	var raw_path: Array = data.get("route_path", [])
	for p in raw_path:
		s.route_path.append(StringName(p))

	s.path_index = int(data.get("path_index", 0))
	s.segment_ticks_progress = float(data.get("segment_ticks_progress", 0.0))
	s.segment_total_ticks = int(data.get("segment_total_ticks", 0))
	s.status = StringName(data.get("status", STATUS_PREPARING))
	s.blocked_reason = str(data.get("blocked_reason", ""))
	s.events = (data.get("events", []) as Array).duplicate(true)
	return s
