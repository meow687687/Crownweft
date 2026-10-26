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
@export var culture_id: StringName = CultureCatalog.DEFAULT_CULTURE_ID
@export var religion_id: StringName = ReligionCatalog.DEFAULT_RELIGION_ID
@export var doctrine_id: StringName = DoctrineCatalog.DEFAULT_DOCTRINE_ID
var convictions: Dictionary = {} # StringName -> Variant
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

func _init(
	p_id: int = 0,
	p_pos: Vector2i = Vector2i.ZERO,
	p_role: StringName = &"unassigned",
	p_species: StringName = &"",
	p_status: StringName = &"",
	p_culture: StringName = &"",
	p_religion: StringName = &"",
	p_doctrine: StringName = &""
) -> void:
	id = p_id
	species_id = SpeciesCatalog.validate_species_id(p_species) if p_species != &"" else SpeciesCatalog.DEFAULT_SPECIES_ID
	social_status_id = SocialClassCatalog.validate_status_id(p_status) if p_status != &"" else SocialClassCatalog.DEFAULT_STATUS_ID
	culture_id = CultureCatalog.validate_culture_id(p_culture) if p_culture != &"" else CultureCatalog.DEFAULT_CULTURE_ID
	religion_id = ReligionCatalog.validate_religion_id(p_religion) if p_religion != &"" else ReligionCatalog.DEFAULT_RELIGION_ID
	doctrine_id = DoctrineCatalog.validate_doctrine_id(p_doctrine) if p_doctrine != &"" else CultureCatalog.get_default_doctrine(culture_id)
	position_tile = p_pos
	target_tile = p_pos
	role_id = p_role
	energy = MAX_ENERGY
	is_resting = false
	init_starting_skills()
	init_starting_convictions()

func init_starting_convictions() -> void:
	convictions = DoctrineCatalog.get_default_convictions(doctrine_id)

func get_conviction(domain: StringName) -> float:
	var val = convictions.get(domain, 0.5)
	if val is float or val is int:
		return clampf(float(val), 0.0, 1.0)
	return 0.5

func set_conviction(domain: StringName, val: float) -> void:
	convictions[domain] = clampf(val, 0.0, 1.0)

func rejects_food(food_id: StringName) -> bool:
	var diet: String = str(convictions.get(&"dietary_type", "omnivore"))
	if diet == "vegetarian" and food_id == &"meat":
		return true
	if DoctrineCatalog.rejects_food(doctrine_id, food_id):
		return true
	return false

func get_active_belief_conflict(government: GovernmentState = null) -> String:
	# 1. Dietary conflict
	if hunger_counter > 0 and rejects_food(&"meat") and food_state != FoodState.FED:
		return "Rejects meat; available dietary alternatives are insufficient."
	# 2. Conservation conflict
	if role_id == &"woodcutter" and get_conviction(&"nature_conservation") >= 0.7:
		return "Supports conservation; forestry assignment conflicts with personal conviction."
	# 3. Work ethic restlessness
	if role_id == &"unassigned" and workplace_id <= 0 and get_conviction(&"work_ethic") >= 0.8:
		return "Values diligent labor; currently idle and unassigned."
	# 4. Law vs Personal Belief conflicts
	if government != null:
		var for_pol: StringName = government.get_policy(LawCatalog.LAW_FORESTRY)
		if for_pol == &"open_extraction" and get_conviction(&"nature_conservation") >= 0.7:
			return "Disapproves of open extraction; forestry decree conflicts with personal conservation conviction."
		var lab_pol: StringName = government.get_policy(LawCatalog.LAW_LABOUR)
		if lab_pol == &"extended" and get_conviction(&"work_ethic") < 0.4:
			return "Exhausted by extended shifts; labour decree conflicts with personal rest needs."
	return ""

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

func consume_energy(amount: float, is_work: bool = false) -> void:
	var drain_mod: float = SpeciesCatalog.get_energy_drain_modifier(species_id)
	var ethic_discount: float = 1.0
	var actually_working: bool = is_work or (workplace_id > 0 and not is_resting and move_state == MoveState.IDLE)
	if actually_working:
		var ethic: float = get_conviction(&"work_ethic")
		if ethic >= 0.7:
			ethic_discount = 1.0 - (ethic * 0.12)
	energy = clampf(energy - (amount * drain_mod * ethic_discount), MIN_ENERGY, MAX_ENERGY)

func restore_energy(amount: float) -> void:
	var rec_mod: float = SpeciesCatalog.get_energy_recovery_modifier(species_id)
	energy = clampf(energy + (amount * rec_mod), MIN_ENERGY, MAX_ENERGY)

func is_exhausted() -> bool:
	return energy <= EXHAUSTION_THRESHOLD

func is_recovered() -> bool:
	return energy >= RECOVERY_THRESHOLD
