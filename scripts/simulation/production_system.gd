class_name ProductionSystem
extends RefCounted

# Block reasons: OK, NO_WORKERS, MISSING_INPUTS, OUTPUT_FULL, DISABLED, NO_RESOURCE.
const HARVEST_RADIUS: int = 5

static func get_relevant_skill(building_id: StringName) -> StringName:
	match building_id:
		&"farm":
			return &"farming"
		&"woodcutter":
			return &"forestry"
		&"bakery":
			return &"crafting"
		&"quarry":
			return &"masonry"
		_:
			return &""

func tick_building(
	building: BuildingState,
	recipe: RecipeDef,
	world: WorldState = null,
	workers_present: int = -1,
	workers: Array[CitizenState] = []
) -> void:
	if building == null or recipe == null:
		return
	if not building.enabled:
		building.current_block_reason = &"DISABLED"
		return

	var effective_workers: int = building.assigned_workers if workers_present < 0 else workers_present
	if not workers.is_empty():
		effective_workers = workers.size()

	if effective_workers < recipe.required_workers:
		if building.current_block_reason != &"ENTRANCE_UNREACHABLE":
			building.current_block_reason = &"NO_WORKERS"
		return

	# Calculate worker skill factor
	var skill_name: StringName = get_relevant_skill(building.definition_id)
	var skill_factor: float = 1.0
	if not workers.is_empty() and skill_name != &"":
		var total_factor: float = 0.0
		for w: CitizenState in workers:
			total_factor += w.get_skill_factor(skill_name)
		skill_factor = total_factor / float(workers.size())

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

		var bonus_res: int = 0
		if building.definition_id == &"woodcutter" and skill_factor >= 1.15:
			bonus_res = 1

		var total_outputs: int = 0
		for out_res: StringName in recipe.outputs:
			if not building.inventory.accepts(out_res):
				building.current_block_reason = &"OUTPUT_FULL"
				return
			total_outputs += int(recipe.outputs[out_res]) + (bonus_res if out_res == &"timber" else 0)
		if building.inventory.get_free_capacity() < total_outputs:
			building.current_block_reason = &"OUTPUT_FULL"
			return

		# Reserve output capacity first; this prevents another action from filling the
		# inventory before this production cycle commits.
		var reserved_outputs: Dictionary = {}
		for out_res: StringName in recipe.outputs:
			var res_amount: int = int(recipe.outputs[out_res]) + (bonus_res if out_res == &"timber" else 0)
			if not building.inventory.reserve_in(out_res, res_amount):
				for rollback_res: StringName in reserved_outputs:
					building.inventory.release_reserved_in(rollback_res, reserved_outputs[rollback_res])
				building.current_block_reason = &"OUTPUT_FULL"
				return
			reserved_outputs[out_res] = res_amount

		for in_res: StringName in recipe.inputs:
			if not building.inventory.remove_resource(in_res, int(recipe.inputs[in_res]), "PRODUCTION_INPUT", false):
				# This should be impossible after pre-validation; release output space.
				for rollback_res: StringName in reserved_outputs:
					building.inventory.release_reserved_in(rollback_res, reserved_outputs[rollback_res])
				building.current_block_reason = &"MISSING_INPUTS"
				return

		if deposit_tile != null:
			deposit_tile.resource_amount = maxi(0, deposit_tile.resource_amount - 1)

	building.current_block_reason = &""

	# Active work drains energy and yields experience only when actively progressing
	for w: CitizenState in workers:
		w.consume_energy(CitizenState.WORK_ENERGY_DRAIN)
		if skill_name != &"":
			w.gain_experience(skill_name, 0.1)

	# Progress advances modulated by skill factor
	building.production_work_accum += skill_factor
	var steps: int = int(building.production_work_accum)
	building.production_work_accum -= float(steps)
	building.production_progress += steps

	if building.production_progress < recipe.duration_ticks:
		return

	# Determine final outputs with skill bonuses
	for out_res: StringName in recipe.outputs:
		var bonus_out: int = 0
		if building.definition_id == &"woodcutter" and out_res == &"timber":
			if skill_factor >= 1.15:
				bonus_out = 1
			elif skill_factor < 0.85:
				bonus_out = -1
		var final_amount: int = maxi(1, int(recipe.outputs[out_res]) + bonus_out)
		if not building.inventory.add_resource(out_res, final_amount, "PRODUCTION_OUTPUT", true):
			building.current_block_reason = &"OUTPUT_FULL"
			return
	building.production_progress = 0
	building.production_work_accum = 0.0

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
