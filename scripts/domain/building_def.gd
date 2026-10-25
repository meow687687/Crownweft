class_name BuildingDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var inventory_capacity: int = 50
@export var worker_slots: int = 2
@export var recipe_id: StringName = &""
@export var accepted_resources: Array[StringName] = []

func _init(p_id: StringName = &"", p_name: String = "", p_cap: int = 50, p_slots: int = 2, p_recipe: StringName = &"", p_accepted: Array[StringName] = []) -> void:
	id = p_id
	display_name = p_name
	inventory_capacity = p_cap
	worker_slots = p_slots
	recipe_id = p_recipe
	accepted_resources = p_accepted.duplicate()
