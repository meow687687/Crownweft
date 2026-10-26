class_name CitizenState
extends RefCounted

enum FoodState {
	FED,
	HUNGRY,
	AT_RISK
}

enum MoveState {
	IDLE,
	MOVING
}

@export var id: int = 0
@export var home_building_id: int = 0
@export var workplace_id: int = 0
@export var role_id: StringName = &"unassigned"
@export var position_tile: Vector2i = Vector2i.ZERO
@export var target_tile: Vector2i = Vector2i.ZERO
var path: Array[Vector2i] = []
@export var move_state: MoveState = MoveState.IDLE
@export var food_state: FoodState = FoodState.FED
@export var hunger_counter: int = 0 # Ticks since last meal
@export var carried_resource: StringName = &""
@export var carried_amount: int = 0
@export var active_job_id: int = 0
@export var current_block_reason: StringName = &""

func _init(p_id: int = 0, p_pos: Vector2i = Vector2i.ZERO, p_role: StringName = &"unassigned") -> void:
	id = p_id
	position_tile = p_pos
	target_tile = p_pos
	role_id = p_role
