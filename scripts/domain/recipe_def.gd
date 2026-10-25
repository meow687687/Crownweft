class_name RecipeDef
extends Resource

@export var id: StringName = &""
@export var inputs: Dictionary = {} # StringName -> int
@export var outputs: Dictionary = {} # StringName -> int
@export var required_workers: int = 1
@export var duration_ticks: int = 4

func _init(p_id: StringName = &"", p_inputs: Dictionary = {}, p_outputs: Dictionary = {}, p_workers: int = 1, p_duration: int = 4) -> void:
	id = p_id
	inputs = p_inputs
	outputs = p_outputs
	required_workers = p_workers
	duration_ticks = p_duration
