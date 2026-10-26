class_name GovernmentState
extends RefCounted

signal policy_enacted(law_id: StringName, old_option: StringName, new_option: StringName)

var enacted_policies: Dictionary = {}
var policy_ticks: Dictionary = {}
var policy_history: Array = []

func _init() -> void:
	for law_id in LawCatalog.LAW_IDS:
		var def_opt: StringName = LawCatalog.get_default_option(law_id)
		enacted_policies[law_id] = def_opt
		policy_ticks[law_id] = 0

func get_policy(law_id: StringName) -> StringName:
	if not LawCatalog.is_valid_law(law_id):
		return &""
	if not enacted_policies.has(law_id):
		enacted_policies[law_id] = LawCatalog.get_default_option(law_id)
	return enacted_policies[law_id]

func enact_policy(law_id: StringName, option_id: StringName, current_tick: int, reason: String = "") -> bool:
	if not LawCatalog.is_valid_law(law_id):
		return false
	if not LawCatalog.is_valid_option(law_id, option_id):
		return false

	var old_option: StringName = get_policy(law_id)
	if old_option == option_id:
		return false # Already enacted

	enacted_policies[law_id] = option_id
	policy_ticks[law_id] = current_tick

	var law_def: Dictionary = LawCatalog.get_law_def(law_id)
	var opt_def: Dictionary = LawCatalog.get_option_def(law_id, option_id)
	var law_name: String = str(law_def.get("display_name", str(law_id)))
	var opt_name: String = str(opt_def.get("display_name", str(option_id)))

	var log_desc: String = "The realm enacted %s (%s) at tick %d." % [opt_name, law_name, current_tick]
	if reason != "":
		log_desc += " Reason: %s." % reason

	policy_history.append({
		"tick": current_tick,
		"law_id": law_id,
		"option_id": option_id,
		"old_option_id": old_option,
		"description": log_desc
	})

	policy_enacted.emit(law_id, old_option, option_id)
	return true

func get_recent_history(max_entries: int = 6) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total: int = policy_history.size()
	var start_idx: int = maxi(0, total - max_entries)
	for i in range(total - 1, start_idx - 1, -1):
		result.append(policy_history[i])
	return result
