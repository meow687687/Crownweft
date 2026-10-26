class_name SocialClassService
extends RefCounted

static func can_promote_citizen(
	citizen: CitizenState,
	target_status: StringName,
	town_inventory: Inventory = null
) -> Dictionary:
	if citizen == null:
		return {"ok": false, "reason": "CITIZEN_NULL"}
	
	if not SocialClassCatalog.is_valid_status(target_status):
		return {"ok": false, "reason": "INVALID_STATUS_ID"}
		
	if citizen.social_status_id == target_status:
		return {"ok": false, "reason": "ALREADY_HAS_STATUS"}
		
	var min_skill: float = SocialClassCatalog.get_advancement_min_skill(target_status)
	if min_skill > 0.0:
		var has_required_skill: bool = false
		match target_status:
			&"artisan":
				has_required_skill = (citizen.get_skill(&"crafting") >= min_skill or citizen.get_skill(&"masonry") >= min_skill)
			&"merchant":
				has_required_skill = (citizen.get_skill(&"hauling") >= min_skill or citizen.get_skill(&"crafting") >= min_skill)
			&"scholar":
				for s in CitizenState.SKILL_NAMES:
					if citizen.get_skill(s) >= min_skill:
						has_required_skill = true
						break
			&"administrator":
				for s in CitizenState.SKILL_NAMES:
					if citizen.get_skill(s) >= min_skill:
						has_required_skill = true
						break
			_:
				has_required_skill = true
				
		if not has_required_skill:
			return {
				"ok": false,
				"reason": "INSUFFICIENT_SKILL",
				"required_skill": min_skill
			}
			
	var cost: int = SocialClassCatalog.get_advancement_cost(target_status)
	if cost > 0 and town_inventory != null:
		if town_inventory.get_quantity(&"coin") < cost:
			return {
				"ok": false,
				"reason": "INSUFFICIENT_FUNDS",
				"cost": cost,
				"available": town_inventory.get_quantity(&"coin")
			}
			
	return {"ok": true, "reason": "ELIGIBLE"}

static func promote_citizen(
	citizen: CitizenState,
	target_status: StringName,
	reason: String,
	town_inventory: Inventory = null,
	current_tick: int = 0
) -> bool:
	var check: Dictionary = can_promote_citizen(citizen, target_status, town_inventory)
	if not check.get("ok", false):
		return false
		
	var cost: int = SocialClassCatalog.get_advancement_cost(target_status)
	if cost > 0 and town_inventory != null:
		var rem_ok: bool = town_inventory.remove_resource(&"coin", cost, "STATUS_PROMOTION")
		if not rem_ok:
			return false
			
	citizen.social_status_id = target_status
	citizen.last_status_transition_reason = reason
	
	# If newly promoted status refuses manual hauling (Nobles), step down from hauling role
	if SocialClassCatalog.refuses_manual_hauling(target_status) and citizen.role_id == &"hauler":
		citizen.role_id = &"unassigned"
		citizen.carried_resource = &""
		citizen.carried_amount = 0
		citizen.active_job_id = 0
		citizen.path.clear()
		citizen.move_state = CitizenState.MoveState.IDLE
		
	return true

static func check_automatic_advancement(citizen: CitizenState, current_tick: int = 0) -> bool:
	if citizen == null:
		return false
		
	if citizen.social_status_id == &"commoner":
		# Exemplary craftsmanship advancement
		if citizen.get_skill(&"crafting") >= 60.0 or citizen.get_skill(&"masonry") >= 60.0:
			citizen.social_status_id = &"artisan"
			citizen.last_status_transition_reason = "EXEMPLARY_CRAFTSMANSHIP"
			return true
			
		# Commercial acumen advancement
		if citizen.get_skill(&"hauling") >= 60.0 and citizen.role_id == &"storekeeper":
			citizen.social_status_id = &"merchant"
			citizen.last_status_transition_reason = "COMMERCE_ACUMEN"
			return true
			
	return false
