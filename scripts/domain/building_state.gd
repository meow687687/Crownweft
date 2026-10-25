class_name BuildingState
extends RefCounted

@export var entity_id: int = 0
@export var definition_id: StringName = &""
var inventory: Inventory = null
var assigned_workers: int = 0
var enabled: bool = true
var production_progress: int = 0
var current_block_reason: StringName = &""
var tile_origin: Vector2i = Vector2i.ZERO
var health: int = 100
var max_health: int = 100
var is_destroyed: bool = false

func _init(p_entity_id: int = 0, p_def_id: StringName = &"", p_capacity: int = 50, p_accepted: Array = []) -> void:
	entity_id = p_entity_id
	definition_id = p_def_id
	inventory = Inventory.new(p_entity_id, p_capacity, p_accepted)
