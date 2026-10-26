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

const SKILL_NAMES: Array[StringName] = [&"farming", &"forestry", &"masonry", &"crafting", &"hauling"]
const MIN_SKILL: float = 0.0
const MAX_SKILL: float = 100.0
const DEFAULT_SKILL: float = 50.0

const MAX_ENERGY: float = 100.0
const MIN_ENERGY: float = 0.0
const EXHAUSTION_THRESHOLD: float = 20.0
const RECOVERY_THRESHOLD: float = 80.0
const WORK_ENERGY_DRAIN: float = 0.5
const REST_ENERGY_RECOVERY: float = 2.0
const IDLE_ENERGY_DRAIN: float = 0.02

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

@export var energy: float = MAX_ENERGY
@export var is_resting: bool = false
var skills: Dictionary = {} # StringName -> float

func _init(p_id: int = 0, p_pos: Vector2i = Vector2i.ZERO, p_role: StringName = &"unassigned") -> void:
	id = p_id
	position_tile = p_pos
	target_tile = p_pos
	role_id = p_role
	energy = MAX_ENERGY
	is_resting = false
	init_starting_skills()

func init_starting_skills(seed_offset: int = 0) -> void:
	var primes: Dictionary = {
		&"farming": 17,
		&"forestry": 31,
		&"masonry": 47,
		&"crafting": 61,
		&"hauling": 79
	}
	for s: StringName in SKILL_NAMES:
		var prime: int = primes.get(s, 13)
		var var_val: float = 40.0 + float(absi((id * prime + seed_offset) % 21))
		skills[s] = clampf(var_val, MIN_SKILL, MAX_SKILL)

func get_skill(skill_name: StringName) -> float:
	if not skills.has(skill_name):
		return DEFAULT_SKILL
	return clampf(float(skills[skill_name]), MIN_SKILL, MAX_SKILL)

func set_skill(skill_name: StringName, value: float) -> void:
	skills[skill_name] = clampf(value, MIN_SKILL, MAX_SKILL)

func get_skill_factor(skill_name: StringName) -> float:
	# Bounded formula: 0.75 at skill 0, 1.00 at skill 50, 1.25 at skill 100
	var sk: float = get_skill(skill_name)
	return clampf(0.75 + (sk / 200.0), 0.75, 1.25)

func gain_experience(skill_name: StringName, base_amount: float = 0.5) -> float:
	if not SKILL_NAMES.has(skill_name):
		return 0.0
	var cur: float = get_skill(skill_name)
	# Diminishing returns: lower gains as skill approaches MAX_SKILL
	var factor: float = maxf(0.0, 1.0 - (cur / MAX_SKILL))
	var gain: float = base_amount * factor
	set_skill(skill_name, cur + gain)
	return gain

func consume_energy(amount: float) -> void:
	energy = clampf(energy - amount, MIN_ENERGY, MAX_ENERGY)

func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, MIN_ENERGY, MAX_ENERGY)

func is_exhausted() -> bool:
	return energy <= EXHAUSTION_THRESHOLD

func is_recovered() -> bool:
	return energy >= RECOVERY_THRESHOLD
