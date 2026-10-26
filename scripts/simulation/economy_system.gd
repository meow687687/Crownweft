class_name EconomySystem
extends RefCounted

func tick_economy(
	economy: EconomyState,
	population_count: int,
	hungry_count: int,
	at_risk_count: int,
	town_inventory: Inventory,
	current_tick: int,
	citizens_list: Array = [],
	government: GovernmentState = null
) -> void:
	if economy == null:
		return

	if government != null:
		var tax_pol: StringName = government.get_policy(LawCatalog.LAW_TAXATION)
		match tax_pol:
			&"low":
				economy.tax_level = EconomyState.TaxLevel.LOW
			&"standard":
				economy.tax_level = EconomyState.TaxLevel.NORMAL
			&"high":
				economy.tax_level = EconomyState.TaxLevel.HIGH
		
	# Check if it's tax collection tick
	if (current_tick - economy.last_tax_tick) >= EconomyState.TAX_INTERVAL_TICKS:
		economy.last_tax_tick = current_tick
		
		# 1. Collect taxes
		var rate: int = economy.get_tax_rate_per_capita()
		var income: int = 0
		var status_approval_bonus: float = 0.0
		var has_admin: bool = false
		
		if not citizens_list.is_empty():
			for c in citizens_list:
				var c_tax: int = SocialClassCatalog.get_tax_per_capita(c.social_status_id, rate)
				income += c_tax
				var is_distressed: bool = (c.food_state != CitizenState.FoodState.FED or c.home_building_id <= 0)
				status_approval_bonus += SocialClassCatalog.get_approval_bonus(c.social_status_id, is_distressed)
				if c.role_id == &"administrator" and c.workplace_id > 0:
					has_admin = true
			if has_admin:
				income = int(roundf(income * 1.15))
		else:
			income = population_count * rate
			
		economy.last_tax_income = income
		
		if town_inventory != null and income > 0:
			town_inventory.add_resource(&"coin", income, "TAX_INCOME", false)
			
		# 2. Adjust approval based on tax rate and food health
		var base_target: float = 60.0
		match economy.tax_level:
			EconomyState.TaxLevel.LOW:
				base_target = 85.0
			EconomyState.TaxLevel.NORMAL:
				base_target = 60.0
			EconomyState.TaxLevel.HIGH:
				base_target = 25.0
				
		# Food shortage penalties
		var penalty: float = float(hungry_count * 5 + at_risk_count * 15)
		var admin_approval_dampening: float = 5.0 if (has_admin and economy.tax_level == EconomyState.TaxLevel.HIGH) else 0.0

		# Law and policy approval modifiers
		var policy_approval_mod: float = 0.0
		if government != null:
			var lab_pol: StringName = government.get_policy(LawCatalog.LAW_LABOUR)
			var base_lab_mod: float = LawCatalog.get_policy_approval_mod(LawCatalog.LAW_LABOUR, lab_pol)
			if lab_pol == &"extended" and has_admin:
				base_lab_mod += 3.0 # Administrator organization dampens extended shift strain
			policy_approval_mod += base_lab_mod

			var for_pol: StringName = government.get_policy(LawCatalog.LAW_FORESTRY)
			if not citizens_list.is_empty():
				var conservationists: int = 0
				for c in citizens_list:
					if c.get_conviction(&"nature_conservation") >= 0.7:
						conservationists += 1
				if for_pol == &"open_extraction":
					policy_approval_mod -= minf(float(conservationists) * 1.5, 6.0)
				elif for_pol == &"protected_forests":
					policy_approval_mod += minf(float(conservationists) * 1.5, 6.0)
			else:
				policy_approval_mod += LawCatalog.get_policy_approval_mod(LawCatalog.LAW_FORESTRY, for_pol)

		var final_target: float = clampf(base_target - penalty + status_approval_bonus + admin_approval_dampening + policy_approval_mod, 0.0, 100.0)
		
		# Smooth approval drift (up to 8 points per tax cycle)
		economy.approval = move_toward(economy.approval, final_target, 8.0)
