class_name ProductionSystem
extends RefCounted

# Block reasons:
# &"OK", &"NO_WORKERS", &"MISSING_INPUTS", &"OUTPUT_FULL", &"DISABLED"

func tick_building(building: BuildingState, recipe: RecipeDef) -> void:
	if building == null or recipe == null:
		return
	
	if not building.enabled:
		building.current_block_reason = &"DISABLED"
		return
	
	if building.assigned_workers < recipe.required_workers:
		building.current_block_reason = &"NO_WORKERS"
		return
	
	# If we are starting a new cycle (progress == 0)
	if building.production_progress == 0:
		# Check inputs availability
		for in_res: StringName in recipe.inputs:
			var req_amount: int = recipe.inputs[in_res]
			if building.inventory.get_available_outgoing(in_res) < req_amount:
				building.current_block_reason = &"MISSING_INPUTS"
				return
		
		# Check output capacity
		var total_outputs: int = 0
		for out_res: StringName in recipe.outputs:
			var out_amount: int = recipe.outputs[out_res]
			if not building.inventory.accepts(out_res):
				building.current_block_reason = &"OUTPUT_FULL"
				return
			total_outputs += out_amount
			
		if building.inventory.get_free_capacity() < total_outputs:
			building.current_block_reason = &"OUTPUT_FULL"
			return
		
		# Consume inputs atomically at cycle start
		for in_res: StringName in recipe.inputs:
			var req_amount: int = recipe.inputs[in_res]
			building.inventory.remove_resource(in_res, req_amount, "PRODUCTION_INPUT", false)
		
		# Reserve space for output goods so inventory doesn't overflow during production
		for out_res: StringName in recipe.outputs:
			var out_amount: int = recipe.outputs[out_res]
			building.inventory.reserve_in(out_res, out_amount)
	
	# Cycle is active and unblocked
	building.current_block_reason = &""
	building.production_progress += 1
	
	# Cycle completion
	if building.production_progress >= recipe.duration_ticks:
		for out_res: StringName in recipe.outputs:
			var out_amount: int = recipe.outputs[out_res]
			building.inventory.add_resource(out_res, out_amount, "PRODUCTION_OUTPUT", true)
		
		building.production_progress = 0
