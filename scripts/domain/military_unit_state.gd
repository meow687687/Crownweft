class_name MilitaryUnitState
extends RefCounted

enum OrderType {
	HOLD,
	MOVE,
	ATTACK_MOVE,
	ATTACK_TARGET
}

@export var id: int = 0
@export var unit_definition_id: StringName = &"spearman"
@export var faction_id: int = 0 # 0 = player, 1 = raiders
@export var position: Vector2 = Vector2.ZERO
@export var health: int = 100
@export var max_health: int = 100

@export var order_type: OrderType = OrderType.HOLD
@export var target_pos: Vector2 = Vector2.ZERO
@export var target_unit_id: int = -1
@export var attack_timer: float = 0.0
@export var is_dead: bool = false
@export var is_starving: bool = false # Debuff when settlement lacks food upkeep

func _init(p_id: int = 0, p_def_id: StringName = &"spearman", p_faction: int = 0, p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	unit_definition_id = p_def_id
	faction_id = p_faction
	position = p_pos
	
	var defs: Dictionary = UnitDef.get_all_defs()
	var def: UnitDef = defs.get(unit_definition_id, null)
	if def != null:
		max_health = def.max_health
		health = def.max_health

func set_move_order(dest_pos: Vector2) -> void:
	order_type = OrderType.MOVE
	target_pos = dest_pos
	target_unit_id = -1

func set_attack_move_order(dest_pos: Vector2) -> void:
	order_type = OrderType.ATTACK_MOVE
	target_pos = dest_pos
	target_unit_id = -1

func set_attack_target_order(unit_id: int) -> void:
	order_type = OrderType.ATTACK_TARGET
	target_unit_id = unit_id

func set_hold_order() -> void:
	order_type = OrderType.HOLD
	target_unit_id = -1
