class_name UnitDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: int = 100
@export var speed: float = 40.0 # Pixels per second
@export var damage: int = 15
@export var attack_range: float = 24.0 # Pixels
@export var attack_cooldown: float = 1.0 # Seconds
@export var recruitment_cost: Dictionary = {} # ResourceId -> int
@export var upkeep_bread: int = 1 # Bread upkeep per period
@export var unit_color: Color = Color.BLUE

func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_hp: int = 100,
	p_speed: float = 40.0,
	p_dmg: int = 15,
	p_range: float = 24.0,
	p_cooldown: float = 1.0,
	p_cost: Dictionary = {},
	p_color: Color = Color.BLUE
) -> void:
	id = p_id
	display_name = p_name
	max_health = p_hp
	speed = p_speed
	damage = p_dmg
	attack_range = p_range
	attack_cooldown = p_cooldown
	recruitment_cost = p_cost
	unit_color = p_color

static func get_all_defs() -> Dictionary:
	var defs: Dictionary = {}
	
	# Spearmen: Sturdy melee frontline
	defs[&"spearman"] = UnitDef.new(
		&"spearman", "Spearman",
		120, 38.0, 18, 22.0, 1.2,
		{&"coin": 15}, Color(0.2, 0.45, 0.85) # Royal Blue
	)
	
	# Archers: Fragile ranged damage
	defs[&"archer"] = UnitDef.new(
		&"archer", "Archer",
		70, 44.0, 14, 80.0, 1.0,
		{&"coin": 20}, Color(0.25, 0.75, 0.4) # Archer Green
	)
	
	# Raider: Fast aggressive attackers
	defs[&"raider"] = UnitDef.new(
		&"raider", "Raider",
		90, 42.0, 15, 22.0, 1.1,
		{}, Color(0.85, 0.2, 0.2) # Raider Red
	)
	
	return defs
