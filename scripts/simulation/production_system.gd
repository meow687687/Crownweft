class_name ProductionSystem
extends RefCounted

# Block reasons: OK, NO_WORKERS, MISSING_INPUTS, OUTPUT_FULL, DISABLED, NO_RESOURCE.
const HARVEST_RADIUS: int = 5

func tick_building(
    building: BuildingState,
    recipe: RecipeDef,
    world: WorldState = null,
    workers_present: int = -1
) -> void:
	if building == null or recipe == null:
		return
	if not building.enabled:
		building.current_block_reason = &"DISABLED"
		return
	var effective_workers: int = building.assigned_workers if workers_present < 0 else workers_present
	if effective_workers < recipe.required_workers:
		building.current_block_reason = &"NO_WORKERS"
		return

	var starting_cycle: bool = building.production_progress == 0
	var deposit_tile: WorldTile = null
	var harvest_id: StringName = _get_harvest_deposit(building.definition_id)
	if starting_cycle and harvest_id != &"":
		if world == null:
			building.current_block_reason = &"NO_RESOURCE"
			return
		deposit_tile = _find_nearby_deposit(building, world, harvest_id)
		if deposit_tile == null:
			building.current_block_reason = &"NO_RESOURCE"
			return

	if starting_cycle:
		for in_res: StringName in recipe.inputs:
			if building.inventory.get_available_outgoing(in_res) < int(recipe.inputs[in_res]):
				building.current_block_reason = &"MISSING_INPUTS"
				return
		var total_outputs: int = 0
		for out_res: StringName in recipe.outputs:
			if not building.inventory.accepts(out_res):
				building.current_block_reason = &"OUTPUT_FULL"
				return
			total_outputs += int(recipe.outputs[out_res])
		if building.inventory.get_free_capacity() < total_outputs:
			building.current_block_reason = &"OUTPUT_FULL"
			return

		# Reserve output capacity first; this prevents another action from filling the
		# inventory before this production cycle commits.
		var reserved_outputs: Array[StringName] = []
		for out_res: StringName in recipe.outputs:
			if not building.inventory.reserve_in(out_res, int(recipe.outputs[out_res])):
				for rollback_res: StringName in reserved_outputs:
					building.inventory.release_reserved_in(rollback_res, int(recipe.outputs[rollback_res]))
				building.current_block_reason = &"OUTPUT_FULL"
				return
			reserved_outputs.append(out_res)

		for in_res: StringName in recipe.inputs:
			if not building.inventory.remove_resource(in_res, int(recipe.inputs[in_res]), "PRODUCTION_INPUT", false):
				# This should be impossible after pre-validation; release output space.
				for rollback_res: StringName in reserved_outputs:
					building.inventory.release_reserved_in(rollback_res, int(recipe.outputs[rollback_res]))
				building.current_block_reason = &"MISSING_INPUTS"
				return

		if deposit_tile != null:
			# One unit of deposit is consumed per cycle. The output amount is defined by
			# the recipe, so deposit depletion remains independent from resource units.
			deposit_tile.resource_amount = maxi(0, deposit_tile.resource_amount - 1)

	building.current_block_reason = &""
	building.production_progress += 1
	if building.production_progress < recipe.duration_ticks:
		return

	for out_res: StringName in recipe.outputs:
		if not building.inventory.add_resource(out_res, int(recipe.outputs[out_res]), "PRODUCTION_OUTPUT", true):
			# Keep invariant failures visible rather than silently discarding output.
			building.current_block_reason = &"OUTPUT_FULL"
			return
	building.production_progress = 0

func _get_harvest_deposit(building_id: StringName) -> StringName:
	match building_id:
		&"woodcutter":
			return &"trees"
		&"quarry":
			return &"stone_deposit"
		_:
			return &""

func _find_nearby_deposit(building: BuildingState, world: WorldState, deposit_id: StringName) -> WorldTile:
	var best_tile: WorldTile = null
	var best_distance: int = 999999
	for y in range(maxi(0, building.tile_origin.y - HARVEST_RADIUS), mini(world.height, building.tile_origin.y + HARVEST_RADIUS + 1)):
		for x in range(maxi(0, building.tile_origin.x - HARVEST_RADIUS), mini(world.width, building.tile_origin.x + HARVEST_RADIUS + 1)):
			var tile: WorldTile = world.get_tile(Vector2i(x, y))
			if tile == null or tile.resource_deposit_id != deposit_id or tile.resource_amount <= 0:
				continue
			var distance: int = absi(x - building.tile_origin.x) + absi(y - building.tile_origin.y)
			if distance < best_distance:
				best_distance = distance
				best_tile = tile
	return best_tile
