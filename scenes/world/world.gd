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

var buildings: Array[BuildingState] = []
var citizens: Array[CitizenState] = []
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
	renderer.active_jobs = []
	renderer.queue_redraw()

func _setup_signals() -> void:
	ui.speed_changed.connect(func(speed: float):
		sim_speed_multiplier = speed
	)
	ui.build_selected.connect(func(b_id: StringName):
		active_build_id = b_id
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

func _process(delta: float) -> void:
	if sim_speed_multiplier > 0.0:
		sim_tick_timer += delta * sim_speed_multiplier
		var tick_interval: float = BASE_TICK_RATE
		while sim_tick_timer >= tick_interval:
			sim_tick_timer -= tick_interval
			_simulation_tick()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var mouse_world: Vector2 = get_global_mouse_position()
		var tile_coord: Vector2i = Vector2i(int(mouse_world.x / 16.0), int(mouse_world.y / 16.0))
		
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if active_build_id != &"":
				if active_build_id == &"road":
					build_road(tile_coord)
				else:
					place_building(active_build_id, tile_coord)
			else:
				_select_building_at(tile_coord)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			active_build_id = &""
			selected_building = null
			renderer.selected_building = null
			ui.show_building_details(null, {})
			renderer.queue_redraw()

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

func build_road(coord: Vector2i) -> void:
	var tile: WorldTile = world_state.get_tile(coord)
	if tile != null and tile.is_walkable:
		tile.road_level = 1
		pathfinding.set_road(coord, true)
		renderer.queue_redraw()

func place_building(b_id: StringName, coord: Vector2i, bypass_cost: bool = false) -> BuildingState:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	if def_info.is_empty():
		return null
		
	var footprint: Vector2i = def_info.get("footprint", Vector2i(2, 2))
	
	# Validate tiles
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var c: Vector2i = coord + Vector2i(dx, dy)
			var tile: WorldTile = world_state.get_tile(c)
			if tile == null or not tile.is_buildable:
				return null
				
	# Deduct construction cost from Town Hall / nearest storehouse
	if not bypass_cost:
		var cost: Dictionary = def_info.get("cost", {})
		if not _try_deduct_cost(cost):
			return null
			
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
	
	# Mark tiles solid
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
		
	# Find town hall / main store
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
	
	# 3. Logistics demand creation
	_generate_logistics_demand()
	
	# 4. Dispatch and tick haulers
	var inv_map: Dictionary = {}
	for b in buildings:
		inv_map[b.inventory.owner_id] = b.inventory
		
	logistics.dispatch_jobs()
	logistics.tick_haulers(inv_map, current_tick)
	
	# 5. Update UI counters
	_update_ui_state(needs_report)
	renderer.queue_redraw()

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
	
	if selected_building != null:
		var defs: Dictionary = BuildingCatalog.get_all_defs()
		ui.show_building_details(selected_building, defs.get(selected_building.definition_id, {}))
