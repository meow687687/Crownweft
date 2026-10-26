class_name WarState
extends RefCounted

const STATUS_PEACE: StringName = &"peace"
const STATUS_CRISIS: StringName = &"crisis"
const STATUS_WAR: StringName = &"war"
const STATUS_CEASEFIRE: StringName = &"ceasefire"

const OUTCOME_ONGOING: StringName = &"ongoing"
const OUTCOME_WHITE_PEACE: StringName = &"white_peace"
const OUTCOME_VICTORY: StringName = &"victory"
const OUTCOME_DEFEAT: StringName = &"defeat"

var id: int = 0
var name: String = ""
var initiating_faction: StringName = &""
var target_faction: StringName = &""
var status: StringName = STATUS_PEACE
var reason: String = ""
var start_tick: int = 0
var resolution_tick: int = -1
var outcome: StringName = OUTCOME_ONGOING

var objectives: Array[StringName] = []
var casualties: Dictionary = {} # StringName (faction_id) -> int
var battles: Array = [] # Array of Dictionaries
var ceasefire_ticks_remaining: int = 0
var attacker_expedition_spawned: bool = false
var attacker_expedition_unit_ids: Array = []

func _init(
	p_id: int = 0,
	p_init_fac: StringName = &"",
	p_target_fac: StringName = &"",
	p_status: StringName = STATUS_PEACE,
	p_reason: String = "",
	p_tick: int = 0
) -> void:
	id = p_id
	initiating_faction = p_init_fac
	target_faction = p_target_fac
	status = p_status
	reason = p_reason
	start_tick = p_tick
	outcome = OUTCOME_ONGOING
	
	if initiating_faction != &"" and target_faction != &"":
		name = "%s War of Aggression against %s" % [
			str(initiating_faction).capitalize(),
			str(target_faction).capitalize()
		]
		casualties[str(initiating_faction)] = 0
		casualties[str(target_faction)] = 0

func can_transition_to(new_status: StringName) -> bool:
	if new_status == status:
		return false # Redundant transition
	if initiating_faction == target_faction or initiating_faction == &"" or target_faction == &"":
		return false # Invalid faction references
		
	match status:
		STATUS_PEACE:
			return new_status in [STATUS_CRISIS, STATUS_WAR]
		STATUS_CRISIS:
			return new_status in [STATUS_WAR, STATUS_PEACE]
		STATUS_WAR:
			return new_status in [STATUS_CEASEFIRE, STATUS_PEACE]
		STATUS_CEASEFIRE:
			return new_status in [STATUS_WAR, STATUS_PEACE]
		_:
			return false

func transition_to(new_status: StringName, current_tick: int, reason_msg: String = "") -> bool:
	if not can_transition_to(new_status):
		return false

	var old_status: StringName = status
	status = new_status

	if new_status == STATUS_WAR and old_status != STATUS_CEASEFIRE:
		start_tick = current_tick
	elif new_status == STATUS_CEASEFIRE:
		ceasefire_ticks_remaining = 240 # Default truce period
	elif new_status == STATUS_PEACE:
		resolution_tick = current_tick
		if outcome == OUTCOME_ONGOING:
			outcome = OUTCOME_WHITE_PEACE
		ceasefire_ticks_remaining = 0

	return true

func record_casualty(faction: StringName, count: int = 1) -> void:
	var key: String = str(faction)
	casualties[key] = int(casualties.get(key, 0)) + count

func record_battle(tick: int, desc: String, att_losses: int, def_losses: int, res: StringName) -> void:
	battles.append({
		"tick": tick,
		"description": desc,
		"attacker_losses": att_losses,
		"defender_losses": def_losses,
		"result": res
	})

func is_active() -> bool:
	return status in [STATUS_CRISIS, STATUS_WAR, STATUS_CEASEFIRE]

func serialize() -> Dictionary:
	var obj_arr: Array = []
	for o in objectives:
		obj_arr.append(str(o))
	return {
		"id": id,
		"name": name,
		"initiating_faction": initiating_faction,
		"target_faction": target_faction,
		"status": status,
		"reason": reason,
		"start_tick": start_tick,
		"resolution_tick": resolution_tick,
		"outcome": outcome,
		"objectives": obj_arr,
		"casualties": casualties.duplicate(true),
		"battles": battles.duplicate(true),
		"ceasefire_ticks_remaining": ceasefire_ticks_remaining,
		"attacker_expedition_spawned": attacker_expedition_spawned,
		"attacker_expedition_unit_ids": attacker_expedition_unit_ids.duplicate(true)
	}

static func deserialize(dict: Dictionary) -> WarState:
	var w := WarState.new(
		int(dict.get("id", 0)),
		dict.get("initiating_faction", &""),
		dict.get("target_faction", &""),
		dict.get("status", STATUS_PEACE),
		dict.get("reason", ""),
		int(dict.get("start_tick", 0))
	)
	w.name = dict.get("name", "")
	w.resolution_tick = int(dict.get("resolution_tick", -1))
	w.outcome = dict.get("outcome", OUTCOME_ONGOING)
	
	w.objectives.clear()
	for o in dict.get("objectives", []):
		w.objectives.append(StringName(o))
		
	w.casualties = (dict.get("casualties", {}) as Dictionary).duplicate(true)
	
	w.battles.clear()
	for b in dict.get("battles", []):
		if b is Dictionary:
			w.battles.append(b.duplicate(true))
			
	w.ceasefire_ticks_remaining = int(dict.get("ceasefire_ticks_remaining", 0))
	w.attacker_expedition_spawned = bool(dict.get("attacker_expedition_spawned", false))
	
	w.attacker_expedition_unit_ids.clear()
	for uid in dict.get("attacker_expedition_unit_ids", []):
		w.attacker_expedition_unit_ids.append(int(uid))
		
	return w
