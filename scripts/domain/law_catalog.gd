class_name LawCatalog
extends RefCounted

const LAW_TAXATION: StringName = &"taxation"
const LAW_LABOUR: StringName = &"labour"
const LAW_FORESTRY: StringName = &"forestry"

const LAW_IDS: Array[StringName] = [
	LAW_TAXATION,
	LAW_LABOUR,
	LAW_FORESTRY
]

static var _defs: Dictionary = {}

static func get_all_defs() -> Dictionary:
	if _defs.is_empty():
		_init_defs()
	return _defs

static func _init_defs() -> void:
	_defs[LAW_TAXATION] = {
		"id": LAW_TAXATION,
		"display_name": "Taxation Decree",
		"description": "Establishes the settlement's fiscal levy on taxable residents and commercial transactions.",
		"default_option_id": &"standard",
		"options": {
			&"low": {
				"id": &"low",
				"display_name": "Low Taxes",
				"description": "Minimal per-capita levy of 1 coin. Encourages migration, civic goodwill, and high approval.",
				"trade_offs": "Rate: 1 coin/capita. Baseline approval target: 85%. Treasury growth is slow.",
				"rate": 1,
				"approval_target": 85.0
			},
			&"standard": {
				"id": &"standard",
				"display_name": "Standard Taxes",
				"description": "Balanced levy of 2 coins per taxable resident, sustaining civic coffers under moderate scrutiny.",
				"trade_offs": "Rate: 2 coins/capita. Baseline approval target: 60%. Sustainable general treasury income.",
				"rate": 2,
				"approval_target": 60.0
			},
			&"high": {
				"id": &"high",
				"display_name": "High Taxes",
				"description": "Heavy fiscal exaction of 4 coins per capita. Fills coffers rapidly at severe cost to public satisfaction.",
				"trade_offs": "Rate: 4 coins/capita. Baseline approval target: 25%. Triggers unrest without an active Administrator.",
				"rate": 4,
				"approval_target": 25.0
			}
		}
	}

	_defs[LAW_LABOUR] = {
		"id": LAW_LABOUR,
		"display_name": "Labour Regulation",
		"description": "Regulates working shifts, daily pace, and physical exertion across workshops and construction sites.",
		"default_option_id": &"standard",
		"options": {
			&"relaxed": {
				"id": &"relaxed",
				"display_name": "Relaxed Shifts",
				"description": "Shorter work hours and reduced physical strain. Workers fatigue slower and rest less often.",
				"trade_offs": "Speed: 0.80x work rate. Energy drain: 0.75x. Approval bonus: +5.0 points.",
				"speed_mod": 0.80,
				"drain_mod": 0.75,
				"approval_mod": 5.0
			},
			&"standard": {
				"id": &"standard",
				"display_name": "Standard Shifts",
				"description": "Standard working day balancing steady production milestones with normal restorative home rest.",
				"trade_offs": "Speed: 1.00x work rate. Energy drain: 1.00x. Approval modifier: 0 points.",
				"speed_mod": 1.00,
				"drain_mod": 1.00,
				"approval_mod": 0.0
			},
			&"extended": {
				"id": &"extended",
				"display_name": "Extended Shifts",
				"description": "Mandatory overtime and intensified shift pacing to accelerate output and construction completion.",
				"trade_offs": "Speed: 1.20x work rate. Energy drain: 1.35x. Approval penalty: -8.0 points (damped by Administrator).",
				"speed_mod": 1.20,
				"drain_mod": 1.35,
				"approval_mod": -8.0
			}
		}
	}

	_defs[LAW_FORESTRY] = {
		"id": LAW_FORESTRY,
		"display_name": "Forestry Regulation",
		"description": "Directs natural woodland stewardship, timber felling permits, and conservation boundaries.",
		"default_option_id": &"managed",
		"options": {
			&"open_extraction": {
				"id": &"open_extraction",
				"display_name": "Open Extraction",
				"description": "Unchecked clear-cutting permitted across all accessible timber stands. Yields additional timber in dense groves.",
				"trade_offs": "Harvesting: fully permitted (+1 bonus timber when stands >= 2). Sparks conflict with conservationists.",
				"harvest_allowed": true,
				"bonus_timber": 1,
				"approval_mod": -5.0
			},
			&"managed": {
				"id": &"managed",
				"display_name": "Managed Forestry",
				"description": "Balanced sustainable forestry permits selective felling while conserving immature canopy groves.",
				"trade_offs": "Harvesting: standard selective felling. Output: standard. Conservationists accept practices.",
				"harvest_allowed": true,
				"bonus_timber": 0,
				"approval_mod": 0.0
			},
			&"protected_forests": {
				"id": &"protected_forests",
				"display_name": "Protected Forests",
				"description": "Crown decree declaring natural woodlands protected sanctuaries. Felling living trees is strictly unlawful.",
				"trade_offs": "Harvesting: PROHIBITED (woodcutters blocked by law). Conservationists rejoice (+6.0 approval bonus).",
				"harvest_allowed": false,
				"bonus_timber": 0,
				"approval_mod": 6.0
			}
		}
	}

static func get_law_def(law_id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(law_id, {})

static func get_option_def(law_id: StringName, option_id: StringName) -> Dictionary:
	var law_def: Dictionary = get_law_def(law_id)
	var options: Dictionary = law_def.get("options", {})
	return options.get(option_id, {})

static func is_valid_law(law_id: StringName) -> bool:
	return LAW_IDS.has(law_id)

static func is_valid_option(law_id: StringName, option_id: StringName) -> bool:
	var law_def: Dictionary = get_law_def(law_id)
	var options: Dictionary = law_def.get("options", {})
	return options.has(option_id)

static func get_default_option(law_id: StringName) -> StringName:
	var law_def: Dictionary = get_law_def(law_id)
	return law_def.get("default_option_id", &"standard")

static func get_labour_speed_mod(option_id: StringName) -> float:
	var opt_def: Dictionary = get_option_def(LAW_LABOUR, option_id)
	return float(opt_def.get("speed_mod", 1.0))

static func get_labour_drain_mod(option_id: StringName) -> float:
	var opt_def: Dictionary = get_option_def(LAW_LABOUR, option_id)
	return float(opt_def.get("drain_mod", 1.0))

static func is_forestry_harvest_allowed(option_id: StringName) -> bool:
	var opt_def: Dictionary = get_option_def(LAW_FORESTRY, option_id)
	return bool(opt_def.get("harvest_allowed", true))

static func get_forestry_bonus_timber(option_id: StringName) -> int:
	var opt_def: Dictionary = get_option_def(LAW_FORESTRY, option_id)
	return int(opt_def.get("bonus_timber", 0))

static func get_policy_approval_mod(law_id: StringName, option_id: StringName) -> float:
	var opt_def: Dictionary = get_option_def(law_id, option_id)
	return float(opt_def.get("approval_mod", 0.0))
