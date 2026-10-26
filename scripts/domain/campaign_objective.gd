class_name CampaignObjective
extends RefCounted

const TYPE_DEFEND_REGION: StringName = &"defend_region"
const TYPE_CONTEST_REGION: StringName = &"contest_region"
const TYPE_REPEL_ARMY: StringName = &"repel_army"
const TYPE_SECURE_ROUTE: StringName = &"secure_route"
const TYPE_OCCUPY_REGION: StringName = &"occupy_region"

const ALL_TYPES: Array[StringName] = [
	TYPE_DEFEND_REGION,
	TYPE_CONTEST_REGION,
	TYPE_REPEL_ARMY,
	TYPE_SECURE_ROUTE,
	TYPE_OCCUPY_REGION
]

const STATUS_PENDING: StringName = &"pending"
const STATUS_IN_PROGRESS: StringName = &"in_progress"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"

var id: int = 0
var owning_faction: StringName = &""
var faction_id: StringName:
	get:
		return owning_faction
	set(v):
		owning_faction = v

var type: StringName = TYPE_DEFEND_REGION
var description: String = ""
var target_region_id: StringName = &""
var target_army_id: int = -1
var target_route_id: StringName = &""
var war_id: int = -1
var status: StringName = STATUS_PENDING
var created_tick: int = 0
var target_tick: int = 0
var completion_tick: int = 0
var reason: String = ""

func _init(
	p_id: int = 0,
	p_faction: StringName = &"",
	p_type: StringName = TYPE_DEFEND_REGION,
	p_desc: String = "",
	p_target_region: StringName = &"",
	p_target_army: int = -1,
	p_war: int = -1,
	p_tick: int = 0
) -> void:
	id = p_id
	owning_faction = p_faction
	type = p_type
	description = p_desc
	target_region_id = p_target_region
	target_army_id = p_target_army
	war_id = p_war
	created_tick = p_tick
	status = STATUS_IN_PROGRESS

func is_active() -> bool:
	return status in [STATUS_PENDING, STATUS_IN_PROGRESS]

func complete(p_reason: String, p_tick: int) -> void:
	status = STATUS_COMPLETED
	completion_tick = p_tick
	reason = p_reason

func fail(p_reason: String, p_tick: int) -> void:
	status = STATUS_FAILED
	completion_tick = p_tick
	reason = p_reason

func get_title() -> String:
	match type:
		TYPE_DEFEND_REGION:
			return "Defend %s" % str(target_region_id).replace("_", " ").capitalize()
		TYPE_CONTEST_REGION:
			return "Contest %s" % str(target_region_id).replace("_", " ").capitalize()
		TYPE_REPEL_ARMY:
			return "Repel Hostile Force (Army #%d)" % target_army_id
		TYPE_SECURE_ROUTE:
			return "Secure Route %s" % str(target_route_id).replace("_", " ").capitalize()
		TYPE_OCCUPY_REGION:
			return "Occupy Strategic Region %s" % str(target_region_id).replace("_", " ").capitalize()
		_:
			return "Strategic Objective"

func serialize() -> Dictionary:
	return {
		"id": id,
		"owning_faction": str(owning_faction),
		"type": str(type),
		"description": description,
		"target_region_id": str(target_region_id),
		"target_army_id": target_army_id,
		"target_route_id": str(target_route_id),
		"war_id": war_id,
		"status": str(status),
		"created_tick": created_tick,
		"target_tick": target_tick,
		"completion_tick": completion_tick,
		"reason": reason
	}

static func deserialize(data: Dictionary) -> CampaignObjective:
	var obj := CampaignObjective.new(
		int(data.get("id", 0)),
		StringName(data.get("owning_faction", "")),
		StringName(data.get("type", "defend_region")),
		str(data.get("description", "")),
		StringName(data.get("target_region_id", "")),
		int(data.get("target_army_id", -1)),
		int(data.get("war_id", -1)),
		int(data.get("created_tick", 0))
	)
	obj.target_route_id = StringName(data.get("target_route_id", ""))
	obj.status = StringName(data.get("status", STATUS_PENDING))
	obj.target_tick = int(data.get("target_tick", 0))
	obj.completion_tick = int(data.get("completion_tick", 0))
	obj.reason = str(data.get("reason", ""))
	return obj
