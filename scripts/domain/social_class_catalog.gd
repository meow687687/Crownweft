class_name SocialClassCatalog
extends RefCounted

const DEFAULT_STATUS_ID: StringName = &"commoner"

const STATUS_IDS: Array[StringName] = [
	&"commoner",
	&"artisan",
	&"merchant",
	&"scholar",
	&"clergy",
	&"administrator",
	&"noble"
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[&"commoner"] = {
		"id": &"commoner",
		"display_name": "Commoner",
		"description": "The hardworking backbone of the settlement. Commoners handle agriculture, forestry, manual construction, and physical hauling.",
		"privileges": [
			"Unrestricted manual labor and employment in any production role"
		],
		"responsibilities": [
			"Subject to standard settlement poll taxes"
		],
		"tax_modifier_type": "standard",
		"approval_bonus": 0.0,
		"refuses_hauling": false,
		"advancement_cost": 0,
		"advancement_min_skill": 0.0
	}

	_defs[&"artisan"] = {
		"id": &"artisan",
		"display_name": "Artisan",
		"description": "Skilled craftspersons and stonemasons dedicated to refined manufacturing, baking, and construction precision.",
		"privileges": [
			"+10% Craftsmanship bonus to crafting, baking, and masonry performance"
		],
		"responsibilities": [
			"Subject to standard settlement poll taxes"
		],
		"tax_modifier_type": "standard",
		"approval_bonus": 0.0,
		"refuses_hauling": false,
		"advancement_cost": 10,
		"advancement_min_skill": 50.0
	}

	_defs[&"merchant"] = {
		"id": &"merchant",
		"display_name": "Merchant",
		"description": "Traders and warehouse stewards who manage supply distribution, market trade, and capital accumulation.",
		"privileges": [
			"Eligible for storehouse management and commerce oversight"
		],
		"responsibilities": [
			"Subject to commercial wealth levy (+2 coin bonus tax per tax cycle)"
		],
		"tax_modifier_type": "commerce_bonus",
		"approval_bonus": 0.0,
		"refuses_hauling": false,
		"advancement_cost": 15,
		"advancement_min_skill": 40.0
	}

	_defs[&"scholar"] = {
		"id": &"scholar",
		"display_name": "Scholar",
		"description": "Learned intellectuals and scribes who study theory, record-keeping, and experimental techniques.",
		"privileges": [
			"+20% accelerated learning rate when acquiring skill experience"
		],
		"responsibilities": [
			"Subject to standard settlement poll taxes"
		],
		"tax_modifier_type": "standard",
		"approval_bonus": 0.0,
		"refuses_hauling": false,
		"advancement_cost": 15,
		"advancement_min_skill": 45.0
	}

	_defs[&"clergy"] = {
		"id": &"clergy",
		"display_name": "Clergy",
		"description": "Spiritual leaders and caretakers who offer communal solace, ethical guidance, and festival blessings.",
		"privileges": [
			"Exempt from poll taxes (ecclesiastical tithe exemption)",
			"+3.0 settlement approval boost from spiritual stewardship"
		],
		"responsibilities": [
			"Community morale and spiritual guidance"
		],
		"tax_modifier_type": "exempt",
		"approval_bonus": 3.0,
		"refuses_hauling": false,
		"advancement_cost": 20,
		"advancement_min_skill": 30.0
	}

	_defs[&"administrator"] = {
		"id": &"administrator",
		"display_name": "Administrator",
		"description": "Civic magistrates and officers of the crown who oversee governance, fiscal auditing, and Town Hall operations.",
		"privileges": [
			"Exclusively eligible for Town Hall administrative staffing",
			"Increases tax collection yield by +15% and dampens civic unrest when stationed at Town Hall"
		],
		"responsibilities": [
			"Civic oversight, fiscal accounting, and ordinance enforcement"
		],
		"tax_modifier_type": "standard",
		"approval_bonus": 1.0,
		"refuses_hauling": false,
		"advancement_cost": 25,
		"advancement_min_skill": 50.0
	}

	_defs[&"noble"] = {
		"id": &"noble",
		"display_name": "Noble",
		"description": "Patricians and landed gentry of high lineage who invest capital and provide civic prestige, but demand dignified treatment.",
		"privileges": [
			"Full poll tax exemption by noble birthright",
			"+2.0 settlement prestige approval when fed and housed"
		],
		"responsibilities": [
			"Refuses manual resource hauling (considers raw cargo labor beneath noble dignity)",
			"Causes severe unrest (-5.0 approval) if left homeless or starving"
		],
		"tax_modifier_type": "exempt",
		"approval_bonus": 2.0,
		"refuses_hauling": true,
		"advancement_cost": 50,
		"advancement_min_skill": 0.0
	}

static func get_def(id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(id, defs[DEFAULT_STATUS_ID])

static func is_valid_status(id: StringName) -> bool:
	return STATUS_IDS.has(id)

static func validate_status_id(id: StringName) -> StringName:
	return id if is_valid_status(id) else DEFAULT_STATUS_ID

static func get_display_name(id: StringName) -> String:
	var d: Dictionary = get_def(id)
	return d.get("display_name", "Commoner")

static func get_tax_per_capita(id: StringName, base_rate: int) -> int:
	match id:
		&"noble", &"clergy":
			return 0
		&"merchant":
			return base_rate + 2
		_:
			return base_rate

static func get_approval_bonus(id: StringName, is_distressed: bool = false) -> float:
	match id:
		&"clergy":
			return 3.0
		&"noble":
			return -5.0 if is_distressed else 2.0
		&"administrator":
			return 1.0
		_:
			return 0.0

static func get_crafting_modifier(id: StringName, skill_name: StringName) -> float:
	if id == &"artisan" and (skill_name == &"crafting" or skill_name == &"masonry"):
		return 0.10
	return 0.0

static func get_learning_modifier(id: StringName) -> float:
	if id == &"scholar":
		return 1.20
	return 1.0

static func refuses_manual_hauling(id: StringName) -> bool:
	return id == &"noble"

static func get_advancement_cost(id: StringName) -> int:
	var d: Dictionary = get_def(id)
	return int(d.get("advancement_cost", 0))

static func get_advancement_min_skill(id: StringName) -> float:
	var d: Dictionary = get_def(id)
	return float(d.get("advancement_min_skill", 0.0))
