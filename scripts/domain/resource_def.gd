class_name ResourceDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var is_food: bool = false
@export var build_cost_allowed: bool = false
@export var stack_limit: int = 0 # 0 means limited only by inventory capacity
@export var debug_color: Color = Color.WHITE

func _init(p_id: StringName = &"", p_name: String = "", p_is_food: bool = false, p_build_allowed: bool = false, p_color: Color = Color.WHITE) -> void:
	id = p_id
	display_name = p_name
	is_food = p_is_food
	build_cost_allowed = p_build_allowed
	debug_color = p_color
