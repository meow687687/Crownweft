class_name DiplomaticRelationship
extends RefCounted

const TRUST_MIN: float = -100.0
const TRUST_MAX: float = 100.0

const THREAT_MIN: float = 0.0
const THREAT_MAX: float = 100.0

const RESENTMENT_MIN: float = 0.0
const RESENTMENT_MAX: float = 100.0

const RESPECT_MIN: float = 0.0
const RESPECT_MAX: float = 100.0

const COOPERATION_MIN: float = 0.0
const COOPERATION_MAX: float = 100.0

var faction_a: StringName = &""
var faction_b: StringName = &""

var trust: float = 0.0
var threat: float = 10.0
var resentment: float = 0.0
var respect: float = 20.0
var economic_cooperation: float = 0.0

func _init(p_a: StringName = &"", p_b: StringName = &"", p_trust: float = 0.0, p_threat: float = 10.0, p_resentment: float = 0.0, p_respect: float = 20.0, p_coop: float = 0.0) -> void:
	faction_a = p_a
	faction_b = p_b
	trust = clampf(p_trust, TRUST_MIN, TRUST_MAX)
	threat = clampf(p_threat, THREAT_MIN, THREAT_MAX)
	resentment = clampf(p_resentment, RESENTMENT_MIN, RESENTMENT_MAX)
	respect = clampf(p_respect, RESPECT_MIN, RESPECT_MAX)
	economic_cooperation = clampf(p_coop, COOPERATION_MIN, COOPERATION_MAX)

func modify_trust(delta: float) -> void:
	trust = clampf(trust + delta, TRUST_MIN, TRUST_MAX)

func modify_threat(delta: float) -> void:
	threat = clampf(threat + delta, THREAT_MIN, THREAT_MAX)

func modify_resentment(delta: float) -> void:
	resentment = clampf(resentment + delta, RESENTMENT_MIN, RESENTMENT_MAX)

func modify_respect(delta: float) -> void:
	respect = clampf(respect + delta, RESPECT_MIN, RESPECT_MAX)

func modify_cooperation(delta: float) -> void:
	economic_cooperation = clampf(economic_cooperation + delta, COOPERATION_MIN, COOPERATION_MAX)

func serialize() -> Dictionary:
	return {
		"faction_a": faction_a,
		"faction_b": faction_b,
		"trust": trust,
		"threat": threat,
		"resentment": resentment,
		"respect": respect,
		"economic_cooperation": economic_cooperation
	}

static func deserialize(dict: Dictionary) -> DiplomaticRelationship:
	var rel := DiplomaticRelationship.new(
		dict.get("faction_a", &""),
		dict.get("faction_b", &""),
		float(dict.get("trust", 0.0)),
		float(dict.get("threat", 10.0)),
		float(dict.get("resentment", 0.0)),
		float(dict.get("respect", 20.0)),
		float(dict.get("economic_cooperation", 0.0))
	)
	return rel

func get_relationship_stance() -> String:
	if trust >= 40.0 and resentment <= 15.0:
		return "Friendly Alliance"
	elif trust >= 15.0 and resentment <= 25.0:
		return "Cordial"
	elif resentment >= 50.0:
		return "Hostile"
	elif resentment >= 30.0 or threat >= 50.0:
		return "Wary & Distrustful"
	else:
		return "Neutral & Cautious"
