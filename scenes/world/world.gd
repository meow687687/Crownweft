class_name WorldScene
extends Node2D

@onready var camera: RTSCamera = $RTSCamera
@onready var renderer: WorldRenderer = $WorldRenderer
@onready var ui: GameUI = $GameUI

var world_state: WorldState = null
var pathfinding: PathfindingService = null
var job_board: JobBoard = null
var logistics: LogisticsSystem = null
var production: ProductionSystem = null
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
	camera.position = Vector2(th_pos.x * 16.0, th_pos.y * 16.0)
	
	# Pass state to renderer
	renderer.world_state = world_state
	renderer.buildings = buildings
	renderer.citizens = citizens
	renderer.military_units = military_units
	renderer.selected_units = selected_units
	renderer.active_jobs = []
	renderer.queue_redraw()

func _setup_signals() -> void:
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
	ui.worker_assignment_changed.connect(func(delta: int):
		if selected_building != null:
			var defs: Dictionary = BuildingCatalog.get_all_defs()
			var max_slots: int = defs.get(selected_building.definition_id, {}).get("worker_slots", 0)
			selected_building.assigned_workers = clampi(selected_building.assigned_workers + delta, 0, max_slots)
			ui.show_building_details(selected_building, defs.get(selected_building.definition_id, {}))
	)
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
		combat.tick_combat(military_units, sim_delta)
		combat.tick_raid_timer(sim_delta, world_state.raider_camp_pos, military_units)
		
		sim_tick_timer += sim_delta
		var tick_interval: float = BASE_TICK_RATE
		while sim_tick_timer >= tick_interval:
			sim_tick_timer -= tick_interval
			_simulation_tick()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		# Protection: Ignore clicks if mouse is over top HUD or bottom palette
		var mouse_screen: Vector2 = get_viewport().get_mouse_position()
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		if mouse_screen.y < 50.0 or mouse_screen.y > (screen_size.y - 65.0):
			return
		if ui.panel_inspector != null and ui.panel_inspector.visible and mouse_screen.x > (screen_size.x - 290.0):
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
				
	# Cost check against Town Hall
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	if main_inv != null:
		var cost: Dictionary = def_info.get("cost", {})
		for res_id in cost:
			var req: int = cost[res_id]
			if main_inv.get_available_outgoing(res_id) < req:
				return {"ok": false, "reason": "Insufficient %s! (Need %d, have %d)" % [str(res_id).capitalize(), req, main_inv.get_available_outgoing(res_id)]}
				
	return {"ok": true, "reason": "Ready to build"}

func build_road(coord: Vector2i) -> void:
	var tile: WorldTile = world_state.get_tile(coord)
	if tile != null and tile.is_walkable:
		tile.road_level = 1
		pathfinding.set_road(coord, true)
		renderer.queue_redraw()
		ui.show_toast("Built road section", false)

func place_building(b_id: StringName, coord: Vector2i, bypass_cost: bool = false) -> BuildingState:
	var check: Dictionary = can_place_building_at(b_id, coord)
	if not bypass_cost and not check.get("ok", false):
		return null
		
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	var footprint: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	
	# Deduct construction cost from Town Hall / nearest storehouse
	if not bypass_cost:
		var cost: Dictionary = def_info.get("cost", {})
		_try_deduct_cost(cost)
			
	# Instantiate building
	var b_state: BuildingState = BuildingState.new(
		next_entity_id,
		b_id,
		def_info.get("capacity", 30),
		def_info.get("accepted", [])
	)
	next_entity_id += 1
	b_state.tile_origin = coord
	b_state.assigned_workers = def_info.get("worker_slots", 0) # Auto-assign initial workers
	
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
	renderer.queue_redraw()
	return b_state

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
		ui.show_toast("⚠ Build a Barracks first to recruit troops!", true)
		return
		
	# Deduct recruitment cost (Coin) from town hall / main store
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	if main_inv == null:
		return
		
	var coin_cost: int = unit_def.recruitment_cost.get(&"coin", 0)
	if main_inv.get_available_outgoing(&"coin") < coin_cost:
		ui.show_toast("⚠ Not enough Coin! (Need %d, have %d)" % [coin_cost, main_inv.get_available_outgoing(&"coin")], true)
		return
		
	main_inv.remove_resource(&"coin", coin_cost, "RECRUITMENT", false)
	
	# Spawn unit just outside barracks
	var spawn_pos: Vector2 = Vector2((barracks_b.tile_origin.x + 3) * 16.0, (barracks_b.tile_origin.y + 1) * 16.0)
	var new_unit: MilitaryUnitState = combat.spawn_player_unit(unit_def_id, spawn_pos)
	military_units.append(new_unit)
	renderer.queue_redraw()
	ui.show_toast("⚔ Recruited %s!" % unit_def.display_name, false)

func _simulation_tick() -> void:
	current_tick += 1
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	
	# 1. Advance Production
	for b in buildings:
		var recipe: RecipeDef = defs.get(b.definition_id, {}).get("recipe", null)
		if recipe != null:
			production.tick_building(b, recipe)
			
	# 2. Advance Citizen Needs / Food consumption
	var food_inventories: Array[Inventory] = []
	for b in buildings:
		if b.inventory.get_available_outgoing(&"bread") > 0:
			food_inventories.append(b.inventory)
			
	var needs_report: Dictionary = needs.tick_citizens(citizens, food_inventories, current_tick)
	
	# Military upkeep (soldiers consume bread every 24 ticks)
	if current_tick % 24 == 0:
		combat.apply_military_upkeep(military_units, food_inventories)
	
	# Economy & Taxation
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	economy_system.tick_economy(
		economy,
		citizens.size(),
		needs_report.get("hungry", 0),
		needs_report.get("at_risk", 0),
		main_inv,
		current_tick
	)
	
	# 3. Logistics demand creation
	_generate_logistics_demand()
	
	# 4. Dispatch and tick haulers
	var inv_map: Dictionary = {}
	for b in buildings:
		inv_map[b.inventory.owner_id] = b.inventory
		
	logistics.dispatch_jobs()
	logistics.tick_haulers(inv_map, current_tick)
	
	# 5. Visible Citizen Movement along jobs
	_update_citizen_hauling_movement()
	
	# 6. Update UI counters
	_update_ui_state(needs_report)
	renderer.queue_redraw()

func _update_citizen_hauling_movement() -> void:
	for hauler in logistics.haulers:
		var citizen: CitizenState = _find_citizen_by_id(hauler.id)
		if citizen == null:
			continue
			
		if hauler.active_job != null:
			citizen.active_job_id = hauler.active_job.id
			citizen.carried_resource = hauler.carried_resource
			citizen.carried_amount = hauler.carried_amount
			
			var target_b: BuildingState = null
			if hauler.active_job.status == HaulJob.Status.ASSIGNED:
				target_b = _find_building_by_inv_id(hauler.active_job.source_inventory_id)
			elif hauler.active_job.status == HaulJob.Status.IN_TRANSIT:
				target_b = _find_building_by_inv_id(hauler.active_job.destination_inventory_id)
				
			if target_b != null:
				var path: Array[Vector2i] = pathfinding.find_path_to_adjacent(citizen.position_tile, target_b.tile_origin)
				if path.size() > 1:
					citizen.position_tile = path[1]
					hauler.current_tile = path[1]
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
	var farm_b: BuildingState = null
	var bakery_b: BuildingState = null
	var store_b: BuildingState = null
	
	for b in buildings:
		if b.definition_id == &"farm" and farm_b == null:
			farm_b = b
		elif b.definition_id == &"bakery" and bakery_b == null:
			bakery_b = b
		elif (b.definition_id == &"storehouse" or b.definition_id == &"town_hall") and store_b == null:
			store_b = b
			
	# Haul grain from farm to bakery
	if farm_b != null and bakery_b != null:
		if bakery_b.inventory.get_quantity(&"grain") + bakery_b.inventory.get_reserved_in(&"grain") < 6:
			logistics.check_and_create_demand(farm_b, bakery_b, &"grain", 4, current_tick, 2)
			
	# Haul bread from bakery to storehouse / town hall
	if bakery_b != null and store_b != null:
		if bakery_b.inventory.get_available_outgoing(&"bread") > 0:
			logistics.check_and_create_demand(bakery_b, store_b, &"bread", 4, current_tick, 1)

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
		ui.show_building_details(selected_building, defs.get(selected_building.definition_id, {}))

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
		ui.show_toast("✔ Realm state saved successfully!", false)
	else:
		ui.show_toast("⚠ Failed to save realm!", true)

func _on_load_game() -> void:
	var loaded: Dictionary = SaveService.load_game_from_file()
	if loaded.is_empty():
		ui.show_toast("⚠ No valid save found!", true)
		return
		
	economy = loaded["economy"]
	buildings = loaded["buildings"]
	citizens = loaded["citizens"]
	military_units = loaded["military_units"]
	job_board = loaded["job_board"]
	logistics.job_board = job_board
	
	current_tick = loaded["meta"].get("current_tick", 0)
	sim_speed_multiplier = loaded["meta"].get("sim_speed", 1.0)
	
	pathfinding.initialize_from_world(world_state)
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for b in buildings:
		var footprint: Vector2i = defs.get(b.definition_id, {}).get("footprint", Vector2i(2, 2))
		for dy in range(footprint.y):
			for dx in range(footprint.x):
				var c: Vector2i = b.tile_origin + Vector2i(dx, dy)
				pathfinding.set_solid(c, true)
				
	renderer.buildings = buildings
	renderer.citizens = citizens
	renderer.military_units = military_units
	selected_building = null
	selected_units.clear()
	renderer.selected_building = null
	renderer.selected_units = selected_units
	renderer.queue_redraw()
	ui.update_economy(economy.get_tax_level_name(), economy.approval)
	ui.show_toast("✔ Realm loaded successfully!", false)
