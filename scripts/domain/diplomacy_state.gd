class_name DiplomacyState
extends RefCounted

var factions: Dictionary = {} # StringName -> FactionState
var relationships: Dictionary = {} # String ("a:b") -> DiplomaticRelationship
var pending_proposals: Array[DiplomaticProposal] = []
var diplomatic_chronicle: Array = []
var proposal_counter: int = 1
var active_wars: Array[WarState] = []
var war_history: Array = []
var war_counter: int = 1

func _init() -> void:
	for f_id in FactionCatalog.FACTION_IDS:
		factions[f_id] = FactionState.new(f_id)
		
	# Initialize symmetric relationships
	for i in range(FactionCatalog.FACTION_IDS.size()):
		var f_a: StringName = FactionCatalog.FACTION_IDS[i]
		for j in range(i + 1, FactionCatalog.FACTION_IDS.size()):
			var f_b: StringName = FactionCatalog.FACTION_IDS[j]
			var rel := _create_initial_relationship(f_a, f_b)
			relationships[get_rel_key(f_a, f_b)] = rel

	# Record initial chronicle
	add_chronicle(0, "Regional emissaries established initial diplomatic contact with neighbouring realms.", &"establishment")

static func get_rel_key(a: StringName, b: StringName) -> String:
	if str(a) < str(b):
		return "%s:%s" % [str(a), str(b)]
	else:
		return "%s:%s" % [str(b), str(a)]

func get_relationship(a: StringName, b: StringName) -> DiplomaticRelationship:
	var key: String = get_rel_key(a, b)
	if not relationships.has(key):
		relationships[key] = DiplomaticRelationship.new(a, b)
	return relationships[key]

func _create_initial_relationship(a: StringName, b: StringName) -> DiplomaticRelationship:
	var rel := DiplomaticRelationship.new(a, b)
	# Tailored baseline relationships reflecting cultural affinities
	if (a == FactionCatalog.FACTION_PLAYER and b == FactionCatalog.FACTION_VALEN) or (b == FactionCatalog.FACTION_PLAYER and a == FactionCatalog.FACTION_VALEN):
		rel.trust = 15.0
		rel.respect = 25.0
		rel.economic_cooperation = 10.0
		rel.threat = 5.0
	elif (a == FactionCatalog.FACTION_PLAYER and b == FactionCatalog.FACTION_OLD_GROVE) or (b == FactionCatalog.FACTION_PLAYER and a == FactionCatalog.FACTION_OLD_GROVE):
		rel.trust = 5.0
		rel.respect = 20.0
		rel.threat = 10.0
	elif (a == FactionCatalog.FACTION_PLAYER and b == FactionCatalog.FACTION_IRONPEAK) or (b == FactionCatalog.FACTION_PLAYER and a == FactionCatalog.FACTION_IRONPEAK):
		rel.trust = 0.0
		rel.respect = 30.0
		rel.threat = 20.0
	return rel

func add_chronicle(tick: int, text: String, event_type: StringName = &"general") -> void:
	diplomatic_chronicle.append({
		"tick": tick,
		"text": text,
		"type": event_type
	})

func add_proposal(proposal: DiplomaticProposal) -> void:
	if proposal.id <= 0:
		proposal.id = proposal_counter
		proposal_counter += 1
	pending_proposals.append(proposal)

func find_proposal(id: int) -> DiplomaticProposal:
	for p in pending_proposals:
		if p.id == id:
			return p
	return null

func remove_proposal(id: int) -> void:
	var idx: int = -1
	for i in range(pending_proposals.size()):
		if pending_proposals[i].id == id:
			idx = i
			break
	if idx >= 0:
		pending_proposals.remove_at(idx)

func get_war_by_id(war_id: int) -> WarState:
	for w in active_wars:
		if w.id == war_id:
			return w
	for h in war_history:
		if h is WarState and h.id == war_id:
			return h
	return null

func get_active_war(fac_a: StringName, fac_b: StringName) -> WarState:
	for w in active_wars:
		if w.is_active():
			if (w.initiating_faction == fac_a and w.target_faction == fac_b) or (w.initiating_faction == fac_b and w.target_faction == fac_a):
				return w
	return null

func has_active_war(fac_a: StringName, fac_b: StringName = &"") -> bool:
	for w in active_wars:
		if w.is_active():
			if fac_b == &"":
				if w.initiating_faction == fac_a or w.target_faction == fac_a:
					return true
			else:
				if (w.initiating_faction == fac_a and w.target_faction == fac_b) or (w.initiating_faction == fac_b and w.target_faction == fac_a):
					return true
	return false

func create_war(init_fac: StringName, target_fac: StringName, reason: String, current_tick: int, initial_status: StringName = WarState.STATUS_CRISIS) -> WarState:
	var existing: WarState = get_active_war(init_fac, target_fac)
	if existing != null:
		return existing
	if init_fac == target_fac or init_fac == &"" or target_fac == &"":
		return null
		
	var w := WarState.new(war_counter, init_fac, target_fac, initial_status, reason, current_tick)
	war_counter += 1
	active_wars.append(w)
	return w

func serialize() -> Dictionary:
	var facs_dict: Dictionary = {}
	for f_id in factions:
		facs_dict[str(f_id)] = (factions[f_id] as FactionState).serialize()

	var rels_dict: Dictionary = {}
	for k in relationships:
		rels_dict[k] = (relationships[k] as DiplomaticRelationship).serialize()

	var props_arr: Array = []
	for p in pending_proposals:
		props_arr.append(p.serialize())

	var wars_arr: Array = []
	for w in active_wars:
		wars_arr.append(w.serialize())

	var hist_arr: Array = []
	for h in war_history:
		if h is WarState:
			hist_arr.append(h.serialize())
		elif h is Dictionary:
			hist_arr.append(h.duplicate(true))

	return {
		"factions": facs_dict,
		"relationships": rels_dict,
		"pending_proposals": props_arr,
		"diplomatic_chronicle": diplomatic_chronicle.duplicate(true),
		"proposal_counter": proposal_counter,
		"active_wars": wars_arr,
		"war_history": hist_arr,
		"war_counter": war_counter
	}

static func deserialize(dict: Dictionary) -> DiplomacyState:
	var state := DiplomacyState.new()
	var raw_facs: Dictionary = dict.get("factions", {})
	for f_str in raw_facs:
		var f_id := StringName(f_str)
		state.factions[f_id] = FactionState.deserialize(raw_facs[f_str])

	var raw_rels: Dictionary = dict.get("relationships", {})
	for k in raw_rels:
		state.relationships[k] = DiplomaticRelationship.deserialize(raw_rels[k])

	state.pending_proposals.clear()
	var raw_props: Array = dict.get("pending_proposals", [])
	for p_dict in raw_props:
		state.pending_proposals.append(DiplomaticProposal.deserialize(p_dict))

	state.diplomatic_chronicle = (dict.get("diplomatic_chronicle", []) as Array).duplicate(true)
	state.proposal_counter = int(dict.get("proposal_counter", 1))

	state.active_wars.clear()
	var raw_wars: Array = dict.get("active_wars", [])
	for w_dict in raw_wars:
		state.active_wars.append(WarState.deserialize(w_dict))

	state.war_history.clear()
	var raw_hist: Array = dict.get("war_history", [])
	for h in raw_hist:
		if h is Dictionary:
			state.war_history.append(h.duplicate(true))

	state.war_counter = int(dict.get("war_counter", 1))
	return state
