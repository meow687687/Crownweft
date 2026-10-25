class_name EconomySystem
extends RefCounted

func tick_economy(
	economy: EconomyState,
	population_count: int,
	hungry_count: int,
	at_risk_count: int,
	town_inventory: Inventory,
	current_tick: int
) -> void:
	if economy == null:
		return
		
	# Check if it's tax collection tick
	if (current_tick - economy.last_tax_tick) >= EconomyState.TAX_INTERVAL_TICKS:
		economy.last_tax_tick = current_tick
		
		# 1. Collect taxes
		var rate: int = economy.get_tax_rate_per_capita()
		var income: int = population_count * rate
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
		var final_target: float = clampf(base_target - penalty, 0.0, 100.0)
		
		# Smooth approval drift (up to 8 points per tax cycle)
		economy.approval = move_toward(economy.approval, final_target, 8.0)
