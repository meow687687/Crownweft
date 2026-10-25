class_name HaulJob
extends RefCounted

enum Status {
	REQUESTED,
	RESERVED,
	ASSIGNED,
	PICKUP,
	IN_TRANSIT,
	DELIVERED,
	CANCELLED,
	BLOCKED
}

@export var id: int = 0
@export var resource_id: StringName = &""
@export var amount: int = 0
@export var source_inventory_id: int = 0
@export var destination_inventory_id: int = 0
@export var priority: int = 0
@export var status: Status = Status.REQUESTED
@export var assigned_citizen_id: int = -1
@export var reserved_amount: int = 0
@export var created_tick: int = 0
@export var retry_tick: int = 0
@export var blocked_reason: String = ""

func _init(p_id: int = 0, p_resource: StringName = &"", p_amount: int = 0, p_source: int = 0, p_dest: int = 0, p_priority: int = 0, p_tick: int = 0) -> void:
	id = p_id
	resource_id = p_resource
	amount = p_amount
	source_inventory_id = p_source
	destination_inventory_id = p_dest
	priority = p_priority
	created_tick = p_tick
