class_name IncidentService
extends RefCounted

signal incident_triggered(incident_id: StringName, incident_data: Dictionary)
signal incident_decision_applied(incident_id: StringName, option_id: StringName, result_dict: Dictionary)
signal incident_resolved(incident_id: StringName, incident_data: Dictionary)

const IncidentCatalog = preload("res://scripts/domain/incident_catalog.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")

var active_incidents: Dictionary = {} # StringName -> Dictionary
var cooldowns: Dictionary = {} # StringName -> int (tick)
var resolution_history: Array[Dictionary] = []

func clear() -> void:
	active_incidents.clear()
	cooldowns.clear()
	resolution_history.clear()

func is_incident_active(id: StringName) -> bool:
	return active_incidents.has(id)

func get_active_incident(id: StringName) -> Dictionary:
	return active_incidents.get(id, {})

func get_all_active_incidents() -> Array:
	return active_incidents.values()

func evaluate_incidents(world, needs_report: Dictionary, current_tick: int) -> Array[StringName]:
	var triggered: Array[StringName] = []
	if world == null:
		return triggered

	# Check resolution of existing active incidents first
	var active_keys: Array = active_incidents.keys().duplicate()
	for inc_id: StringName in active_keys:
		if check_resolution(inc_id, world, needs_report):
			resolve_incident(inc_id, world, current_tick)

	# Only evaluate new triggers periodically to avoid overhead
	if current_tick % 12 != 0:
		return triggered

	for inc_id: StringName in IncidentCatalog.INCIDENT_IDS:
		if not active_incidents.has(inc_id) and can_trigger_incident(inc_id, world, needs_report, current_tick):
			if trigger_incident(inc_id, world, current_tick):
				triggered.append(inc_id)

	return triggered

func can_trigger_incident(id: StringName, world, needs_report: Dictionary, current_tick: int) -> bool:
	if active_incidents.has(id):
		return false
	if current_tick < cooldowns.get(id, 0):
		return false

	match id:
		IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT:
			var hungry: int = needs_report.get("hungry", 0)
			var at_risk: int = needs_report.get("at_risk", 0)
			var total_food: int = _count_stored_food(world)
			var min_food: int = world.citizens.size()
			return (hungry > 0 or at_risk > 0 or total_food < min_food) and current_tick >= 24

		IncidentCatalog.INCIDENT_REALM_GRIEVANCE:
			if world.economy == null:
				return false
			var approval: float = world.economy.approval
			return approval < 45.0 and current_tick >= 36

		IncidentCatalog.INCIDENT_FRONTIER_TROUBLE:
			if world.regional_world == null:
				return false
			var player_armies = _get_player_armies(world)
			if player_armies.is_empty():
				return false
			var army = player_armies[0]
			var low_supplies: bool = army.get_supplies(&"grain") < 25.0
			var has_active_war: bool = world.diplomacy != null and not world.diplomacy.active_wars.is_empty()
			return (low_supplies or has_active_war) and current_tick >= 24

	return false

func trigger_incident(id: StringName, world, current_tick: int, custom_cause: String = "") -> bool:
	if active_incidents.has(id):
		return false

	var def: Dictionary = IncidentCatalog.get_incident_def(id)
	if def.is_empty():
		return false

	var cause_str: String = custom_cause
	if cause_str == "":
		match id:
			IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT:
				var food_amt: int = _count_stored_food(world)
				cause_str = "Settlement food stores critically low (%d food in storage). Immediate hunger threatens citizen welfare." % food_amt
			IncidentCatalog.INCIDENT_REALM_GRIEVANCE:
				cause_str = "Public approval has dropped to %d%% due to royal decrees, high taxation, or unsatisfied needs." % int(roundf(world.economy.approval if world.economy != null else 50.0))
			IncidentCatalog.INCIDENT_FRONTIER_TROUBLE:
				var player_armies = _get_player_armies(world)
				var supplies: float = player_armies[0].get_supplies(&"grain") if not player_armies.is_empty() else 0.0
				cause_str = "Frontier garrison facing severe supply depletion (%.1f supplies remaining) and regional tensions." % supplies

	var inc_data: Dictionary = {
		"id": id,
		"title": def.get("title", str(id)),
		"urgency": def.get("urgency", &"medium"),
		"description": def.get("description", ""),
		"cause": cause_str,
		"triggered_tick": current_tick,
		"chosen_option_id": &"",
		"status": &"pending",
		"options": def.get("options", [])
	}

	active_incidents[id] = inc_data

	# Log chronicle event
	if world.event_log != null:
		var chronicle_msg: String = "CIVIC INCIDENT: %s — %s" % [inc_data["title"], cause_str]
		world.event_log.add_event(&"civic", chronicle_msg, &"warning", current_tick)

	if world.ui != null:
		world.ui.show_toast("Civic Incident: %s!" % inc_data["title"], true)
		world.ui.show_incident_dialog(inc_data, world)

	incident_triggered.emit(id, inc_data)
	return true

func check_option_prerequisites(incident_id: StringName, option_id: StringName, world) -> Dictionary:
	var opt: Dictionary = IncidentCatalog.get_option_def(incident_id, option_id)
	if opt.is_empty():
		return {"ok": false, "reason": "Unknown option"}

	var costs: Dictionary = opt.get("cost", {})
	if not costs.is_empty():
		var town_hall = _find_town_hall(world)
		if town_hall == null or town_hall.inventory == null:
			return {"ok": false, "reason": "No accessible Town Hall storage found."}
		
		for res_id in costs:
			var req: int = int(costs[res_id])
			if res_id == "food":
				var avail_food: int = town_hall.inventory.get_quantity(&"bread") + town_hall.inventory.get_quantity(&"meat")
				if avail_food < req:
					return {"ok": false, "reason": "Insufficient food in Town Hall (%d / %d required)." % [avail_food, req]}
			else:
				var avail: int = town_hall.inventory.get_quantity(StringName(res_id))
				if avail < req:
					return {"ok": false, "reason": "Insufficient %s in Town Hall (%d / %d required)." % [str(res_id).capitalize(), avail, req]}

	return {"ok": true, "reason": ""}

func apply_decision(incident_id: StringName, option_id: StringName, world, current_tick: int) -> Dictionary:
	if not active_incidents.has(incident_id):
		return {"ok": false, "reason": "Incident is not active"}

	var inc_data: Dictionary = active_incidents[incident_id]
	if inc_data.get("chosen_option_id", &"") != &"":
		return {"ok": false, "reason": "Decision already made for this incident"}

	var prereq: Dictionary = check_option_prerequisites(incident_id, option_id, world)
	if not prereq.get("ok", false):
		return prereq

	var opt: Dictionary = IncidentCatalog.get_option_def(incident_id, option_id)
	if opt.is_empty():
		return {"ok": false, "reason": "Invalid option definition"}

	# Deduct costs from Town Hall
	var costs: Dictionary = opt.get("cost", {})
	if not costs.is_empty():
		var town_hall = _find_town_hall(world)
		if town_hall != null and town_hall.inventory != null:
			for res_id in costs:
				var req: int = int(costs[res_id])
				if res_id == "food":
					var bread_amt: int = town_hall.inventory.get_quantity(&"bread")
					var deduct_bread: int = mini(bread_amt, req)
					var deduct_meat: int = req - deduct_bread
					if deduct_bread > 0:
						town_hall.inventory.remove_resource(&"bread", deduct_bread, "CIVIC_INCIDENT")
					if deduct_meat > 0:
						town_hall.inventory.remove_resource(&"meat", deduct_meat, "CIVIC_INCIDENT")
				else:
					town_hall.inventory.remove_resource(StringName(res_id), req, "CIVIC_INCIDENT")

	# Add granted resources (e.g. relief supplies)
	var adds: Dictionary = opt.get("adds_resource", {})
	if not adds.is_empty():
		var town_hall = _find_town_hall(world)
		if town_hall != null and town_hall.inventory != null:
			for res_id in adds:
				town_hall.inventory.add_resource(StringName(res_id), int(adds[res_id]), "CIVIC_INCIDENT_RELIEF")

	# Apply policy change
	var pol_change: Dictionary = opt.get("policy_change", {})
	if not pol_change.is_empty() and world.government != null:
		var law_id: StringName = pol_change.get("law_id", &"")
		var opt_id: StringName = pol_change.get("option_id", &"")
		if law_id != &"" and opt_id != &"":
			world.government.enact_policy(law_id, opt_id, current_tick, "Civic Decision: %s" % opt.get("title", ""))

	# Apply building priorities if action_key == &"prioritize_food"
	if opt.get("action_key", &"") == &"prioritize_food":
		for b: BuildingState in world.buildings:
			if b.status == BuildingState.Status.ACTIVE and b.definition_id in [&"farm", &"bakery"]:
				world.set_building_priority(b, BuildingState.PRIORITY_MAX)

	# Apply approval delta
	var app_delta: float = float(opt.get("approval_delta", 0.0))
	if not is_zero_approx(app_delta) and world.economy != null:
		world.economy.approval = clampf(world.economy.approval + app_delta, 0.0, 100.0)

	# Apply army supplies delta
	var sup_delta: float = float(opt.get("army_supplies_delta", 0.0))
	if not is_zero_approx(sup_delta) and world.regional_world != null:
		var p_armies = _get_player_armies(world)
		if not p_armies.is_empty():
			var army = p_armies[0]
			army.add_supplies(&"grain", int(sup_delta), current_tick)

	# Apply diplomacy delta
	var dip_delta: float = float(opt.get("diplomacy_delta", 0.0))
	if not is_zero_approx(dip_delta) and world.diplomacy != null:
		var rel = world.diplomacy.get_relationship(FactionCatalog.FACTION_PLAYER, FactionCatalog.FACTION_VALEN)
		if rel != null:
			rel.economic_cooperation = clampf(rel.economic_cooperation + dip_delta, 0.0, 100.0)

	inc_data["chosen_option_id"] = option_id
	inc_data["status"] = &"decision_applied"

	# Log chronicle event
	if world.event_log != null:
		var outcome_msg: String = "DECISION ENACTED: %s — Chose '%s'. %s" % [
			inc_data["title"],
			opt.get("title", str(option_id)),
			opt.get("consequence_preview", "")
		]
		world.event_log.add_event(&"civic", outcome_msg, &"info", current_tick)

	if world.ui != null:
		world.ui.show_toast("Decision Enacted: %s" % opt.get("title", ""), false)

	incident_decision_applied.emit(incident_id, option_id, {
		"ok": true,
		"option": opt,
		"incident": inc_data
	})
	return {"ok": true, "option": opt}

func check_resolution(id: StringName, world, needs_report: Dictionary) -> bool:
	if not active_incidents.has(id):
		return false
	var inc_data: Dictionary = active_incidents[id]
	# An incident requires a decision before it can naturally resolve
	if inc_data.get("chosen_option_id", &"") == &"":
		return false

	match id:
		IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT:
			var hungry: int = needs_report.get("hungry", 0)
			var at_risk: int = needs_report.get("at_risk", 0)
			var total_food: int = _count_stored_food(world)
			var target_food: int = world.citizens.size() * 2
			return hungry == 0 and at_risk == 0 and total_food >= target_food

		IncidentCatalog.INCIDENT_REALM_GRIEVANCE:
			if world.economy == null:
				return false
			return world.economy.approval >= 60.0

		IncidentCatalog.INCIDENT_FRONTIER_TROUBLE:
			if world.regional_world == null:
				return false
			var p_armies = _get_player_armies(world)
			if p_armies.is_empty():
				return true
			return p_armies[0].get_supplies(&"grain") >= 30.0

	return false

func resolve_incident(id: StringName, world, current_tick: int) -> void:
	if not active_incidents.has(id):
		return

	var inc_data: Dictionary = active_incidents[id]
	inc_data["status"] = &"resolved"
	inc_data["resolved_tick"] = current_tick
	active_incidents.erase(id)
	resolution_history.append(inc_data)

	# Set recurrence cooldown
	cooldowns[id] = current_tick + IncidentCatalog.DEFAULT_COOLDOWN_TICKS

	# Log resolution event
	if world.event_log != null:
		var resolve_msg: String = "INCIDENT RESOLVED: %s — Settlement conditions have stabilized." % inc_data["title"]
		world.event_log.add_event(&"civic", resolve_msg, &"info", current_tick)

	if world.ui != null:
		world.ui.show_toast("Resolved: %s" % inc_data["title"], false)
		world.ui.close_incident_dialog_if_open(id)

	incident_resolved.emit(id, inc_data)

func _count_stored_food(world) -> int:
	var total: int = 0
	for b: BuildingState in world.buildings:
		if b.status == BuildingState.Status.ACTIVE and b.definition_id in [&"town_hall", &"storehouse"]:
			if b.inventory != null:
				total += b.inventory.get_quantity(&"bread") + b.inventory.get_quantity(&"meat")
	return total

func _find_town_hall(world) -> BuildingState:
	for b: BuildingState in world.buildings:
		if b.status == BuildingState.Status.ACTIVE and b.definition_id == &"town_hall":
			return b
	return null

func _get_player_armies(world) -> Array:
	if world == null or world.regional_world == null:
		return []
	if world.regional_world.has_method("get_armies_for_faction"):
		return world.regional_world.get_armies_for_faction(FactionCatalog.FACTION_PLAYER)
	var res: Array = []
	if world.regional_world.armies is Dictionary:
		for a in world.regional_world.armies.values():
			if a != null and a.is_active() and a.faction_id == FactionCatalog.FACTION_PLAYER:
				res.append(a)
	return res

func serialize() -> Dictionary:
	var active_serialized: Dictionary = {}
	for k in active_incidents:
		active_serialized[str(k)] = active_incidents[k].duplicate(true)

	var cd_serialized: Dictionary = {}
	for k in cooldowns:
		cd_serialized[str(k)] = cooldowns[k]

	return {
		"active_incidents": active_serialized,
		"cooldowns": cd_serialized,
		"history": resolution_history.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	clear()
	var act_dict: Dictionary = data.get("active_incidents", {})
	for k in act_dict:
		active_incidents[StringName(k)] = act_dict[k]

	var cd_dict: Dictionary = data.get("cooldowns", {})
	for k in cd_dict:
		cooldowns[StringName(k)] = int(cd_dict[k])

	var hist_arr: Array = data.get("history", [])
	resolution_history.assign(hist_arr)
