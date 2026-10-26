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
@export var species_id: StringName = SpeciesCatalog.DEFAULT_SPECIES_ID
@export var social_status_id: StringName = SocialClassCatalog.DEFAULT_STATUS_ID
@export var last_status_transition_reason: String = ""
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

func _init(p_id: int = 0, p_pos: Vector2i = Vector2i.ZERO, p_role: StringName = &"unassigned", p_species: StringName = &"", p_status: StringName = &"") -> void:
	id = p_id
	species_id = SpeciesCatalog.validate_species_id(p_species) if p_species != &"" else SpeciesCatalog.DEFAULT_SPECIES_ID
	social_status_id = SocialClassCatalog.validate_status_id(p_status) if p_status != &"" else SocialClassCatalog.DEFAULT_STATUS_ID
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
		var base_val: float = 40.0 + float(absi((id * prime + seed_offset) % 21))
		var species_mod: float = SpeciesCatalog.get_starting_skill_modifier(species_id, s)
		skills[s] = clampf(base_val + species_mod, MIN_SKILL, MAX_SKILL)

func get_skill(skill_name: StringName) -> float:
	if not skills.has(skill_name):
		return DEFAULT_SKILL
	return clampf(float(skills[skill_name]), MIN_SKILL, MAX_SKILL)

func set_skill(skill_name: StringName, value: float) -> void:
	skills[skill_name] = clampf(value, MIN_SKILL, MAX_SKILL)

func get_skill_factor(skill_name: StringName) -> float:
	# Bounded formula: 0.75 at skill 0, 1.00 at skill 50, 1.25 at skill 100
	var sk: float = get_skill(skill_name)
	var base_factor: float = 0.75 + (sk / 200.0)
	var species_mod: float = SpeciesCatalog.get_performance_modifier(species_id, skill_name)
	var status_mod: float = SocialClassCatalog.get_crafting_modifier(social_status_id, skill_name)
	return clampf(base_factor + species_mod + status_mod, 0.60, 1.45)

func gain_experience(skill_name: StringName, base_amount: float = 0.5) -> float:
	if not SKILL_NAMES.has(skill_name):
		return 0.0
	var cur: float = get_skill(skill_name)
	# Diminishing returns: lower gains as skill approaches MAX_SKILL
	var factor: float = maxf(0.0, 1.0 - (cur / MAX_SKILL))
	var learn_mod: float = SocialClassCatalog.get_learning_modifier(social_status_id)
	var gain: float = base_amount * factor * learn_mod
	set_skill(skill_name, cur + gain)
	return gain

func can_perform_role(role_name: StringName) -> bool:
	if role_name == &"hauler" and SocialClassCatalog.refuses_manual_hauling(social_status_id):
		return false
	return true

func set_social_status(new_status: StringName, reason: String = "") -> void:
	social_status_id = SocialClassCatalog.validate_status_id(new_status)
	last_status_transition_reason = reason

func consume_energy(amount: float) -> void:
	var drain_mod: float = SpeciesCatalog.get_energy_drain_modifier(species_id)
	energy = clampf(energy - (amount * drain_mod), MIN_ENERGY, MAX_ENERGY)

func restore_energy(amount: float) -> void:
	var rec_mod: float = SpeciesCatalog.get_energy_recovery_modifier(species_id)
	energy = clampf(energy + (amount * rec_mod), MIN_ENERGY, MAX_ENERGY)

func is_exhausted() -> bool:
	return energy <= EXHAUSTION_THRESHOLD

func is_recovered() -> bool:
	return energy >= RECOVERY_THRESHOLD
