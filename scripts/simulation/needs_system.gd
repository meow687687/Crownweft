class_name NeedsSystem
extends RefCounted

const MEAL_INTERVAL_TICKS: int = 24 # Citizen eats once per day/cycle (approx every 6 seconds at 4 ticks/sec)

var total_meals_served: int = 0
var total_shortages: int = 0

func tick_citizens(citizens: Array[CitizenState], food_inventories: Array[Inventory], current_tick: int) -> Dictionary:
	var fed_count: int = 0
	var hungry_count: int = 0
	var at_risk_count: int = 0
	
	for citizen: CitizenState in citizens:
		# Check if it's mealtime for this citizen
		if (current_tick + citizen.id) % MEAL_INTERVAL_TICKS == 0:
			var consumed: bool = _try_consume_food(citizen, food_inventories)
			if consumed:
				citizen.food_state = CitizenState.FoodState.FED
				citizen.hunger_counter = 0
				total_meals_served += 1
			else:
				citizen.hunger_counter += 1
				total_shortages += 1
				if citizen.hunger_counter >= 3:
					citizen.food_state = CitizenState.FoodState.AT_RISK
				else:
					citizen.food_state = CitizenState.FoodState.HUNGRY
					
		# Aggregate current states
		match citizen.food_state:
			CitizenState.FoodState.FED:
				fed_count += 1
			CitizenState.FoodState.HUNGRY:
				hungry_count += 1
			CitizenState.FoodState.AT_RISK:
				at_risk_count += 1
				
	return {
		"fed": fed_count,
		"hungry": hungry_count,
		"at_risk": at_risk_count,
		"total_meals_served": total_meals_served,
		"total_shortages": total_shortages
	}

func _try_consume_food(citizen: CitizenState, food_inventories: Array[Inventory]) -> bool:
	for inv: Inventory in food_inventories:
		if inv.get_available_outgoing(&"bread") >= 1:
			var ok: bool = inv.remove_resource(&"bread", 1, "CONSUMPTION", false)
			if ok:
				return true
	return false
