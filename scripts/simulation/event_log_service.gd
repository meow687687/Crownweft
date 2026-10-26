class_name EventLogService
extends RefCounted

signal event_added(event_dict: Dictionary)

const MAX_HISTORY: int = 50
const DEFAULT_THROTTLE_TICKS: int = 24

var events: Array[Dictionary] = []
var _last_logged_ticks: Dictionary = {} # String -> int

func add_event(
	category: StringName,
	message: String,
	level: StringName = &"info",
	current_tick: int = 0,
	throttle_key: String = ""
) -> bool:
	if throttle_key != "":
		var last_tick: int = _last_logged_ticks.get(throttle_key, -999999)
		if current_tick - last_tick < DEFAULT_THROTTLE_TICKS:
			return false
		_last_logged_ticks[throttle_key] = current_tick

	var entry: Dictionary = {
		"tick": current_tick,
		"category": category,
		"message": message,
		"level": level,
		"timestamp": Time.get_time_string_from_system()
	}

	events.append(entry)
	if events.size() > MAX_HISTORY:
		events.pop_front()

	event_added.emit(entry)
	return true

func get_recent_events(limit: int = 20) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total: int = events.size()
	var start_idx: int = maxi(0, total - limit)
	for i in range(start_idx, total):
		result.append(events[i])
	return result

func get_events_by_category(category: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ev in events:
		if ev.get("category", &"") == category:
			result.append(ev)
	return result

func clear() -> void:
	events.clear()
	_last_logged_ticks.clear()

func serialize() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for e in events:
		copy.append(e.duplicate(true))
	return copy

func deserialize(data: Array) -> void:
	clear()
	for item in data:
		if item is Dictionary:
			events.append(item.duplicate(true))
