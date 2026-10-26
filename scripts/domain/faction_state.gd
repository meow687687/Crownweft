class_name FactionState
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var culture: StringName = &"valen"
var religion: StringName = &"pantheon"
var doctrine: StringName = &"communal_labor"

var treasury: int = 50
var resources: Dictionary = {}
var reserved_treasury: int = 0
var reserved_resources: Dictionary = {}
var military_power: int = 20

var active_goals: Array[StringName] = []
var memories: Array = []
var cooldowns: Dictionary = {}
var active_treaties: Array = []

var last_decision_tick: int = 0
var last_utility_breakdown: Dictionary = {}
var known_information: Dictionary = {}

func _init(p_id: StringName = &"") -> void:
	id = p_id
	if id != &"":
		var def_info: Dictionary = FactionCatalog.get_faction_def(id)
		display_name = def_info.get("display_name", str(id).capitalize())
		culture = def_info.get("culture", &"valen")
		religion = def_info.get("religion", &"pantheon")
		doctrine = def_info.get("doctrine", &"communal_labor")
		treasury = int(def_info.get("initial_treasury", 50))
		resources = (def_info.get("initial_resources", {}) as Dictionary).duplicate(true)
		military_power = int(def_info.get("initial_military", 20))
		active_goals.clear()
		for g in def_info.get("default_goals", []):
			active_goals.append(g)

func add_memory(
	p_tick: int,
	p_actor: StringName,
	p_target: StringName,
	p_type: StringName,
	p_severity: float,
	p_interp: String,
	p_retention: int = 600
) -> void:
	memories.append({
		"id": memories.size() + 1,
		"tick": p_tick,
		"actor": p_actor,
		"target": p_target,
		"event_type": p_type,
		"severity": p_severity,
		"interpretation": p_interp,
		"expires_tick": p_tick + p_retention,
		"confidence": 1.0
	})

func decay_memories(current_tick: int) -> void:
	var kept: Array[Dictionary] = []
	for m in memories:
		if current_tick < int(m.get("expires_tick", current_tick + 1)):
			kept.append(m)
	memories = kept

func set_cooldown(key: StringName, until_tick: int) -> void:
	cooldowns[key] = until_tick

func is_on_cooldown(key: StringName, current_tick: int) -> bool:
	if not cooldowns.has(key):
		return false
	return current_tick < int(cooldowns[key])

func add_treaty(treaty_type: StringName, with_faction: StringName, signed_tick: int, duration_ticks: int) -> void:
	# Avoid duplicates
	for t in active_treaties:
		if t.get("type", &"") == treaty_type and t.get("with_faction", &"") == with_faction:
			t["expires_tick"] = signed_tick + duration_ticks
			return
	active_treaties.append({
		"type": treaty_type,
		"with_faction": with_faction,
		"signed_tick": signed_tick,
		"expires_tick": signed_tick + duration_ticks if duration_ticks > 0 else -1
	})

func has_active_treaty(treaty_type: StringName, with_faction: StringName = &"") -> bool:
	for t in active_treaties:
		if t.get("type", &"") == treaty_type:
			if with_faction == &"" or t.get("with_faction", &"") == with_faction:
				return true
	return false

func clean_expired_treaties(current_tick: int) -> void:
	var valid: Array[Dictionary] = []
	for t in active_treaties:
		var exp: int = int(t.get("expires_tick", -1))
		if exp < 0 or current_tick <= exp:
			valid.append(t)
	active_treaties = valid

func get_available_treasury() -> int:
	return maxi(0, treasury - reserved_treasury)

func reserve_treasury(amount: int) -> bool:
	if amount <= 0:
		return false
	if get_available_treasury() < amount:
		return false
	reserved_treasury += amount
	return true

func release_reserved_treasury(amount: int) -> void:
	if amount <= 0:
		return
	reserved_treasury = maxi(0, reserved_treasury - amount)

func get_available_resource(res_id: StringName) -> int:
	return maxi(0, int(resources.get(res_id, 0)) - int(reserved_resources.get(res_id, 0)))

func reserve_resource(res_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if get_available_resource(res_id) < amount:
		return false
	reserved_resources[res_id] = int(reserved_resources.get(res_id, 0)) + amount
	return true

func release_reserved_resource(res_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var current: int = int(reserved_resources.get(res_id, 0))
	var new_val: int = maxi(0, current - amount)
	if new_val == 0:
		reserved_resources.erase(res_id)
	else:
		reserved_resources[res_id] = new_val

func serialize() -> Dictionary:
	var goals_arr: Array = []
	for g in active_goals:
		goals_arr.append(str(g))
	var res_res_dict: Dictionary = {}
	for k in reserved_resources:
		res_res_dict[str(k)] = int(reserved_resources[k])

	return {
		"id": id,
		"display_name": display_name,
		"culture": culture,
		"religion": religion,
		"doctrine": doctrine,
		"treasury": treasury,
		"resources": resources.duplicate(true),
		"reserved_treasury": reserved_treasury,
		"reserved_resources": res_res_dict,
		"military_power": military_power,
		"active_goals": goals_arr,
		"memories": memories.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"active_treaties": active_treaties.duplicate(true),
		"last_decision_tick": last_decision_tick,
		"last_utility_breakdown": last_utility_breakdown.duplicate(true),
		"known_information": known_information.duplicate(true)
	}

static func deserialize(dict: Dictionary) -> FactionState:
	var f := FactionState.new(&"")
	f.id = dict.get("id", &"")
	f.display_name = dict.get("display_name", "")
	f.culture = dict.get("culture", &"valen")
	f.religion = dict.get("religion", &"pantheon")
	f.doctrine = dict.get("doctrine", &"communal_labor")
	f.treasury = int(dict.get("treasury", 50))
	f.resources = (dict.get("resources", {}) as Dictionary).duplicate(true)
	f.reserved_treasury = int(dict.get("reserved_treasury", 0))
	var raw_rr: Dictionary = dict.get("reserved_resources", {})
	for k in raw_rr:
		f.reserved_resources[StringName(k)] = int(raw_rr[k])
	f.military_power = int(dict.get("military_power", 20))
	
	f.active_goals.clear()
	for g in dict.get("active_goals", []):
		f.active_goals.append(StringName(g))
		
	f.memories.clear()
	for m in dict.get("memories", []):
		if m is Dictionary:
			f.memories.append(m.duplicate(true))
	f.cooldowns = (dict.get("cooldowns", {}) as Dictionary).duplicate(true)
	f.active_treaties.clear()
	for t in dict.get("active_treaties", []):
		if t is Dictionary:
			f.active_treaties.append(t.duplicate(true))
	f.last_decision_tick = int(dict.get("last_decision_tick", 0))
	f.last_utility_breakdown = (dict.get("last_utility_breakdown", {}) as Dictionary).duplicate(true)
	f.known_information = (dict.get("known_information", {}) as Dictionary).duplicate(true)
	return f
