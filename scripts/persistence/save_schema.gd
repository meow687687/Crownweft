class_name SaveSchema
extends RefCounted

const SCHEMA_VERSION: int = 1
const GENERATOR_VERSION: int = 1

static func serialize(
	world_state: WorldState,
	economy: EconomyState,
	buildings: Array[BuildingState],
	citizens: Array[CitizenState],
	military_units: Array[MilitaryUnitState],
	job_board: JobBoard,
	current_tick: int,
	sim_speed: float
) -> Dictionary:
	var data: Dictionary = {
		"meta": {
			"schema_version": SCHEMA_VERSION,
			"generator_version": GENERATOR_VERSION,
			"seed_val": world_state.seed_val if world_state != null else 0,
			"current_tick": current_tick,
			"sim_speed": sim_speed
		},
		"economy": {
			"tax_level": economy.tax_level if economy != null else 1,
			"approval": economy.approval if economy != null else 60.0,
			"last_tax_income": economy.last_tax_income if economy != null else 0,
			"last_tax_tick": economy.last_tax_tick if economy != null else 0
		},
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"jobs": []
	}
	
	# Serialize buildings
	for b in buildings:
		var b_dict: Dictionary = {
			"entity_id": b.entity_id,
			"definition_id": str(b.definition_id),
			"tile_origin": [b.tile_origin.x, b.tile_origin.y],
			"assigned_workers": b.assigned_workers,
			"production_progress": b.production_progress,
			"block_reason": str(b.current_block_reason),
			"inventory": {
				"capacity": b.inventory.capacity,
				"quantities": b.inventory.quantities.duplicate(),
				"reserved_out": b.inventory.reserved_out.duplicate(),
				"reserved_in": b.inventory.reserved_in.duplicate(),
				"accepted": b.inventory.accepted_resources
			}
		}
		data["buildings"].append(b_dict)
		
	# Serialize citizens
	for c in citizens:
		var c_dict: Dictionary = {
			"id": c.id,
			"role_id": str(c.role_id),
			"position_tile": [c.position_tile.x, c.position_tile.y],
			"hunger_counter": c.hunger_counter,
			"food_state": c.food_state,
			"carried_resource": str(c.carried_resource),
			"carried_amount": c.carried_amount,
			"active_job_id": c.active_job_id
		}
		data["citizens"].append(c_dict)
		
	# Serialize military units
	for u in military_units:
		if not u.is_dead:
			var u_dict: Dictionary = {
				"id": u.id,
				"unit_def_id": str(u.unit_definition_id),
				"faction_id": u.faction_id,
				"position": [u.position.x, u.position.y],
				"health": u.health,
				"max_health": u.max_health,
				"order_type": u.order_type,
				"target_pos": [u.target_pos.x, u.target_pos.y],
				"target_unit_id": u.target_unit_id,
				"is_starving": u.is_starving
			}
			data["military_units"].append(u_dict)
			
	# Serialize haul jobs
	if job_board != null:
		for job in job_board.jobs.values():
			if job.status != HaulJob.Status.DELIVERED and job.status != HaulJob.Status.CANCELLED:
				var j_dict: Dictionary = {
					"id": job.id,
					"resource_id": str(job.resource_id),
					"amount": job.amount,
					"source_id": job.source_inventory_id,
					"dest_id": job.destination_inventory_id,
					"priority": job.priority,
					"status": job.status,
					"assigned_citizen_id": job.assigned_citizen_id,
					"reserved_amount": job.reserved_amount,
					"created_tick": job.created_tick
				}
				data["jobs"].append(j_dict)
				
	return data

static func deserialize(data: Dictionary) -> Dictionary:
	var meta: Dictionary = data.get("meta", {})
	var schema_ver: int = meta.get("schema_version", 1)
	if schema_ver > SCHEMA_VERSION:
		printerr("Incompatible save schema version: ", schema_ver)
		return {}
		
	var result: Dictionary = {
		"meta": meta,
		"economy": EconomyState.new(),
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"job_board": JobBoard.new()
	}
	
	# Deserialize economy
	var eco_data: Dictionary = data.get("economy", {})
	result["economy"].tax_level = eco_data.get("tax_level", 1)
	result["economy"].approval = eco_data.get("approval", 60.0)
	result["economy"].last_tax_income = eco_data.get("last_tax_income", 0)
	result["economy"].last_tax_tick = eco_data.get("last_tax_tick", 0)
	
	# Deserialize buildings
	var buildings_arr: Array[BuildingState] = []
	for b_dict in data.get("buildings", []):
		var b: BuildingState = BuildingState.new(
			b_dict["entity_id"],
			StringName(b_dict["definition_id"]),
			b_dict["inventory"]["capacity"],
			b_dict["inventory"].get("accepted", [])
		)
		var origin_arr: Array = b_dict["tile_origin"]
		b.tile_origin = Vector2i(origin_arr[0], origin_arr[1])
		b.assigned_workers = b_dict.get("assigned_workers", 0)
		b.production_progress = b_dict.get("production_progress", 0)
		b.current_block_reason = StringName(b_dict.get("block_reason", ""))
		
		# Restore inventory quantities & reservations
		var inv_data: Dictionary = b_dict["inventory"]
		for res_key in inv_data.get("quantities", {}):
			b.inventory.quantities[StringName(res_key)] = int(inv_data["quantities"][res_key])
		for res_key in inv_data.get("reserved_out", {}):
			b.inventory.reserved_out[StringName(res_key)] = int(inv_data["reserved_out"][res_key])
		for res_key in inv_data.get("reserved_in", {}):
			b.inventory.reserved_in[StringName(res_key)] = int(inv_data["reserved_in"][res_key])
			
		buildings_arr.append(b)
	result["buildings"] = buildings_arr
	
	# Deserialize citizens
	var citizens_arr: Array[CitizenState] = []
	for c_dict in data.get("citizens", []):
		var c_pos_arr: Array = c_dict["position_tile"]
		var c: CitizenState = CitizenState.new(
			c_dict["id"],
			Vector2i(c_pos_arr[0], c_pos_arr[1]),
			StringName(c_dict["role_id"])
		)
		c.hunger_counter = c_dict.get("hunger_counter", 0)
		c.food_state = c_dict.get("food_state", CitizenState.FoodState.FED)
		c.carried_resource = StringName(c_dict.get("carried_resource", ""))
		c.carried_amount = c_dict.get("carried_amount", 0)
		c.active_job_id = c_dict.get("active_job_id", 0)
		citizens_arr.append(c)
	result["citizens"] = citizens_arr
	
	# Deserialize military units
	var units_arr: Array[MilitaryUnitState] = []
	for u_dict in data.get("military_units", []):
		var u_pos_arr: Array = u_dict["position"]
		var u: MilitaryUnitState = MilitaryUnitState.new(
			u_dict["id"],
			StringName(u_dict["unit_def_id"]),
			u_dict["faction_id"],
			Vector2(u_pos_arr[0], u_pos_arr[1])
		)
		u.health = u_dict.get("health", 100)
		u.max_health = u_dict.get("max_health", 100)
		u.order_type = u_dict.get("order_type", MilitaryUnitState.OrderType.HOLD)
		var t_pos_arr: Array = u_dict.get("target_pos", [0.0, 0.0])
		u.target_pos = Vector2(t_pos_arr[0], t_pos_arr[1])
		u.target_unit_id = u_dict.get("target_unit_id", -1)
		u.is_starving = u_dict.get("is_starving", false)
		units_arr.append(u)
	result["military_units"] = units_arr
	
	# Deserialize jobs
	var board: JobBoard = result["job_board"]
	for j_dict in data.get("jobs", []):
		var job: HaulJob = HaulJob.new(
			j_dict["id"],
			StringName(j_dict["resource_id"]),
			j_dict["amount"],
			j_dict["source_id"],
			j_dict["dest_id"],
			j_dict["priority"],
			j_dict["created_tick"]
		)
		job.status = j_dict["status"]
		job.assigned_citizen_id = j_dict.get("assigned_citizen_id", -1)
		job.reserved_amount = j_dict.get("reserved_amount", 0)
		board.jobs[job.id] = job
		
	return result
