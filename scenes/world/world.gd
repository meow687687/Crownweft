class_name WorldScene
extends Node2D

const RoadAutotiler = preload("res://scripts/presentation/road_autotiler.gd")

@onready var camera: RTSCamera = $RTSCamera
@onready var renderer: WorldRenderer = $WorldRenderer
@onready var ui: GameUI = $GameUI

var world_state: WorldState = null
var pathfinding: PathfindingService = null
var job_board: JobBoard = null
var logistics: LogisticsSystem = null
var production: ProductionSystem = null
var construction: ConstructionSystem = null
var needs: NeedsSystem = null
var combat: CombatSystem = null
var economy: EconomyState = null
var economy_system: EconomySystem = null

var buildings: Array[BuildingState] = []
var citizens: Array[CitizenState] = []
var military_units: Array[MilitaryUnitState] = []
var selected_units: Array[MilitaryUnitState] = []
var next_entity_id: int = 1

# Simulation timing
var sim_speed_multiplier: float = 1.0 # 0.0 = pause, 1.0 = 1x, 2.0 = 2x, 3.0 = 3x
var sim_tick_timer: float = 0.0
const BASE_TICK_RATE: float = 0.25 # 4 ticks per real second at 1x
var current_tick: int = 0

# Placement / Selection state
var active_build_id: StringName = &""
var selected_building: BuildingState = null

func _ready() -> void:
	_init_simulation()
	_setup_signals()

func _init_simulation() -> void:
	var gen: WorldGenerationService = WorldGenerationService.new()
	world_state = gen.generate_world(2026)
	
	pathfinding = PathfindingService.new(world_state.width, world_state.height)
	pathfinding.initialize_from_world(world_state)
	
	job_board = JobBoard.new()
	logistics = LogisticsSystem.new(job_board)
	production = ProductionSystem.new()
	construction = ConstructionSystem.new()
	construction.building_completed.connect(_on_building_completed)
	needs = NeedsSystem.new()
	combat = CombatSystem.new()
	economy = EconomyState.new()
	economy_system = EconomySystem.new()
	
	combat.raid_announced.connect(func(seconds_left: float):
		ui.show_raid_warning(seconds_left)
	)
	combat.raid_started.connect(func():
		ui.show_raid_warning(0.0)
	)
	
	# Spawn Town Hall at settlement origin
	var th_pos: Vector2i = world_state.start_settlement_pos
	var th_building: BuildingState = place_building(&"town_hall", th_pos, true)
	if th_building != null:
		# Starting supplies
		th_building.inventory.add_resource(&"coin", 50, "START_FUNDS")
		th_building.inventory.add_resource(&"bread", 20, "START_FOOD")
		th_building.inventory.add_resource(&"timber", 25, "START_TIMBER")
		th_building.inventory.add_resource(&"stone", 10, "START_STONE")
		
	# Spawn initial workforce: 10 citizens
	for i in range(10):
		var c_pos: Vector2i = th_pos + Vector2i(i % 3 - 1, i / 3 + 4)
		var citizen: CitizenState = CitizenState.new(next_entity_id, c_pos)
		next_entity_id += 1
		citizens.append(citizen)
		
		# Assign first 2 citizens as dedicated haulers
		if i < 2:
			citizen.role_id = &"hauler"
			logistics.register_hauler(citizen.id, citizen.position_tile)
			
	# Center camera on start settlement
	if camera != null:
		camera.position = Vector2(th_pos.x * 16.0, th_pos.y * 16.0)
	
	# Pass state to renderer
	if renderer != null:
		renderer.world_state = world_state
		renderer.buildings = buildings
		renderer.citizens = citizens
		renderer.military_units = military_units
		renderer.selected_units = selected_units
		renderer.active_jobs = []
		renderer.queue_redraw()

func _setup_signals() -> void:
	if ui == null:
		return
	ui.speed_changed.connect(func(speed: float):
		sim_speed_multiplier = speed
	)
	ui.build_selected.connect(func(b_id: StringName):
		active_build_id = b_id
		renderer.active_build_id = b_id
		renderer.queue_redraw()
	)
	ui.toggle_overlay_requested.connect(func():
		renderer.show_logistics_overlay = not renderer.show_logistics_overlay
		renderer.queue_redraw()
	)
	ui.worker_assignment_changed.connect(_on_worker_assignment_changed)
	ui.recruit_unit_requested.connect(_on_recruit_unit_requested)
	ui.tax_level_cycled.connect(_on_tax_level_cycled)
	ui.save_game_requested.connect(_on_save_game)
	ui.load_game_requested.connect(_on_load_game)

func _process(delta: float) -> void:
	# Update Placement Preview Ghost
	if active_build_id != &"":
		var mouse_world: Vector2 = get_global_mouse_position()
		var tile_coord: Vector2i = Vector2i(int(mouse_world.x / 16.0), int(mouse_world.y / 16.0))
		renderer.hover_tile = tile_coord
		renderer.active_build_id = active_build_id
		var check: Dictionary = can_place_building_at(active_build_id, tile_coord)
		renderer.is_hover_valid = check.get("ok", false)
		renderer.queue_redraw()
	else:
		if renderer.hover_tile != Vector2i(-1, -1):
			renderer.hover_tile = Vector2i(-1, -1)
			renderer.active_build_id = &""
			renderer.queue_redraw()

	if sim_speed_multiplier > 0.0:
		var sim_delta: float = delta * sim_speed_multiplier
		combat.tick_combat(military_units, sim_delta, buildings, pathfinding)
		_cleanup_destroyed_buildings()
		combat.tick_raid_timer(sim_delta, world_state.raider_camp_pos, military_units)
		
		sim_tick_timer += sim_delta
		var tick_interval: float = BASE_TICK_RATE
		while sim_tick_timer >= tick_interval:
			sim_tick_timer -= tick_interval
			_simulation_tick()

func _cleanup_destroyed_buildings() -> void:
	var destroyed: Array[BuildingState] = []
	for building: BuildingState in buildings:
		if building.is_destroyed:
			destroyed.append(building)
	if destroyed.is_empty():
		return
	for building: BuildingState in destroyed:
		# Release assigned citizens immediately; otherwise a destroyed workplace leaves
		# workers permanently counted as employed and production can never recover.
		for citizen: CitizenState in citizens:
			if citizen.workplace_id == building.entity_id:
				citizen.workplace_id = 0
				citizen.role_id = &"unassigned"
				citizen.path.clear()
				citizen.move_state = CitizenState.MoveState.IDLE
				citizen.target_tile = citizen.position_tile
		var inv_id: int = building.inventory.owner_id
		var const_inv_id: int = building.construction_inventory.owner_id if building.construction_inventory != null else -1
		for job: HaulJob in job_board.jobs.values():
			if job.status in [HaulJob.Status.DELIVERED, HaulJob.Status.CANCELLED]:
				continue
			var touches_source: bool = (job.source_inventory_id == inv_id or (const_inv_id > 0 and job.source_inventory_id == const_inv_id))
			var touches_dest: bool = (job.destination_inventory_id == inv_id or (const_inv_id > 0 and job.destination_inventory_id == const_inv_id))
			if not touches_source and not touches_dest:
				continue
			var source_inv: Inventory = _find_inventory_by_id(job.source_inventory_id)
			var dest_inv: Inventory = _find_inventory_by_id(job.destination_inventory_id)
			var carrier = null
			for candidate_hauler in logistics.haulers:
				if candidate_hauler.active_job == job:
					carrier = candidate_hauler
					break
			var has_physical_cargo: bool = carrier != null and carrier.carried_amount > 0
			if has_physical_cargo:
				# Never cancel a job whose goods have left the source. If its destination
				# disappears, release only the destination reservation and keep the cargo.
				if touches_dest:
					if dest_inv != null and job.reserved_amount > 0:
						dest_inv.release_reserved_in(job.resource_id, job.reserved_amount)
					job.destination_inventory_id = -1
					job.reserved_amount = 0
					job.status = HaulJob.Status.BLOCKED
					job.blocked_reason = "DESTINATION_DESTROYED — cargo retained for rerouting"
					carrier.clear_path()
				elif touches_source and job.status == HaulJob.Status.BLOCKED:
					# The source no longer matters after pickup. Keep the job active so the
					# carrier can still complete or reroute its delivery.
					job.blocked_reason = "SOURCE_DESTROYED_AFTER_PICKUP — cargo retained"
				continue
			# Without cargo, cancel safely and release any pre-pickup reservations.
			job_board.cancel_job(job, source_inv, dest_inv, "BUILDING_DESTROYED")
			if carrier != null:
				carrier.active_job = null
				carrier.carried_resource = &""
				carrier.carried_amount = 0
				carrier.clear_path()
		for y in range(BuildingCatalog.get_all_defs().get(building.definition_id, {}).get("footprint", Vector2i(2, 2)).y):
			for x in range(BuildingCatalog.get_all_defs().get(building.definition_id, {}).get("footprint", Vector2i(2, 2)).x):
				var coord: Vector2i = building.tile_origin + Vector2i(x, y)
				var tile: WorldTile = world_state.get_tile(coord)
				if tile == null or tile.building_id != building.entity_id:
					continue
				tile.building_id = 0
				tile._update_flags()
				pathfinding.set_solid(coord, not tile.is_walkable)
		buildings.erase(building)
		if selected_building == building:
			selected_building = null
			ui.show_building_details(null, {})
		if building.definition_id == &"town_hall":
			sim_speed_multiplier = 0.0
			ui.show_toast("Town Hall destroyed. Realm lost.", true)
		else:
			ui.show_toast("%s destroyed" % str(building.definition_id).capitalize(), true)
	renderer.buildings = buildings
	renderer.queue_redraw()

func _find_inventory_by_id(inventory_id: int) -> Inventory:
	for building: BuildingState in buildings:
		if building.inventory.owner_id == inventory_id:
			return building.inventory
		if building.construction_inventory != null and building.construction_inventory.owner_id == inventory_id:
			return building.construction_inventory
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		# Protection: Ignore clicks if mouse is over top HUD or bottom palette
		var mouse_screen: Vector2 = get_viewport().get_mouse_position()
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		if mouse_screen.y < 104.0 or mouse_screen.y > (screen_size.y - 142.0):
			return
		if ui.panel_inspector != null and ui.panel_inspector.visible and mouse_screen.x > (screen_size.x - 320.0):
			return
			
		var mouse_world: Vector2 = get_global_mouse_position()
		var tile_coord: Vector2i = Vector2i(int(mouse_world.x / 16.0), int(mouse_world.y / 16.0))
		
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if active_build_id != &"":
				if active_build_id == &"road":
					build_road(tile_coord)
				else:
					var res = place_building(active_build_id, tile_coord)
					if res == null:
						var check = can_place_building_at(active_build_id, tile_coord)
						ui.show_toast(check.get("reason", "Cannot place here!"), true)
					else:
						var defs = BuildingCatalog.get_all_defs()
						ui.show_toast("Constructed %s" % defs.get(active_build_id, {}).get("display_name", "Building"), false)
			else:
				var clicked_unit: MilitaryUnitState = _find_unit_at(mouse_world)
				if clicked_unit != null and clicked_unit.faction_id == 0:
					selected_units = [clicked_unit]
					renderer.selected_units = selected_units
					selected_building = null
					renderer.selected_building = null
					ui.show_building_details(null, {})
					renderer.queue_redraw()
				else:
					selected_units.clear()
					renderer.selected_units = selected_units
					_select_building_at(tile_coord)
					
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if active_build_id != &"":
				active_build_id = &""
				ui.set_active_build_mode(&"")
				renderer.active_build_id = &""
				renderer.hover_tile = Vector2i(-1, -1)
				renderer.queue_redraw()
				ui.show_toast("Build mode cancelled", false)
				return
				
			if not selected_units.is_empty():
				var target_enemy: MilitaryUnitState = _find_unit_at(mouse_world)
				for u in selected_units:
					if target_enemy != null and target_enemy.faction_id != 0:
						u.set_attack_target_order(target_enemy.id)
					else:
						u.set_move_order(mouse_world)
				renderer.queue_redraw()
			else:
				selected_building = null
				renderer.selected_building = null
				ui.show_building_details(null, {})
				renderer.queue_redraw()

func _find_unit_at(pos: Vector2) -> MilitaryUnitState:
	for u in military_units:
		if not u.is_dead and u.position.distance_to(pos) <= 12.0:
			return u
	return null

func _on_worker_assignment_changed(delta: int) -> void:
	if selected_building == null or delta == 0:
		return
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(selected_building.definition_id, {})
	var max_slots: int = 3 if selected_building.is_under_construction() else int(def_info.get("worker_slots", 0))
	if delta > 0:
		var available: CitizenState = null
		for citizen: CitizenState in citizens:
			if citizen.role_id == &"unassigned" and citizen.workplace_id == 0:
				available = citizen
				break
		if selected_building.assigned_workers >= max_slots:
			ui.show_toast("This building has no open %s slots" % ("builder" if selected_building.is_under_construction() else "worker"), true)
			return
		if available == null:
			ui.show_toast("No unassigned workers available", true)
			return
		selected_building.assigned_workers += 1
		available.workplace_id = selected_building.entity_id
		available.role_id = &"builder" if selected_building.is_under_construction() else _worker_role_for_building(selected_building.definition_id)
		available.path.clear()
		available.move_state = CitizenState.MoveState.MOVING
	else:
		for citizen: CitizenState in citizens:
			if citizen.workplace_id == selected_building.entity_id and citizen.role_id != &"hauler":
				citizen.workplace_id = 0
				citizen.role_id = &"unassigned"
				citizen.path.clear()
				citizen.move_state = CitizenState.MoveState.IDLE
				citizen.target_tile = citizen.position_tile
				selected_building.assigned_workers = maxi(0, selected_building.assigned_workers - 1)
				break
	ui.show_building_details(selected_building, def_info, _count_workers_at_building(selected_building))
	renderer.queue_redraw()

func _worker_role_for_building(building_id: StringName) -> StringName:
	match building_id:
		&"farm": return &"farmer"
		&"woodcutter": return &"woodcutter"
		&"quarry": return &"quarry_worker"
		&"bakery": return &"baker"
		&"storehouse": return &"storekeeper"
		_: return &"worker"

func _select_building_at(tile_coord: Vector2i) -> void:
	selected_building = null
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for b in buildings:
		var footprint: Vector2i = defs.get(b.definition_id, {}).get("footprint", Vector2i(2, 2))
		var rect: Rect2i = Rect2i(b.tile_origin, footprint)
		if rect.has_point(tile_coord):
			selected_building = b
			break
			
	renderer.selected_building = selected_building
	if selected_building != null:
		ui.show_building_details(selected_building, defs.get(selected_building.definition_id, {}))
	else:
		ui.show_building_details(null, {})
	renderer.queue_redraw()

func can_place_building_at(b_id: StringName, coord: Vector2i) -> Dictionary:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	if def_info.is_empty():
		return {"ok": false, "reason": "Unknown building"}
		
	var footprint: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	
	# Bounds and terrain validation
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var c: Vector2i = coord + Vector2i(dx, dy)
			if not world_state.is_valid_coord(c):
				return {"ok": false, "reason": "Location is outside map boundary"}
			var tile: WorldTile = world_state.get_tile(c)
			if tile == null:
				return {"ok": false, "reason": "Invalid tile"}
			if tile.terrain_id == &"water":
				return {"ok": false, "reason": "Cannot build on water"}
			if tile.terrain_id == &"rock":
				return {"ok": false, "reason": "Cannot build on rocky terrain"}
			if not tile.is_buildable:
				return {"ok": false, "reason": "Tile is occupied or blocked"}
				
	# Entrance validation
	var entrance_offset: Vector2i = def_info.get("entrance_offset", Vector2i.ZERO)
	if entrance_offset != Vector2i.ZERO:
		var ent_tile: Vector2i = coord + entrance_offset
		if not world_state.is_valid_coord(ent_tile):
			return {"ok": false, "reason": "Entrance is outside map boundary"}
		var ent_world_tile: WorldTile = world_state.get_tile(ent_tile)
		if ent_world_tile == null:
			return {"ok": false, "reason": "Invalid entrance tile"}
		if ent_world_tile.terrain_id == &"water":
			return {"ok": false, "reason": "Entrance blocked by water"}
		if ent_world_tile.terrain_id == &"rock":
			return {"ok": false, "reason": "Entrance blocked by rocky terrain"}
		if not ent_world_tile.is_walkable:
			return {"ok": false, "reason": "Entrance is occupied or blocked"}

	# A new footprint must not trap a citizen or be built under a military unit.
	for citizen: CitizenState in citizens:
		if Rect2i(coord, footprint).has_point(citizen.position_tile):
			return {"ok": false, "reason": "A citizen is standing here"}
	for unit: MilitaryUnitState in military_units:
		if unit.is_dead:
			continue
		var unit_tile := Vector2i(floori(unit.position.x / 16.0), floori(unit.position.y / 16.0))
		if Rect2i(coord, footprint).has_point(unit_tile):
			return {"ok": false, "reason": "A troop is standing here"}

	# Resource buildings need a real nearby deposit; they do not create infinite resources.
	var required_deposit: StringName = StringName(def_info.get("harvest_deposit", ""))
	if required_deposit != &"":
		var deposit_found := false
		for y in range(maxi(0, coord.y - 5), mini(world_state.height, coord.y + footprint.y + 5)):
			for x in range(maxi(0, coord.x - 5), mini(world_state.width, coord.x + footprint.x + 5)):
				var candidate: WorldTile = world_state.get_tile(Vector2i(x, y))
				if candidate != null and candidate.resource_deposit_id == required_deposit and candidate.resource_amount > 0:
					deposit_found = true
					break
			if deposit_found:
				break
		if not deposit_found:
			return {"ok": false, "reason": "Requires a nearby %s deposit" % ("forest" if required_deposit == &"trees" else "stone" )}

	# Sites can be placed even if materials are pending; haulers will deliver them.
	return {"ok": true, "reason": "Ready to build"}

func build_road(coord: Vector2i) -> bool:
	var tile: WorldTile = world_state.get_tile(coord)
	if tile != null and tile.is_walkable:
		tile.road_level = 1
		pathfinding.set_road(coord, true)
		if renderer != null:
			renderer.refresh_road_cells(RoadAutotiler.get_affected_coords(coord, world_state))
		if ui != null:
			ui.show_toast("Built road section", false)
		return true
	return false

func remove_road(coord: Vector2i) -> bool:
	var tile: WorldTile = world_state.get_tile(coord)
	if tile == null or tile.road_level == 0:
		return false
	tile.road_level = 0
	tile._update_flags()
	pathfinding.set_road(coord, false)
	if renderer != null:
		renderer.refresh_road_cells(RoadAutotiler.get_affected_coords(coord, world_state))
	if ui != null:
		ui.show_toast("Removed road section", false)
	return true

func place_building(b_id: StringName, coord: Vector2i, bypass_cost: bool = false) -> BuildingState:
	var check: Dictionary = can_place_building_at(b_id, coord)
	if not bypass_cost and not check.get("ok", false):
		return null
		
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	var footprint: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	var cost: Dictionary = def_info.get("cost", {}).duplicate()
	var build_time: int = int(def_info.get("build_time", 8))
	
	var b_state: BuildingState = null
	if bypass_cost or cost.is_empty():
		b_state = BuildingState.new(
			next_entity_id,
			b_id,
			def_info.get("capacity", 30),
			def_info.get("accepted", [])
		)
		b_state.status = BuildingState.Status.ACTIVE
		b_state.construction_progress = 1.0
		b_state.construction_ticks = build_time
		b_state.construction_required_ticks = build_time
		next_entity_id += 1
	else:
		var const_inv_id: int = next_entity_id + 1
		b_state = construction.create_construction_site(
			next_entity_id,
			b_id,
			coord,
			cost,
			build_time,
			const_inv_id,
			def_info.get("capacity", 30),
			def_info.get("accepted", [])
		)
		next_entity_id += 2

	b_state.tile_origin = coord
	b_state.assigned_workers = 0 # Workers must come from the finite citizen pool.
	b_state.max_health = int(def_info.get("health", 100))
	b_state.health = b_state.max_health
	
	# Mark tiles solid in world and pathfinder
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var c: Vector2i = coord + Vector2i(dx, dy)
			var tile: WorldTile = world_state.get_tile(c)
			tile.is_buildable = false
			tile.is_walkable = false
			tile.building_id = b_state.entity_id
			pathfinding.set_solid(c, true)
			
	buildings.append(b_state)
	if renderer != null:
		renderer.queue_redraw()
	return b_state

func _on_building_completed(building: BuildingState) -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(building.definition_id, {})
	var max_slots: int = int(def_info.get("worker_slots", 0))
	
	# Transition assigned builders to permanent role up to worker_slots, unassign excess
	var converted: int = 0
	for citizen: CitizenState in citizens:
		if citizen.workplace_id == building.entity_id:
			if converted < max_slots:
				citizen.role_id = _worker_role_for_building(building.definition_id)
				converted += 1
			else:
				citizen.workplace_id = 0
				citizen.role_id = &"unassigned"
				citizen.path.clear()
				citizen.move_state = CitizenState.MoveState.IDLE
				citizen.target_tile = citizen.position_tile
	building.assigned_workers = converted
	
	# Ensure pathfinding and collision flags are reaffirmed
	var footprint: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var c: Vector2i = building.tile_origin + Vector2i(dx, dy)
			var tile: WorldTile = world_state.get_tile(c)
			if tile != null:
				tile.is_buildable = false
				tile.is_walkable = false
				tile.building_id = building.entity_id
				pathfinding.set_solid(c, true)
				
	if selected_building == building and ui != null:
		ui.show_building_details(building, def_info, _count_workers_at_building(building))
	if renderer != null:
		renderer.queue_redraw()
	if ui != null:
		ui.show_toast("%s completed and active!" % def_info.get("display_name", str(building.definition_id)), false)

func cancel_construction_site(building: BuildingState) -> void:
	if building == null or not building.is_under_construction():
		return
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	var fallback_invs: Array[Inventory] = []
	for b: BuildingState in buildings:
		if b != building and b.status == BuildingState.Status.ACTIVE and b.definition_id in [&"storehouse", &"town_hall"]:
			if b.inventory != main_inv and b.inventory != null:
				fallback_invs.append(b.inventory)
				
	var inv_map: Dictionary = {}
	for b: BuildingState in buildings:
		inv_map[b.inventory.owner_id] = b.inventory
		if b.construction_inventory != null:
			inv_map[b.construction_inventory.owner_id] = b.construction_inventory
	
	var refunded: Dictionary = construction.cancel_construction_site(building, job_board, main_inv, inv_map, fallback_invs)
	
	# Release any assigned builders
	for citizen: CitizenState in citizens:
		if citizen.workplace_id == building.entity_id:
			citizen.workplace_id = 0
			citizen.role_id = &"unassigned"
			citizen.path.clear()
			citizen.move_state = CitizenState.MoveState.IDLE
			citizen.target_tile = citizen.position_tile
			
	# Clear world tiles and pathfinding
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var footprint: Vector2i = defs.get(building.definition_id, {}).get("footprint", Vector2i(2, 2))
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var coord: Vector2i = building.tile_origin + Vector2i(dx, dy)
			var tile: WorldTile = world_state.get_tile(coord)
			if tile != null and tile.building_id == building.entity_id:
				tile.building_id = 0
				tile._update_flags()
				pathfinding.set_solid(coord, not tile.is_walkable)
				
	buildings.erase(building)
	
	# If an overflow ground pile was created, register it as a visible ground pile building in the world
	if refunded.has("ground_pile"):
		var pile_inv: Inventory = refunded["ground_pile"]
		var pile_b: BuildingState = BuildingState.new(pile_inv.owner_id, &"ground_pile", pile_inv.capacity, [])
		pile_b.tile_origin = building.tile_origin
		pile_b.inventory = pile_inv
		pile_b.status = BuildingState.Status.ACTIVE
		pile_b.construction_progress = 1.0
		buildings.append(pile_b)
		
		var pile_tile: WorldTile = world_state.get_tile(pile_b.tile_origin)
		if pile_tile != null:
			pile_tile.is_buildable = false
			pile_tile.is_walkable = false
			pile_tile.building_id = pile_b.entity_id
			pathfinding.set_solid(pile_b.tile_origin, true)
	
	if selected_building == building:
		selected_building = null
		if ui != null:
			ui.show_building_details(null, {})
	if renderer != null:
		renderer.buildings = buildings
		renderer.queue_redraw()
	if ui != null:
		ui.show_toast("Construction site cancelled", false)

func _try_deduct_cost(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
		
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	if main_inv == null:
		return false
		
	for res_id in cost:
		var req: int = cost[res_id]
		if main_inv.get_available_outgoing(res_id) < req:
			return false
			
	for res_id in cost:
		var req: int = cost[res_id]
		main_inv.remove_resource(res_id, req, "CONSTRUCTION", false)
	return true

func _on_recruit_unit_requested(unit_def_id: StringName) -> void:
	var defs: Dictionary = UnitDef.get_all_defs()
	var unit_def: UnitDef = defs.get(unit_def_id, null)
	if unit_def == null:
		return
		
	# Find barracks
	var barracks_b: BuildingState = null
	for b in buildings:
		if b.definition_id == &"barracks":
			barracks_b = b
			break
	if barracks_b == null:
		ui.show_toast("Build a Barracks first to recruit troops", true)
		return
		
	# Deduct recruitment cost (Coin) from town hall / main store
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	if main_inv == null:
		return
		
	var coin_cost: int = unit_def.recruitment_cost.get(&"coin", 0)
	if main_inv.get_available_outgoing(&"coin") < coin_cost:
		ui.show_toast("Not enough coin (need %d, have %d)" % [coin_cost, main_inv.get_available_outgoing(&"coin")], true)
		return
		
	main_inv.remove_resource(&"coin", coin_cost, "RECRUITMENT", false)
	
	# Spawn unit just outside barracks
	var spawn_pos: Vector2 = Vector2((barracks_b.tile_origin.x + 3) * 16.0, (barracks_b.tile_origin.y + 1) * 16.0)
	var new_unit: MilitaryUnitState = combat.spawn_player_unit(unit_def_id, spawn_pos)
	military_units.append(new_unit)
	renderer.queue_redraw()
	ui.show_toast("Recruited %s" % unit_def.display_name, false)

func _simulation_tick() -> void:
	current_tick += 1
	var defs: Dictionary = BuildingCatalog.get_all_defs()

	# Build maps once per simulation tick. Inventory IDs and building identities must agree.
	var inv_map: Dictionary = {}
	var building_by_inv: Dictionary = {}
	for building: BuildingState in buildings:
		inv_map[building.inventory.owner_id] = building.inventory
		building_by_inv[building.inventory.owner_id] = building
		if building.construction_inventory != null:
			inv_map[building.construction_inventory.owner_id] = building.construction_inventory
			building_by_inv[building.construction_inventory.owner_id] = building

	# Auto-route unassigned workers to sites that have all materials ready for construction
	for building: BuildingState in buildings:
		if building.is_under_construction() and building.has_all_construction_materials() and building.assigned_workers == 0:
			for citizen: CitizenState in citizens:
				if citizen.role_id == &"unassigned" and citizen.workplace_id == 0:
					citizen.workplace_id = building.entity_id
					citizen.role_id = &"builder"
					citizen.path.clear()
					citizen.move_state = CitizenState.MoveState.MOVING
					building.assigned_workers += 1
					if building.assigned_workers >= 2:
						break

	# Assigned workers must physically reach their worksite before production/construction can advance.
	_update_worker_movement()

	# 1. Production and Construction.
	for building: BuildingState in buildings:
		if building.is_under_construction():
			var workers_present: int = _count_workers_at_building(building)
			construction.tick_building(building, workers_present, current_tick)
		elif building.status == BuildingState.Status.ACTIVE:
			var recipe: RecipeDef = defs.get(building.definition_id, {}).get("recipe", null)
			if recipe != null:
				production.tick_building(building, recipe, world_state, _count_workers_at_building(building))

	# 2. Needs are supplied only by inventories the citizen can physically reach.
	var food_inventories: Array[Inventory] = []
	for building: BuildingState in buildings:
		# Food is consumed from actual household-accessible stores only. Bread sitting
		# in the bakery must be hauled to a storehouse or Town Hall first.
		if building.definition_id in [&"town_hall", &"storehouse"] and building.inventory.get_available_outgoing(&"bread") > 0:
			food_inventories.append(building.inventory)
	var needs_report: Dictionary = needs.tick_citizens(
		citizens, food_inventories, current_tick, building_by_inv, pathfinding
	)

	# Military upkeep must also come from the town's current food stock, not an unlimited pool.
	if current_tick % 24 == 0:
		combat.apply_military_upkeep(military_units, food_inventories)

	# 3. Taxes and public approval.
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	economy_system.tick_economy(
		economy,
		citizens.size(),
		needs_report.get("hungry", 0),
		needs_report.get("at_risk", 0),
		main_inv,
		current_tick
	)

	# 4. Create demands, assign jobs, and physically move haulers along A* paths.
	_generate_logistics_demand()
	logistics.dispatch_jobs()
	logistics.tick_haulers(inv_map, current_tick, pathfinding, building_by_inv)
	_update_citizen_hauling_movement()

	# 5. Keep the route overlay connected to live jobs.
	renderer.active_jobs.clear()
	for job: HaulJob in job_board.jobs.values():
		if job.status != HaulJob.Status.DELIVERED and job.status != HaulJob.Status.CANCELLED:
			renderer.active_jobs.append(job)
	_update_ui_state(needs_report)
	renderer.queue_redraw()

func _update_worker_movement() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var building_worker_slots: Dictionary = {}
	
	# Pre-collect occupied staging tiles of idle workers at their workplace
	var occupied_by_building: Dictionary = {}
	for citizen: CitizenState in citizens:
		if citizen.role_id == &"hauler" or citizen.workplace_id <= 0:
			continue
		if citizen.move_state == CitizenState.MoveState.IDLE:
			var b_id: int = citizen.workplace_id
			if not occupied_by_building.has(b_id):
				occupied_by_building[b_id] = []
			(occupied_by_building[b_id] as Array[Vector2i]).append(citizen.position_tile)

	for citizen: CitizenState in citizens:
		if citizen.role_id == &"hauler":
			continue
		if citizen.workplace_id <= 0:
			citizen.path.clear()
			citizen.move_state = CitizenState.MoveState.IDLE
			citizen.target_tile = citizen.position_tile
			continue

		var workplace: BuildingState = _find_building_by_entity_id(citizen.workplace_id)
		if workplace == null or workplace.is_destroyed:
			citizen.workplace_id = 0
			citizen.role_id = &"unassigned"
			citizen.path.clear()
			citizen.move_state = CitizenState.MoveState.IDLE
			citizen.target_tile = citizen.position_tile
			continue

		var footprint: Vector2i = defs.get(workplace.definition_id, {}).get("footprint", Vector2i.ONE)
		var slot_idx: int = building_worker_slots.get(workplace.entity_id, 0)
		building_worker_slots[workplace.entity_id] = slot_idx + 1

		if citizen.move_state == CitizenState.MoveState.IDLE and _is_adjacent_to_building(citizen.position_tile, workplace, footprint):
			citizen.current_block_reason = &""
			if workplace.current_block_reason == &"ENTRANCE_UNREACHABLE":
				workplace.current_block_reason = &""
			if workplace.construction_block_reason == &"ENTRANCE_UNREACHABLE":
				workplace.construction_block_reason = &""
			continue

		if not citizen.path.is_empty():
			if pathfinding.astar_grid.is_point_solid(citizen.path[0]) or pathfinding.astar_grid.is_point_solid(citizen.target_tile):
				citizen.path.clear()

		if citizen.path.is_empty():
			var occupied: Array[Vector2i] = []
			if occupied_by_building.has(workplace.entity_id):
				occupied.assign(occupied_by_building[workplace.entity_id])
			var route_res: Dictionary = pathfinding.find_path_to_entrance(
				citizen.position_tile, workplace, slot_idx, occupied
			)
			if not route_res.get("ok", false):
				citizen.move_state = CitizenState.MoveState.IDLE
				citizen.target_tile = citizen.position_tile
				var reason: StringName = route_res.get("reason", &"ENTRANCE_UNREACHABLE")
				citizen.current_block_reason = reason
				if workplace.is_under_construction():
					workplace.construction_block_reason = reason
				else:
					workplace.current_block_reason = reason
				continue

			citizen.current_block_reason = &""
			if workplace.current_block_reason == &"ENTRANCE_UNREACHABLE":
				workplace.current_block_reason = &""
			if workplace.construction_block_reason == &"ENTRANCE_UNREACHABLE":
				workplace.construction_block_reason = &""

			var route: Array[Vector2i] = []
			route.assign(route_res.get("path", []))
			citizen.path = route
			citizen.target_tile = route_res.get("target_tile", route[route.size() - 1] if not route.is_empty() else citizen.position_tile)
			if not citizen.path.is_empty():
				citizen.path.remove_at(0) # The first route tile is the citizen's current tile.
			if citizen.path.is_empty():
				citizen.move_state = CitizenState.MoveState.IDLE
				citizen.target_tile = citizen.position_tile
				continue

		if not citizen.path.is_empty():
			citizen.position_tile = citizen.path.pop_front()
			citizen.move_state = CitizenState.MoveState.MOVING if not citizen.path.is_empty() else CitizenState.MoveState.IDLE
			if citizen.path.is_empty():
				citizen.target_tile = citizen.position_tile

func _count_workers_at_building(building: BuildingState) -> int:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var footprint: Vector2i = defs.get(building.definition_id, {}).get("footprint", Vector2i.ONE)
	var count: int = 0
	for citizen: CitizenState in citizens:
		if citizen.workplace_id != building.entity_id or citizen.role_id == &"hauler":
			continue
		if citizen.move_state == CitizenState.MoveState.IDLE and _is_adjacent_to_building(citizen.position_tile, building, footprint):
			count += 1
	return count

func _is_adjacent_to_building(tile_coord: Vector2i, building: BuildingState, footprint: Vector2i) -> bool:
	if building != null and building.entrance_offset != Vector2i.ZERO:
		return building.is_at_entrance_or_staging(tile_coord)
	var left: int = building.tile_origin.x
	var top: int = building.tile_origin.y
	var right: int = left + footprint.x - 1
	var bottom: int = top + footprint.y - 1
	var within_x: bool = tile_coord.x >= left and tile_coord.x <= right
	var within_y: bool = tile_coord.y >= top and tile_coord.y <= bottom
	return (within_x and (tile_coord.y == top - 1 or tile_coord.y == bottom + 1)) or (within_y and (tile_coord.x == left - 1 or tile_coord.x == right + 1))

func _find_building_by_entity_id(entity_id: int) -> BuildingState:
	for building: BuildingState in buildings:
		if building.entity_id == entity_id:
			return building
	return null

func _update_citizen_hauling_movement() -> void:
	for hauler in logistics.haulers:
		var citizen: CitizenState = _find_citizen_by_id(hauler.id)
		if citizen == null:
			continue
		citizen.position_tile = hauler.current_tile
		if hauler.active_job != null:
			citizen.active_job_id = hauler.active_job.id
			citizen.carried_resource = hauler.carried_resource
			citizen.carried_amount = hauler.carried_amount
		else:
			citizen.carried_resource = &""
			citizen.carried_amount = 0
			citizen.active_job_id = 0


func _find_citizen_by_id(id: int) -> CitizenState:
	for c in citizens:
		if c.id == id:
			return c
	return null

func _find_building_by_inv_id(inv_id: int) -> BuildingState:
	for b in buildings:
		if b.inventory.owner_id == inv_id:
			return b
	return null

func _generate_logistics_demand() -> void:
	var town_hall: BuildingState = null
	var farm_b: BuildingState = null
	var bakery_b: BuildingState = null
	var storehouse_b: BuildingState = null
	var woodcutter_b: BuildingState = null
	var quarry_b: BuildingState = null

	for b in buildings:
		match b.definition_id:
			&"town_hall":
				town_hall = b
			&"farm":
				if farm_b == null:
					farm_b = b
			&"bakery":
				if bakery_b == null:
					bakery_b = b
			&"storehouse":
				if storehouse_b == null:
					storehouse_b = b
			&"woodcutter":
				if woodcutter_b == null:
					woodcutter_b = b
			&"quarry":
				if quarry_b == null:
					quarry_b = b

	if farm_b != null and bakery_b != null:
		if bakery_b.inventory.get_quantity(&"grain") + bakery_b.inventory.get_reserved_in(&"grain") < 6:
			logistics.check_and_create_demand(farm_b, bakery_b, &"grain", 4, current_tick, 3)

	var food_destination: BuildingState = storehouse_b if storehouse_b != null else town_hall
	if bakery_b != null and food_destination != null and bakery_b != food_destination:
		if bakery_b.inventory.get_available_outgoing(&"bread") >= 2 and food_destination.inventory.get_quantity(&"bread") < 40:
			logistics.check_and_create_demand(bakery_b, food_destination, &"bread", 4, current_tick, 2)

	# Construction is paid from Town Hall stock. Locally produced materials must be hauled there.
	if town_hall != null and woodcutter_b != null:
		var timber_inbound: int = town_hall.inventory.get_quantity(&"timber") + town_hall.inventory.get_reserved_in(&"timber")
		if timber_inbound < 35:
			logistics.check_and_create_demand(woodcutter_b, town_hall, &"timber", 4, current_tick, 2)
	if town_hall != null and quarry_b != null:
		var stone_inbound: int = town_hall.inventory.get_quantity(&"stone") + town_hall.inventory.get_reserved_in(&"stone")
		if stone_inbound < 20:
			logistics.check_and_create_demand(quarry_b, town_hall, &"stone", 4, current_tick, 2)

	# Construction site supply: haul required materials from town storage into site's construction inventory
	for b: BuildingState in buildings:
		if not b.is_under_construction():
			continue
		var needed_map: Dictionary = b.get_unreserved_materials_needed()
		for res_id: StringName in needed_map:
			var needed_qty: int = needed_map[res_id]
			if needed_qty <= 0:
				continue
			var source_building: BuildingState = null
			if town_hall != null and town_hall.status == BuildingState.Status.ACTIVE and town_hall.inventory.get_available_outgoing(res_id) > 0:
				source_building = town_hall
			elif storehouse_b != null and storehouse_b.status == BuildingState.Status.ACTIVE and storehouse_b.inventory.get_available_outgoing(res_id) > 0:
				source_building = storehouse_b
			if source_building != null:
				var available: int = source_building.inventory.get_available_outgoing(res_id)
				var free_cap: int = b.construction_inventory.get_free_capacity()
				var transfer: int = mini(needed_qty, mini(available, mini(4, free_cap)))
				if transfer > 0:
					job_board.create_job(res_id, transfer, source_building.inventory, b.construction_inventory, 4, current_tick)

func _update_ui_state(needs_report: Dictionary) -> void:
	var total_coin: int = 0
	var total_bread: int = 0
	var total_grain: int = 0
	var total_timber: int = 0
	var total_stone: int = 0
	
	for b in buildings:
		total_coin += b.inventory.get_quantity(&"coin")
		total_bread += b.inventory.get_quantity(&"bread")
		total_grain += b.inventory.get_quantity(&"grain")
		total_timber += b.inventory.get_quantity(&"timber")
		total_stone += b.inventory.get_quantity(&"stone")
		
	ui.update_resources(total_coin, total_bread, total_grain, total_timber, total_stone)
	ui.update_population(citizens.size(), needs_report.get("fed", 0), needs_report.get("hungry", 0), needs_report.get("at_risk", 0))
	if economy != null:
		ui.update_economy(economy.get_tax_level_name(), economy.approval)
	
	if selected_building != null:
		var defs: Dictionary = BuildingCatalog.get_all_defs()
		ui.show_building_details(selected_building, defs.get(selected_building.definition_id, {}), _count_workers_at_building(selected_building))

func _on_tax_level_cycled() -> void:
	if economy == null:
		return
	match economy.tax_level:
		EconomyState.TaxLevel.LOW:
			economy.tax_level = EconomyState.TaxLevel.NORMAL
		EconomyState.TaxLevel.NORMAL:
			economy.tax_level = EconomyState.TaxLevel.HIGH
		EconomyState.TaxLevel.HIGH:
			economy.tax_level = EconomyState.TaxLevel.LOW
	ui.update_economy(economy.get_tax_level_name(), economy.approval)
	ui.show_toast("Tax rate changed to %s" % economy.get_tax_level_name(), false)

func _on_save_game() -> void:
	var success: bool = SaveService.save_game_to_file(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		current_tick,
		sim_speed_multiplier
	)
	if success:
		ui.show_toast("Realm state saved successfully", false)
	else:
		ui.show_toast("Failed to save realm", true)

func _on_load_game() -> void:
	var loaded: Dictionary = SaveService.load_game_from_file()
	if loaded.is_empty():
		ui.show_toast("No valid save found", true)
		return
		
	if loaded.has("world_state") and loaded["world_state"] != null:
		world_state = loaded["world_state"]
		renderer.world_state = world_state
		renderer.invalidate_world_visuals()
	economy = loaded["economy"]
	buildings = loaded["buildings"]
	citizens = loaded["citizens"]
	military_units = loaded["military_units"]
	job_board = loaded["job_board"]
	logistics.job_board = job_board
	logistics.haulers.clear()
	combat.unit_navigation.clear()
	for citizen: CitizenState in citizens:
		if citizen.role_id == &"hauler":
			var restored_hauler = logistics.register_hauler(citizen.id, citizen.position_tile)
			var active_job: HaulJob = null
			for candidate: HaulJob in job_board.jobs.values():
				if candidate.assigned_citizen_id == citizen.id and candidate.status in [HaulJob.Status.ASSIGNED, HaulJob.Status.IN_TRANSIT, HaulJob.Status.BLOCKED]:
					# A blocked job can still own physical cargo after a destination is lost.
					if candidate.status != HaulJob.Status.BLOCKED or citizen.carried_amount > 0:
						active_job = candidate
						break
			if active_job != null:
				restored_hauler.active_job = active_job
				if active_job.status == HaulJob.Status.IN_TRANSIT or citizen.carried_amount > 0:
					restored_hauler.carried_resource = citizen.carried_resource if citizen.carried_resource != &"" else active_job.resource_id
					restored_hauler.carried_amount = citizen.carried_amount if citizen.carried_amount > 0 else active_job.amount

	current_tick = loaded["meta"].get("current_tick", 0)
	sim_speed_multiplier = loaded["meta"].get("sim_speed", 1.0)
	
	pathfinding.initialize_from_world(world_state)
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	next_entity_id = 1
	combat.next_unit_id = 1000
	var max_job_id: int = 0
	for b: BuildingState in buildings:
		next_entity_id = maxi(next_entity_id, b.entity_id + 1)
		for dy in range(defs.get(b.definition_id, {}).get("footprint", Vector2i(2, 2)).y):
			for dx in range(defs.get(b.definition_id, {}).get("footprint", Vector2i(2, 2)).x):
				var c: Vector2i = b.tile_origin + Vector2i(dx, dy)
				pathfinding.set_solid(c, true)
	for c: CitizenState in citizens:
		next_entity_id = maxi(next_entity_id, c.id + 1)
	for u: MilitaryUnitState in military_units:
		combat.next_unit_id = maxi(combat.next_unit_id, u.id + 1)
	for job_id in job_board.jobs.keys():
		max_job_id = maxi(max_job_id, int(job_id))
	job_board._next_job_id = max_job_id + 1
				
	renderer.buildings = buildings
	renderer.citizens = citizens
	renderer.military_units = military_units
	selected_building = null
	selected_units.clear()
	renderer.selected_building = null
	renderer.selected_units = selected_units
	renderer.queue_redraw()
	_update_ui_state({"fed": 0, "hungry": 0, "at_risk": 0})
	ui.update_economy(economy.get_tax_level_name(), economy.approval)
	ui.show_toast("Realm loaded successfully", false)
