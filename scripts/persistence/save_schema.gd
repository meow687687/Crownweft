class_name SaveSchema
extends RefCounted

const SCHEMA_VERSION: int = 2
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
		"world": {
			"width": world_state.width if world_state != null else 0,
			"height": world_state.height if world_state != null else 0,
			"start_settlement_pos": [world_state.start_settlement_pos.x, world_state.start_settlement_pos.y] if world_state != null else [0, 0],
			"raider_camp_pos": [world_state.raider_camp_pos.x, world_state.raider_camp_pos.y] if world_state != null else [0, 0],
			"tiles": []
		},
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"jobs": []
	}

	if world_state != null:
		for tile: WorldTile in world_state.tiles:
			if tile == null:
				data["world"]["tiles"].append(null)
				continue
			data["world"]["tiles"].append({
				"terrain_id": str(tile.terrain_id),
				"fertility": tile.fertility,
				"resource_deposit_id": str(tile.resource_deposit_id),
				"resource_amount": tile.resource_amount,
				"building_id": tile.building_id,
				"road_level": tile.road_level,
				"is_buildable": tile.is_buildable,
				"is_walkable": tile.is_walkable
			})
	
	# Serialize buildings
	for b in buildings:
		var b_dict: Dictionary = {
			"entity_id": b.entity_id,
			"definition_id": str(b.definition_id),
			"tile_origin": [b.tile_origin.x, b.tile_origin.y],
			"assigned_workers": b.assigned_workers,
			"production_progress": b.production_progress,
			"block_reason": str(b.current_block_reason),
			"health": b.health,
			"max_health": b.max_health,
			"is_destroyed": b.is_destroyed,
			"status": int(b.status),
			"construction_progress": b.construction_progress,
			"construction_ticks": b.construction_ticks,
			"construction_required_ticks": b.construction_required_ticks,
			"construction_cost": b.construction_cost.duplicate(),
			"construction_block_reason": str(b.construction_block_reason),
			"construction_inventory": {
				"owner_id": b.construction_inventory.owner_id,
				"capacity": b.construction_inventory.capacity,
				"quantities": b.construction_inventory.quantities.duplicate(),
				"reserved_out": b.construction_inventory.reserved_out.duplicate(),
				"reserved_in": b.construction_inventory.reserved_in.duplicate(),
				"accepted": b.construction_inventory.accepted_resources
			} if b.construction_inventory != null else null,
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
			"home_building_id": c.home_building_id,
			"workplace_id": c.workplace_id,
			"role_id": str(c.role_id),
			"position_tile": [c.position_tile.x, c.position_tile.y],
			"target_tile": [c.target_tile.x, c.target_tile.y],
			"move_state": c.move_state,
			"hunger_counter": c.hunger_counter,
			"food_state": c.food_state,
			"carried_resource": str(c.carried_resource),
			"carried_amount": c.carried_amount,
			"active_job_id": c.active_job_id,
			"current_block_reason": str(c.current_block_reason),
			"energy": c.energy,
			"is_resting": c.is_resting,
			"skills": c.skills.duplicate()
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
		"world_state": null,
		"economy": EconomyState.new(),
		"buildings": [],
		"citizens": [],
		"military_units": [],
		"job_board": JobBoard.new()
	}

	var world_data: Dictionary = data.get("world", {})
	if not world_data.is_empty():
		var world_width: int = int(world_data.get("width", WorldState.DEFAULT_WIDTH))
		var world_height: int = int(world_data.get("height", WorldState.DEFAULT_HEIGHT))
		var saved_seed: int = int(meta.get("seed_val", 0))
		var restored_world := WorldState.new(world_width, world_height, saved_seed)
		restored_world.generator_version = int(meta.get("generator_version", GENERATOR_VERSION))
		var start_arr: Array = world_data.get("start_settlement_pos", [0, 0])
		var camp_arr: Array = world_data.get("raider_camp_pos", [0, 0])
		restored_world.start_settlement_pos = Vector2i(int(start_arr[0]), int(start_arr[1]))
		restored_world.raider_camp_pos = Vector2i(int(camp_arr[0]), int(camp_arr[1]))
		var saved_tiles: Array = world_data.get("tiles", [])
		for index in range(mini(saved_tiles.size(), world_width * world_height)):
			var tile_data = saved_tiles[index]
			if tile_data == null:
				continue
			var coord := Vector2i(index % world_width, int(index / world_width))
			var tile := WorldTile.new(coord, StringName(tile_data.get("terrain_id", "grass")), float(tile_data.get("fertility", 0.5)))
			tile.resource_deposit_id = StringName(tile_data.get("resource_deposit_id", ""))
			tile.resource_amount = int(tile_data.get("resource_amount", 0))
			tile.building_id = int(tile_data.get("building_id", 0))
			tile.road_level = int(tile_data.get("road_level", 0))
			tile.is_buildable = bool(tile_data.get("is_buildable", true))
			tile.is_walkable = bool(tile_data.get("is_walkable", true))
			restored_world.set_tile(coord, tile)
		result["world_state"] = restored_world
	else:
		# Backward compatibility with v1 saves that only recorded a seed.
		var legacy_seed: int = int(meta.get("seed_val", 2026))
		result["world_state"] = WorldGenerationService.new().generate_world(legacy_seed)
	
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
		b.health = int(b_dict.get("health", 100))
		b.max_health = int(b_dict.get("max_health", 100))
		b.is_destroyed = bool(b_dict.get("is_destroyed", false))
		b.status = b_dict.get("status", BuildingState.Status.ACTIVE) as BuildingState.Status
		b.construction_progress = float(b_dict.get("construction_progress", 1.0))
		b.construction_ticks = int(b_dict.get("construction_ticks", 0))
		b.construction_required_ticks = int(b_dict.get("construction_required_ticks", 10))
		b.construction_block_reason = StringName(b_dict.get("construction_block_reason", ""))
		
		var saved_cost: Dictionary = b_dict.get("construction_cost", {})
		for cost_k in saved_cost:
			b.construction_cost[StringName(cost_k)] = int(saved_cost[cost_k])
			
		var c_inv_data = b_dict.get("construction_inventory", null)
		if c_inv_data != null:
			var c_owner_id: int = int(c_inv_data.get("owner_id", b.entity_id + 50000))
			var c_cap: int = int(c_inv_data.get("capacity", 50))
			var c_accepted: Array = c_inv_data.get("accepted", [])
			b.construction_inventory = Inventory.new(c_owner_id, c_cap, c_accepted)
			for res_key in c_inv_data.get("quantities", {}):
				b.construction_inventory.quantities[StringName(res_key)] = int(c_inv_data["quantities"][res_key])
			for res_key in c_inv_data.get("reserved_out", {}):
				b.construction_inventory.reserved_out[StringName(res_key)] = int(c_inv_data["reserved_out"][res_key])
			for res_key in c_inv_data.get("reserved_in", {}):
				b.construction_inventory.reserved_in[StringName(res_key)] = int(c_inv_data["reserved_in"][res_key])
		
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
		c.home_building_id = int(c_dict.get("home_building_id", 0))
		c.workplace_id = int(c_dict.get("workplace_id", 0))
		var target_arr: Array = c_dict.get("target_tile", c_pos_arr)
		c.target_tile = Vector2i(int(target_arr[0]), int(target_arr[1]))
		c.move_state = int(c_dict.get("move_state", CitizenState.MoveState.IDLE))
		c.hunger_counter = c_dict.get("hunger_counter", 0)
		c.food_state = c_dict.get("food_state", CitizenState.FoodState.FED)
		c.carried_resource = StringName(c_dict.get("carried_resource", ""))
		c.carried_amount = c_dict.get("carried_amount", 0)
		c.active_job_id = c_dict.get("active_job_id", 0)
		c.current_block_reason = StringName(c_dict.get("current_block_reason", ""))
		c.energy = clampf(float(c_dict.get("energy", CitizenState.MAX_ENERGY)), CitizenState.MIN_ENERGY, CitizenState.MAX_ENERGY)
		c.is_resting = bool(c_dict.get("is_resting", false))
		var saved_skills: Dictionary = c_dict.get("skills", {})
		if not saved_skills.is_empty():
			for s_name in CitizenState.SKILL_NAMES:
				var str_key: String = str(s_name)
				var val = saved_skills.get(str_key, saved_skills.get(s_name, CitizenState.DEFAULT_SKILL))
				c.set_skill(s_name, float(val))
		else:
			c.init_starting_skills(c.id)
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
