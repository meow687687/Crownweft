class_name RegionalEngagement
extends RefCounted

const STATUS_DETECTED: StringName = &"detected"
const STATUS_ENGAGING: StringName = &"engaging"
const STATUS_RESOLVED: StringName = &"resolved"

const STATE_DETECTED: StringName = STATUS_DETECTED
const STATE_ENGAGING: StringName = STATUS_ENGAGING
const STATE_RESOLVED: StringName = STATUS_RESOLVED

const OUTCOME_ATTACKER_VICTORY: StringName = &"attacker_victory"
const OUTCOME_DEFENDER_VICTORY: StringName = &"defender_victory"
const OUTCOME_STALEMATE: StringName = &"stalemate"
const OUTCOME_PENDING: StringName = &"pending"

var id: int = 0
var war_id: int = -1
var region_id: StringName = &""
var attacker_army_id: int = 0
var defender_army_id: int = 0
var attacker_faction: StringName = &""
var defender_faction: StringName = &""

var attacker_faction_id: StringName:
	get:
		return attacker_faction
	set(v):
		attacker_faction = v

var defender_faction_id: StringName:
	get:
		return defender_faction
	set(v):
		defender_faction = v

var status: StringName = STATUS_DETECTED
var state: StringName:
	get:
		return status
	set(v):
		status = v

var outcome: StringName = OUTCOME_PENDING
var start_tick: int = 0
var resolution_tick: int = 0
var resolved_tick: int:
	get:
		return resolution_tick
	set(v):
		resolution_tick = v

var attacker_initial_strength: int = 0
var defender_initial_strength: int = 0
var attacker_supply_factor: float = 1.0
var defender_supply_factor: float = 1.0
var terrain_defensive_factor: float = 1.0

var attacker_losses: int = 0
var attacker_casualties: int:
	get:
		return attacker_losses
	set(v):
		attacker_losses = v

var defender_losses: int = 0
var defender_casualties: int:
	get:
		return defender_losses
	set(v):
		defender_losses = v

var attacker_surviving_strength: int = 0
var defender_surviving_strength: int = 0
var winner_faction: StringName = &""
var occupation_established: bool = false
var diagnostics: Dictionary = {}

func _init(
	p_id: int = 0,
	p_region: StringName = &"",
	p_att_id: int = 0,
	p_att_fac: StringName = &"",
	p_def_id: int = 0,
	p_def_fac: StringName = &"",
	p_war_id: int = -1,
	p_tick: int = 0
) -> void:
	id = p_id
	region_id = p_region
	attacker_army_id = p_att_id
	attacker_faction = p_att_fac
	defender_army_id = p_def_id
	defender_faction = p_def_fac
	war_id = p_war_id
	start_tick = p_tick
	status = STATUS_DETECTED
	outcome = OUTCOME_PENDING

func is_resolved() -> bool:
	return status == STATUS_RESOLVED

func record_initial_metrics(
	att_str: int,
	def_str: int,
	att_supp: float,
	def_supp: float,
	terrain_def: float
) -> void:
	status = STATUS_ENGAGING
	attacker_initial_strength = att_str
	defender_initial_strength = def_str
	attacker_supply_factor = att_supp
	defender_supply_factor = def_supp
	terrain_defensive_factor = terrain_def
	diagnostics["attacker_power"] = float(att_str) * att_supp
	diagnostics["defender_power"] = float(def_str) * def_supp * terrain_def

func resolve_engagement(p_outcome: StringName, att_loss: int, def_loss: int, p_tick: int) -> void:
	status = STATUS_RESOLVED
	outcome = p_outcome
	resolution_tick = p_tick
	attacker_losses = att_loss
	defender_losses = def_loss
	attacker_surviving_strength = maxi(0, attacker_initial_strength - att_loss)
	defender_surviving_strength = maxi(0, defender_initial_strength - def_loss)
	if outcome == OUTCOME_ATTACKER_VICTORY:
		winner_faction = attacker_faction
	elif outcome == OUTCOME_DEFENDER_VICTORY:
		winner_faction = defender_faction
	else:
		winner_faction = &""

func serialize() -> Dictionary:
	return {
		"id": id,
		"war_id": war_id,
		"region_id": str(region_id),
		"attacker_army_id": attacker_army_id,
		"defender_army_id": defender_army_id,
		"attacker_faction": str(attacker_faction),
		"defender_faction": str(defender_faction),
		"status": str(status),
		"outcome": str(outcome),
		"start_tick": start_tick,
		"resolution_tick": resolution_tick,
		"attacker_initial_strength": attacker_initial_strength,
		"defender_initial_strength": defender_initial_strength,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"attacker_surviving_strength": attacker_surviving_strength,
		"defender_surviving_strength": defender_surviving_strength,
		"winner_faction": str(winner_faction),
		"occupation_established": occupation_established,
		"diagnostics": diagnostics.duplicate(true)
	}

static func deserialize(data: Dictionary) -> RegionalEngagement:
	var eng := RegionalEngagement.new(
		int(data.get("id", 0)),
		StringName(data.get("region_id", "")),
		int(data.get("attacker_army_id", 0)),
		StringName(data.get("attacker_faction", "")),
		int(data.get("defender_army_id", 0)),
		StringName(data.get("defender_faction", "")),
		int(data.get("war_id", -1)),
		int(data.get("start_tick", 0))
	)
	eng.status = StringName(data.get("status", STATUS_DETECTED))
	eng.outcome = StringName(data.get("outcome", OUTCOME_PENDING))
	eng.resolution_tick = int(data.get("resolution_tick", 0))
	eng.attacker_initial_strength = int(data.get("attacker_initial_strength", 0))
	eng.defender_initial_strength = int(data.get("defender_initial_strength", 0))
	eng.attacker_losses = int(data.get("attacker_losses", 0))
	eng.defender_losses = int(data.get("defender_losses", 0))
	eng.attacker_surviving_strength = int(data.get("attacker_surviving_strength", 0))
	eng.defender_surviving_strength = int(data.get("defender_surviving_strength", 0))
	eng.winner_faction = StringName(data.get("winner_faction", ""))
	eng.occupation_established = bool(data.get("occupation_established", false))
	eng.diagnostics = data.get("diagnostics", {}).duplicate(true)
	return eng
