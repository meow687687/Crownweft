class_name RegionState
extends RefCounted

const STATUS_CONTROLLED: StringName = &"controlled"
const STATUS_CONTESTED: StringName = &"contested"
const STATUS_OCCUPIED: StringName = &"occupied"
const STATUS_UNCLAIMED: StringName = &"unclaimed"

var id: StringName = &""
var display_name: String = ""
var map_pos: Vector2 = Vector2.ZERO
var terrain_type: StringName = &"valley"
var defensive_advantage: float = 1.0
var travel_difficulty: float = 1.0
var settlement_name: String = ""

var controlling_faction: StringName = &""
var claimed_by_faction: StringName = &""
var occupying_faction: StringName = &""
var is_contested: bool = false
var status: StringName = STATUS_UNCLAIMED

var neighbors: Array[StringName] = []
var primary_resources: Array[StringName] = []
var regional_resources: Dictionary = {} # StringName -> int
var control_transition_history: Array[Dictionary] = []

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_pos: Vector2 = Vector2.ZERO,
	p_terrain: StringName = &"valley",
	p_defensive: float = 1.0,
	p_travel: float = 1.0,
	p_settlement: String = "",
	p_controller: StringName = &"",
	p_claimant: StringName = &""
) -> void:
	id = p_id
	display_name = p_name
	map_pos = p_pos
	terrain_type = p_terrain
	defensive_advantage = maxf(0.5, p_defensive)
	travel_difficulty = maxf(0.5, p_travel)
	settlement_name = p_settlement
	controlling_faction = p_controller
	claimed_by_faction = p_claimant if p_claimant != &"" else p_controller
	occupying_faction = &""
	is_contested = false
	_update_status()

func _update_status() -> void:
	if occupying_faction != &"":
		status = STATUS_OCCUPIED
	elif is_contested:
		status = STATUS_CONTESTED
	elif controlling_faction != &"":
		status = STATUS_CONTROLLED
	else:
		status = STATUS_UNCLAIMED

func is_controlled_by(faction: StringName) -> bool:
	return controlling_faction == faction and occupying_faction == &""

func get_effective_controller() -> StringName:
	if occupying_faction != &"":
		return occupying_faction
	return controlling_faction

func has_settlement() -> bool:
	return settlement_name != ""

func set_claim(claimant: StringName) -> void:
	claimed_by_faction = claimant

func set_contested(contested: bool) -> void:
	is_contested = contested
	_update_status()

func set_occupation(occupier: StringName, reason: String, current_tick: int) -> void:
	var prev_occupier: StringName = occupying_faction
	occupying_faction = occupier
	_update_status()
	control_transition_history.append({
		"tick": current_tick,
		"transition": "occupation",
		"from_faction": str(prev_occupier if prev_occupier != &"" else controlling_faction),
		"to_faction": str(occupier),
		"reason": reason
	})

func clear_occupation(reason: String, current_tick: int) -> void:
	if occupying_faction == &"":
		return
	var prev_occupier: StringName = occupying_faction
	occupying_faction = &""
	_update_status()
	control_transition_history.append({
		"tick": current_tick,
		"transition": "occupation_ended",
		"from_faction": str(prev_occupier),
		"to_faction": str(controlling_faction),
		"reason": reason
	})

func set_control(new_controller: StringName, reason: String, current_tick: int, update_claim: bool = true) -> void:
	var prev_controller: StringName = controlling_faction
	controlling_faction = new_controller
	if update_claim:
		claimed_by_faction = new_controller
	occupying_faction = &""
	is_contested = false
	_update_status()
	control_transition_history.append({
		"tick": current_tick,
		"transition": "control_transfer",
		"from_faction": str(prev_controller),
		"to_faction": str(new_controller),
		"reason": reason
	})

func add_resource_stock(resource_id: StringName, amount: int) -> void:
	var current: int = int(regional_resources.get(resource_id, 0))
	regional_resources[resource_id] = maxi(0, current + amount)

func get_resource_stock(resource_id: StringName) -> int:
	return int(regional_resources.get(resource_id, 0))

func serialize() -> Dictionary:
	var prim_res: Array = []
	for r in primary_resources:
		prim_res.append(str(r))
	var neigh_arr: Array = []
	for n in neighbors:
		neigh_arr.append(str(n))
	var res_dict: Dictionary = {}
	for k in regional_resources:
		res_dict[str(k)] = int(regional_resources[k])
	return {
		"id": str(id),
		"display_name": display_name,
		"map_pos": [map_pos.x, map_pos.y],
		"terrain_type": str(terrain_type),
		"defensive_advantage": defensive_advantage,
		"travel_difficulty": travel_difficulty,
		"settlement_name": settlement_name,
		"controlling_faction": str(controlling_faction),
		"claimed_by_faction": str(claimed_by_faction),
		"occupying_faction": str(occupying_faction),
		"is_contested": is_contested,
		"status": str(status),
		"neighbors": neigh_arr,
		"primary_resources": prim_res,
		"regional_resources": res_dict,
		"control_transition_history": control_transition_history.duplicate(true)
	}

static func deserialize(data: Dictionary) -> RegionState:
	var pos_arr: Array = data.get("map_pos", [0.0, 0.0])
	var reg := RegionState.new(
		StringName(data.get("id", "")),
		str(data.get("display_name", "")),
		Vector2(float(pos_arr[0]), float(pos_arr[1])),
		StringName(data.get("terrain_type", "valley")),
		float(data.get("defensive_advantage", 1.0)),
		float(data.get("travel_difficulty", 1.0)),
		str(data.get("settlement_name", "")),
		StringName(data.get("controlling_faction", "")),
		StringName(data.get("claimed_by_faction", ""))
	)
	reg.occupying_faction = StringName(data.get("occupying_faction", ""))
	reg.is_contested = bool(data.get("is_contested", false))
	reg.status = StringName(data.get("status", STATUS_UNCLAIMED))
	
	reg.neighbors.clear()
	for n in data.get("neighbors", []):
		reg.neighbors.append(StringName(n))
		
	reg.primary_resources.clear()
	for r in data.get("primary_resources", []):
		reg.primary_resources.append(StringName(r))
		
	reg.regional_resources.clear()
	var raw_res: Dictionary = data.get("regional_resources", {})
	for k in raw_res:
		reg.regional_resources[StringName(k)] = int(raw_res[k])
		
	reg.control_transition_history.clear()
	for item in data.get("control_transition_history", []):
		if item is Dictionary:
			reg.control_transition_history.append(item.duplicate(true))
			
	return reg
