class_name NeedsSystem
extends RefCounted

const MEAL_INTERVAL_TICKS: int = 24

var total_meals_served: int = 0
var total_shortages: int = 0

# food_buildings_by_inventory maps Inventory.owner_id -> BuildingState. When omitted,
# this retains a lightweight mode for isolated unit tests; the game runtime always passes it.
func tick_citizens(
	citizens: Array[CitizenState],
	food_inventories: Array[Inventory],
	current_tick: int,
	food_buildings_by_inventory: Dictionary = {},
	pathfinding: PathfindingService = null
) -> Dictionary:
	var fed_count: int = 0
	var hungry_count: int = 0
	var at_risk_count: int = 0

	for citizen: CitizenState in citizens:
		if (current_tick + citizen.id) % MEAL_INTERVAL_TICKS == 0:
			var consumed: bool = _try_consume_food(citizen, food_inventories, food_buildings_by_inventory, pathfinding)
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

func _try_consume_food(
	citizen: CitizenState,
	food_inventories: Array[Inventory],
	food_buildings_by_inventory: Dictionary,
	pathfinding: PathfindingService
) -> bool:
	const CANDIDATE_FOODS: Array[StringName] = [&"bread", &"meat"]
	
	for inv: Inventory in food_inventories:
		for food_id: StringName in CANDIDATE_FOODS:
			if inv.get_available_outgoing(food_id) < 1:
				continue

			# Enforce dietary restrictions: do not meet need with rejected food
			if citizen.rejects_food(food_id):
				continue

			# In the live game, only consume from a food store the citizen can reach.
			if pathfinding != null and not food_buildings_by_inventory.is_empty():
				var building: BuildingState = food_buildings_by_inventory.get(inv.owner_id, null)
				if building == null:
					continue
				var footprint: Vector2i = building.get_footprint()
				var path: Array[Vector2i] = pathfinding.find_path_to_adjacent(
					citizen.position_tile, building.tile_origin, footprint
				)
				if path.is_empty():
					continue

			if inv.remove_resource(food_id, 1, "CONSUMPTION", false):
				return true
	return false
