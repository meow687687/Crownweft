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
var economy: EconomyState = EconomyState.new()
var economy_system: EconomySystem = EconomySystem.new()
var government: GovernmentState = GovernmentState.new()
var diplomacy: DiplomacyState = DiplomacyState.new()
var diplomacy_system: DiplomacySystem = DiplomacySystem.new()
var regional_world: RegionalWorldState = null

var buildings: Array[BuildingState] = []
var citizens: Array[CitizenState] = []
var military_units: Array[MilitaryUnitState] = []
var selected_units: Array[MilitaryUnitState] = []
var next_entity_id: int = 1
var auto_staffing_enabled: bool = false

# Simulation timing
var sim_speed_multiplier: float = 1.0 # 0.0 = pause, 1.0 = 1x, 2.0 = 2x, 3.0 = 3x
var sim_tick_timer: float = 0.0
const BASE_TICK_RATE: float = 0.25 # 4 ticks per real second at 1x
var current_tick: int = 0

# Placement / Selection state
var active_build_id: StringName = &""
var active_build_footprint: Vector2i = Vector2i.ZERO
var is_dragging_footprint: bool = false
var drag_start_tile: Vector2i = Vector2i(-1, -1)
var selected_building: BuildingState = null
var selected_citizen: CitizenState = null

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
	government = GovernmentState.new()
	diplomacy = DiplomacyState.new()
	diplomacy_system = DiplomacySystem.new()
	regional_world = RegionalWorldState.new()
	regional_world.regions = RegionCatalog.create_default_regions()
	regional_world.routes = RegionCatalog.create_default_routes()
	regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	regional_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Royal Crown Guard",
		RegionCatalog.REGION_CROWNWEFT,
		{&"warrior": 12, &"archer": 6},
		40,
		0
	)
	regional_world.create_army(
		FactionCatalog.FACTION_IRONPEAK,
		"Ironpeak Vanguard",
		RegionCatalog.REGION_IRONPEAK,
		{&"warrior": 16, &"archer": 8},
		30,
		0
	)
	
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
		var citizen: CitizenState = spawn_citizen(c_pos)
		
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
		var def_info: Dictionary = BuildingCatalog.get_all_defs().get(b_id, {})
		active_build_footprint = def_info.get("footprint", Vector2i(2, 2))
		is_dragging_footprint = false
		drag_start_tile = Vector2i(-1, -1)
		renderer.active_build_id = b_id
		renderer.hover_footprint = active_build_footprint
		renderer.queue_redraw()
	)
	ui.toggle_overlay_requested.connect(func():
		renderer.show_logistics_overlay = not renderer.show_logistics_overlay
		renderer.queue_redraw()
	)
	ui.worker_assignment_changed.connect(_on_worker_assignment_changed)
	ui.building_priority_changed.connect(_on_building_priority_changed)
	ui.unassign_specific_worker_requested.connect(_on_unassign_specific_worker)
	ui.toggle_workforce_panel_requested.connect(_on_toggle_workforce_panel)
	ui.auto_staffing_toggled.connect(_on_auto_staffing_toggled)
	ui.citizen_selected_from_panel.connect(_on_citizen_selected_from_panel)
	ui.recruit_unit_requested.connect(_on_recruit_unit_requested)
	ui.tax_level_cycled.connect(_on_tax_level_cycled)
	ui.toggle_government_panel_requested.connect(_on_toggle_government_panel)
	ui.policy_enact_requested.connect(func(l_id: StringName, o_id: StringName):
		enact_policy(l_id, o_id, "Decree via Laws Panel")
	)
	ui.toggle_diplomacy_panel_requested.connect(_on_toggle_diplomacy_panel)
	ui.proposal_response_requested.connect(_on_proposal_response)
	ui.ceasefire_requested.connect(_on_ceasefire_requested)
	ui.peace_requested.connect(_on_peace_requested)
	ui.toggle_world_map_panel_requested.connect(_on_toggle_world_map_panel)
	ui.region_selected.connect(_on_region_selected)
	ui.army_march_requested.connect(_on_army_march_requested)
	ui.army_halt_requested.connect(_on_army_halt_requested)
	ui.army_resupply_requested.connect(_on_army_resupply_requested)
	combat.unit_died.connect(_on_unit_died)
	ui.save_game_requested.connect(_on_save_game)
	ui.load_game_requested.connect(_on_load_game)

func _process(delta: float) -> void:
	# Update Placement Preview Ghost
	if active_build_id != &"":
		var mouse_world: Vector2 = get_global_mouse_position()
		var tile_coord: Vector2i = Vector2i(int(mouse_world.x / 16.0), int(mouse_world.y / 16.0))
		
		if is_dragging_footprint and drag_start_tile != Vector2i(-1, -1):
			var min_x: int = mini(drag_start_tile.x, tile_coord.x)
			var min_y: int = mini(drag_start_tile.y, tile_coord.y)
			var w: int = absi(tile_coord.x - drag_start_tile.x) + 1
			var h: int = absi(tile_coord.y - drag_start_tile.y) + 1
			active_build_footprint = BuildingCatalog.clamp_footprint(active_build_id, Vector2i(w, h))
			renderer.hover_tile = Vector2i(min_x, min_y)
		else:
			renderer.hover_tile = tile_coord
			
		renderer.active_build_id = active_build_id
		renderer.hover_footprint = active_build_footprint
		var check: Dictionary = can_place_building_at(active_build_id, renderer.hover_tile, active_build_footprint)
		renderer.is_hover_valid = check.get("ok", false)
		
		if ui != null:
			var cost_dict: Dictionary = BuildingCatalog.get_cost_for_footprint(active_build_id, active_build_footprint)
			var cost_str: String = ""
			for r in cost_dict:
				cost_str += "%s: %d " % [str(r).capitalize(), cost_dict[r]]
			var cap_val: int = BuildingCatalog.get_capacity_for_footprint(active_build_id, active_build_footprint)
			var info_str: String = "Size: %dx%d  |  Cost: %s |  Cap: %d  |  %s" % [
				active_build_footprint.x, active_build_footprint.y,
				cost_str.strip_edges() if cost_str != "" else "Free",
				cap_val,
				check.get("reason", "")
			]
			ui.update_build_prompt(active_build_id, info_str)
		renderer.queue_redraw()
	else:
		if renderer.hover_tile != Vector2i(-1, -1):
			renderer.hover_tile = Vector2i(-1, -1)
			renderer.active_build_id = &""
			renderer.hover_footprint = Vector2i.ZERO
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
		var b_fp: Vector2i = building.get_footprint()
		for y in range(b_fp.y):
			for x in range(b_fp.x):
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
	if event is InputEventKey and event.pressed and not event.echo:
		var kb_event: InputEventKey = event as InputEventKey
		if kb_event.keycode == KEY_W and active_build_id == &"":
			_on_toggle_workforce_panel()
			get_viewport().set_input_as_handled()
			return
		elif kb_event.keycode == KEY_L and active_build_id == &"":
			_on_toggle_government_panel()
			get_viewport().set_input_as_handled()
			return
		elif kb_event.keycode == KEY_D and active_build_id == &"":
			_on_toggle_diplomacy_panel()
			get_viewport().set_input_as_handled()
			return
		elif kb_event.keycode == KEY_M and active_build_id == &"":
			_on_toggle_world_map_panel()
			get_viewport().set_input_as_handled()
			return

	if active_build_id != &"" and BuildingCatalog.is_building_resizable(active_build_id):
		if event is InputEventKey and event.pressed:
			var kb: InputEventKey = event as InputEventKey
			var min_fp: Vector2i = BuildingCatalog.get_min_footprint(active_build_id)
			var max_fp: Vector2i = BuildingCatalog.get_max_footprint(active_build_id)
			if kb.keycode == KEY_BRACKETLEFT:
				active_build_footprint.x = maxi(min_fp.x, active_build_footprint.x - 1)
				get_viewport().set_input_as_handled()
				return
			elif kb.keycode == KEY_BRACKETRIGHT:
				active_build_footprint.x = mini(max_fp.x, active_build_footprint.x + 1)
				get_viewport().set_input_as_handled()
				return
			elif kb.keycode == KEY_MINUS:
				active_build_footprint.y = maxi(min_fp.y, active_build_footprint.y - 1)
				get_viewport().set_input_as_handled()
				return
			elif kb.keycode == KEY_EQUAL:
				active_build_footprint.y = mini(max_fp.y, active_build_footprint.y + 1)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		# Protection: Ignore clicks if mouse is over top HUD, bottom palette, inspector, or workforce panel
		var mouse_screen: Vector2 = get_viewport().get_mouse_position()
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		if mouse_screen.y < 104.0 or mouse_screen.y > (screen_size.y - 142.0):
			return
		if ui != null and ui.panel_workforce != null and ui.panel_workforce.visible:
			var wf_rect := Rect2(screen_size * 0.5 - Vector2(340, 250), Vector2(680, 500))
			if wf_rect.has_point(mouse_screen):
				return
		if ui != null and ui.panel_government != null and ui.panel_government.visible:
			var gov_rect := Rect2(screen_size * 0.5 - Vector2(340, 250), Vector2(680, 500))
			if gov_rect.has_point(mouse_screen):
				return
		if ui != null and ui.panel_diplomacy != null and ui.panel_diplomacy.visible:
			var dip_rect := Rect2(screen_size * 0.5 - Vector2(380, 260), Vector2(760, 520))
			if dip_rect.has_point(mouse_screen):
				return
		if ui != null and ui.panel_inspector != null and ui.panel_inspector.visible and mouse_screen.x > (screen_size.x - 350.0):
			return
			
		var mouse_world: Vector2 = get_global_mouse_position()
		var tile_coord: Vector2i = Vector2i(int(mouse_world.x / 16.0), int(mouse_world.y / 16.0))
		
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if active_build_id != &"":
					if active_build_id == &"road":
						build_road(tile_coord)
					elif BuildingCatalog.is_building_resizable(active_build_id):
						is_dragging_footprint = true
						drag_start_tile = tile_coord
					else:
						var res = place_building(active_build_id, tile_coord, false, active_build_footprint)
						if res == null:
							var check = can_place_building_at(active_build_id, tile_coord, active_build_footprint)
							ui.show_toast(check.get("reason", "Cannot place here!"), true)
						else:
							var defs = BuildingCatalog.get_all_defs()
							ui.show_toast("Constructed %s" % defs.get(active_build_id, {}).get("display_name", "Building"), false)
				else:
					var clicked_citizen: CitizenState = _find_citizen_at(mouse_world)
					if clicked_citizen != null:
						selected_citizen = clicked_citizen
						selected_building = null
						selected_units.clear()
						renderer.selected_building = null
						renderer.selected_units = selected_units
						_update_citizen_inspector()
						renderer.queue_redraw()
					else:
						selected_citizen = null
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
			else: # Button released
				if is_dragging_footprint:
					is_dragging_footprint = false
					var place_origin: Vector2i = renderer.hover_tile
					var res = place_building(active_build_id, place_origin, false, active_build_footprint)
					if res == null:
						var check = can_place_building_at(active_build_id, place_origin, active_build_footprint)
						ui.show_toast(check.get("reason", "Cannot place here!"), true)
					else:
						var defs = BuildingCatalog.get_all_defs()
						ui.show_toast("Constructed %s (%dx%d)" % [
							defs.get(active_build_id, {}).get("display_name", "Building"),
							active_build_footprint.x,
							active_build_footprint.y
						], false)
					drag_start_tile = Vector2i(-1, -1)
					
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			is_dragging_footprint = false
			drag_start_tile = Vector2i(-1, -1)
			if active_build_id != &"":
				active_build_id = &""
				active_build_footprint = Vector2i.ZERO
				ui.set_active_build_mode(&"")
				renderer.active_build_id = &""
				renderer.hover_tile = Vector2i(-1, -1)
				renderer.hover_footprint = Vector2i.ZERO
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
				selected_citizen = null
				renderer.selected_building = null
				ui.show_building_details(null, {})
				renderer.queue_redraw()

func _find_citizen_at(pos: Vector2) -> CitizenState:
	for c: CitizenState in citizens:
		var c_world := Vector2(c.position_tile.x * 16.0 + 8.0, c.position_tile.y * 16.0 + 8.0)
		if c_world.distance_to(pos) <= 12.0:
			return c
	return null

func _update_citizen_inspector() -> void:
	if selected_citizen == null or ui == null:
		return
	var wp: BuildingState = _find_building_by_entity_id(selected_citizen.workplace_id)
	var hm: BuildingState = _find_building_by_entity_id(selected_citizen.home_building_id)
	ui.show_citizen_details(selected_citizen, wp, hm, government)

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
	var max_slots: int = 3 if selected_building.is_under_construction() else BuildingCatalog.get_worker_slots_for_footprint(selected_building.definition_id, selected_building.get_footprint())
	if delta > 0:
		var available: CitizenState = null
		if selected_building.definition_id == &"town_hall":
			for citizen: CitizenState in citizens:
				if citizen.role_id == &"unassigned" and citizen.workplace_id == 0:
					if citizen.social_status_id in [&"administrator", &"noble", &"scholar"]:
						available = citizen
						break
			if available == null:
				if ui != null:
					ui.show_toast("Town Hall requires an Administrator, Scholar, or Noble", true)
				return
		else:
			for citizen: CitizenState in citizens:
				if citizen.role_id == &"unassigned" and citizen.workplace_id == 0:
					available = citizen
					break
		if selected_building.assigned_workers >= max_slots:
			if ui != null:
				ui.show_toast("This building has no open %s slots" % ("builder" if selected_building.is_under_construction() else "worker"), true)
			return
		if available == null:
			if ui != null:
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
	_update_building_inspector()
	_update_workforce_panel()
	if renderer != null:
		renderer.queue_redraw()

func _worker_role_for_building(building_id: StringName) -> StringName:
	match building_id:
		&"town_hall": return &"administrator"
		&"farm": return &"farmer"
		&"woodcutter": return &"woodcutter"
		&"quarry": return &"quarry_worker"
		&"bakery": return &"baker"
		&"storehouse": return &"storekeeper"
		_: return &"worker"

func _select_building_at(tile_coord: Vector2i) -> void:
	selected_building = null
	selected_citizen = null
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for b in buildings:
		var rect: Rect2i = Rect2i(b.tile_origin, b.get_footprint())
		if rect.has_point(tile_coord):
			selected_building = b
			break
			
	if renderer != null:
		renderer.selected_building = selected_building
	if selected_building != null:
		_update_building_inspector()
	else:
		if ui != null:
			ui.show_building_details(null, {})
	if renderer != null:
		renderer.queue_redraw()

func can_place_building_at(b_id: StringName, coord: Vector2i, custom_footprint: Vector2i = Vector2i.ZERO) -> Dictionary:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	if def_info.is_empty():
		return {"ok": false, "reason": "Unknown building"}
		
	var footprint: Vector2i = custom_footprint
	if footprint == Vector2i.ZERO:
		footprint = def_info.get("footprint", Vector2i(2, 2))
	else:
		footprint = BuildingCatalog.clamp_footprint(b_id, footprint)
	
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
	var entrance_offset: Vector2i = Vector2i(footprint.x / 2, footprint.y) if BuildingCatalog.is_building_resizable(b_id) else def_info.get("entrance_offset", Vector2i.ZERO)
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

func place_building(b_id: StringName, coord: Vector2i, bypass_cost: bool = false, custom_footprint: Vector2i = Vector2i.ZERO) -> BuildingState:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(b_id, {})
	if def_info.is_empty():
		return null
		
	var footprint: Vector2i = custom_footprint
	if footprint == Vector2i.ZERO:
		footprint = def_info.get("footprint", Vector2i(2, 2))
	else:
		footprint = BuildingCatalog.clamp_footprint(b_id, footprint)

	var check: Dictionary = can_place_building_at(b_id, coord, footprint)
	if not bypass_cost and not check.get("ok", false):
		return null
		
	var cost: Dictionary = BuildingCatalog.get_cost_for_footprint(b_id, footprint)
	var build_time: int = BuildingCatalog.get_build_time_for_footprint(b_id, footprint)
	var capacity: int = BuildingCatalog.get_capacity_for_footprint(b_id, footprint)
	
	var b_state: BuildingState = null
	if bypass_cost or cost.is_empty():
		b_state = BuildingState.new(
			next_entity_id,
			b_id,
			capacity,
			def_info.get("accepted", [])
		)
		b_state.footprint = footprint
		b_state.recalculate_entrance(footprint)
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
			capacity,
			def_info.get("accepted", []),
			footprint
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
	var max_slots: int = BuildingCatalog.get_worker_slots_for_footprint(building.definition_id, building.get_footprint())
	
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
	var footprint: Vector2i = building.get_footprint()
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
		_update_building_inspector()
	_update_workforce_panel()
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
	var footprint: Vector2i = building.get_footprint()
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

	# Auto-staffing
	if auto_staffing_enabled and current_tick % 12 == 0:
		auto_staff_workplaces()

	# Update housing assignments, resting, and energy recovery
	_update_housing_and_rest()

	# Assigned workers must physically reach their worksite before production/construction can advance.
	_update_worker_movement()

	# 1. Production and Construction.
	for building: BuildingState in buildings:
		if building.is_under_construction():
			var present_builders: Array[CitizenState] = _get_workers_present_at_building(building)
			construction.tick_building(building, present_builders.size(), current_tick, present_builders, government)
		elif building.status == BuildingState.Status.ACTIVE:
			var recipe: RecipeDef = defs.get(building.definition_id, {}).get("recipe", null)
			if recipe != null:
				var present_workers: Array[CitizenState] = _get_workers_present_at_building(building)
				production.tick_building(building, recipe, world_state, present_workers.size(), present_workers, government)

	# 2. Needs are supplied only by inventories the citizen can physically reach.
	var food_inventories: Array[Inventory] = []
	for building: BuildingState in buildings:
		# Food is consumed from actual household-accessible stores only. Bread sitting
		# in the bakery must be hauled to a storehouse or Town Hall first.
		if building.definition_id in [&"town_hall", &"storehouse"]:
			if building.inventory.get_available_outgoing(&"bread") > 0 or building.inventory.get_available_outgoing(&"meat") > 0:
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
		current_tick,
		citizens,
		government,
		diplomacy
	)

	# Faction diplomacy decisions and relationship tracking
	diplomacy_system.tick_diplomacy(diplomacy, current_tick, main_inv, economy, government)
	_tick_active_wars()
	if regional_world != null:
		regional_world.tick_regional_armies(current_tick, diplomacy)

	# Periodic check for social status advancement
	if current_tick % 20 == 0:
		for c: CitizenState in citizens:
			SocialClassService.check_automatic_advancement(c, current_tick)

	# 4. Create demands, assign jobs, and physically move haulers along A* paths.
	var citizens_by_id: Dictionary = {}
	for c: CitizenState in citizens:
		citizens_by_id[c.id] = c

	_generate_logistics_demand()
	logistics.dispatch_jobs(citizens_by_id)
	logistics.tick_haulers(inv_map, current_tick, pathfinding, building_by_inv, citizens_by_id)
	_update_citizen_hauling_movement()

	# 5. Keep the route overlay connected to live jobs.
	renderer.active_jobs.clear()
	for job: HaulJob in job_board.jobs.values():
		if job.status != HaulJob.Status.DELIVERED and job.status != HaulJob.Status.CANCELLED:
			renderer.active_jobs.append(job)
	_update_ui_state(needs_report)
	if selected_citizen != null:
		_update_citizen_inspector()
	if selected_building != null:
		_update_building_inspector()
	if ui != null and ui.is_workforce_panel_visible():
		_update_workforce_panel()
	if ui != null and ui.is_government_panel_visible():
		_update_government_ui()
	if ui != null and ui.is_diplomacy_panel_visible():
		_update_diplomacy_ui()
	if ui != null and ui.is_world_map_visible():
		_update_world_map_ui()
	renderer.queue_redraw()

func _update_worker_movement() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var building_worker_slots: Dictionary = {}
	
	# Pre-collect occupied staging tiles of idle workers at their workplace
	var occupied_by_building: Dictionary = {}
	for citizen: CitizenState in citizens:
		if citizen.role_id == &"hauler" or citizen.workplace_id <= 0 or citizen.is_resting:
			continue
		if citizen.move_state == CitizenState.MoveState.IDLE:
			var b_id: int = citizen.workplace_id
			if not occupied_by_building.has(b_id):
				occupied_by_building[b_id] = []
			(occupied_by_building[b_id] as Array[Vector2i]).append(citizen.position_tile)

	for citizen: CitizenState in citizens:
		if citizen.role_id == &"hauler":
			continue
		if citizen.is_resting:
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

		var footprint: Vector2i = workplace.get_footprint()
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

func _get_workers_present_at_building(building: BuildingState) -> Array[CitizenState]:
	var footprint: Vector2i = building.get_footprint()
	var list: Array[CitizenState] = []
	for citizen: CitizenState in citizens:
		if citizen.workplace_id != building.entity_id or citizen.role_id == &"hauler":
			continue
		if not citizen.is_resting and citizen.move_state == CitizenState.MoveState.IDLE and _is_adjacent_to_building(citizen.position_tile, building, footprint):
			list.append(citizen)
	return list

func _count_workers_at_building(building: BuildingState) -> int:
	return _get_workers_present_at_building(building).size()

func _update_housing_and_rest() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var house_occupants: Dictionary = {} # int -> int
	var available_houses: Array[BuildingState] = []
	for b: BuildingState in buildings:
		if b.status == BuildingState.Status.ACTIVE:
			var cap: int = int(defs.get(b.definition_id, {}).get("housing_capacity", 0))
			if cap > 0:
				house_occupants[b.entity_id] = 0
				available_houses.append(b)

	# Tally existing occupants
	for c: CitizenState in citizens:
		if c.home_building_id > 0:
			if house_occupants.has(c.home_building_id):
				house_occupants[c.home_building_id] += 1
			else:
				c.home_building_id = 0

	# Assign homeless citizens to houses with free capacity
	for c: CitizenState in citizens:
		if c.home_building_id <= 0:
			for h: BuildingState in available_houses:
				var cap: int = int(defs.get(h.definition_id, {}).get("housing_capacity", 0))
				if house_occupants.get(h.entity_id, 0) < cap:
					c.home_building_id = h.entity_id
					house_occupants[h.entity_id] = house_occupants.get(h.entity_id, 0) + 1
					break

	# Process energy and rest state
	for c: CitizenState in citizens:
		if not c.is_resting:
			if c.is_exhausted():
				if c.role_id == &"hauler" and c.carried_amount > 0:
					pass
				else:
					c.is_resting = true
					c.path.clear()
					c.move_state = CitizenState.MoveState.IDLE
			elif c.move_state == CitizenState.MoveState.IDLE and c.workplace_id <= 0:
				c.consume_energy(CitizenState.IDLE_ENERGY_DRAIN)

		if c.is_resting:
			var home: BuildingState = _find_building_by_entity_id(c.home_building_id)
			if home == null or home.is_destroyed or home.status != BuildingState.Status.ACTIVE:
				c.home_building_id = 0
				# Attempt to find another house
				for h: BuildingState in available_houses:
					var cap: int = int(defs.get(h.definition_id, {}).get("housing_capacity", 0))
					if house_occupants.get(h.entity_id, 0) < cap:
						c.home_building_id = h.entity_id
						house_occupants[h.entity_id] = house_occupants.get(h.entity_id, 0) + 1
						home = h
						break

			if home == null:
				c.current_block_reason = &"Cannot rest — no valid home assigned"
				c.move_state = CitizenState.MoveState.IDLE
				c.path.clear()
				c.target_tile = c.position_tile
				continue

			var home_footprint: Vector2i = home.get_footprint()
			if _is_adjacent_to_building(c.position_tile, home, home_footprint):
				c.move_state = CitizenState.MoveState.IDLE
				c.path.clear()
				c.target_tile = c.position_tile
				c.current_block_reason = &""
				c.restore_energy(CitizenState.REST_ENERGY_RECOVERY)
				if c.is_recovered():
					c.is_resting = false
					c.path.clear()
					c.move_state = CitizenState.MoveState.IDLE
			else:
				_route_citizen_to_home(c, home)

func _route_citizen_to_home(citizen: CitizenState, home: BuildingState) -> void:
	if not citizen.path.is_empty():
		if pathfinding.astar_grid.is_point_solid(citizen.path[0]) or pathfinding.astar_grid.is_point_solid(citizen.target_tile):
			citizen.path.clear()

	if citizen.path.is_empty():
		var route_res: Dictionary = pathfinding.find_path_to_entrance(
			citizen.position_tile, home
		)
		if not route_res.get("ok", false):
			citizen.move_state = CitizenState.MoveState.IDLE
			citizen.target_tile = citizen.position_tile
			citizen.current_block_reason = &"Cannot rest — route to home blocked"
			return

		citizen.current_block_reason = &""
		var route: Array[Vector2i] = []
		route.assign(route_res.get("path", []))
		citizen.path = route
		citizen.target_tile = route_res.get("target_tile", route[route.size() - 1] if not route.is_empty() else citizen.position_tile)
		if not citizen.path.is_empty():
			citizen.path.remove_at(0)
		if citizen.path.is_empty():
			citizen.move_state = CitizenState.MoveState.IDLE
			citizen.target_tile = citizen.position_tile
			return

	if not citizen.path.is_empty():
		citizen.position_tile = citizen.path.pop_front()
		citizen.move_state = CitizenState.MoveState.MOVING if not citizen.path.is_empty() else CitizenState.MoveState.IDLE
		if citizen.path.is_empty():
			citizen.target_tile = citizen.position_tile

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
		_update_building_inspector()

func _on_tax_level_cycled() -> void:
	cycle_tax_level()

func cycle_tax_level() -> void:
	if government == null:
		return
	var current_opt: StringName = government.get_policy(LawCatalog.LAW_TAXATION)
	var next_opt: StringName = &"standard"
	match current_opt:
		&"low":
			next_opt = &"standard"
		&"standard":
			next_opt = &"high"
		&"high":
			next_opt = &"low"
		_:
			next_opt = &"standard"
	enact_policy(LawCatalog.LAW_TAXATION, next_opt, "Tax level cycled via HUD")

func enact_policy(law_id: StringName, option_id: StringName, reason: String = "") -> bool:
	if government == null:
		return false
	var ok: bool = government.enact_policy(law_id, option_id, current_tick, reason)
	if ok:
		if law_id == LawCatalog.LAW_TAXATION:
			match option_id:
				&"low":
					economy.tax_level = EconomyState.TaxLevel.LOW
				&"standard":
					economy.tax_level = EconomyState.TaxLevel.NORMAL
				&"high":
					economy.tax_level = EconomyState.TaxLevel.HIGH
			if ui != null and economy != null:
				ui.update_economy(economy.get_tax_level_name(), economy.approval)
		var opt_def: Dictionary = LawCatalog.get_option_def(law_id, option_id)
		var opt_name: String = str(opt_def.get("display_name", str(option_id)))
		if ui != null:
			ui.show_toast("Policy enacted: %s" % opt_name, false)
			_update_government_ui()
	return ok

func _on_toggle_government_panel() -> void:
	if ui != null:
		ui.toggle_government_panel()
		if ui.is_government_panel_visible():
			_update_government_ui()

func _update_government_ui() -> void:
	if ui == null or government == null:
		return
	var has_admin: bool = false
	for c in citizens:
		if c.role_id == &"administrator" and c.workplace_id > 0:
			has_admin = true
			break
	var gov_data: Dictionary = {
		"enacted_policies": government.enacted_policies.duplicate(),
		"has_admin": has_admin,
		"treasury_coin": buildings[0].inventory.get_quantity(&"coin") if not buildings.is_empty() else 0,
		"last_tax_income": economy.last_tax_income if economy != null else 0,
		"approval": economy.approval if economy != null else 60.0,
		"history": government.get_recent_history(5)
	}
	ui.update_government_panel(gov_data)

func _on_toggle_diplomacy_panel() -> void:
	if ui != null:
		ui.toggle_diplomacy_panel()
		if ui.is_diplomacy_panel_visible():
			_update_diplomacy_ui()

func _on_proposal_response(proposal_id: int, accept: bool) -> void:
	if diplomacy == null or diplomacy_system == null:
		return
	var main_inv: Inventory = buildings[0].inventory if not buildings.is_empty() else null
	var res: Dictionary = diplomacy_system.resolve_player_response(diplomacy, proposal_id, accept, main_inv, economy, current_tick)
	if res.get("ok", false):
		var msg: String = "Diplomatic proposal accepted." if accept else "Diplomatic proposal refused."
		if ui != null:
			ui.show_toast(msg, false)
			_update_diplomacy_ui()
	else:
		if ui != null:
			ui.show_toast(res.get("reason", "Cannot resolve proposal"), true)

func _update_diplomacy_ui() -> void:
	if ui == null or diplomacy == null:
		return

	var facs_data: Dictionary = {}
	var rels_data: Dictionary = {}
	for f_id in diplomacy.factions:
		var f: FactionState = diplomacy.factions[f_id]
		facs_data[str(f_id)] = f.serialize()
		if f_id != FactionCatalog.FACTION_PLAYER:
			var rel: DiplomaticRelationship = diplomacy.get_relationship(f_id, FactionCatalog.FACTION_PLAYER)
			var r_dict: Dictionary = rel.serialize()
			r_dict["stance"] = rel.get_relationship_stance()
			rels_data[str(f_id)] = r_dict

	var props_arr: Array = []
	for p in diplomacy.pending_proposals:
		var p_dict: Dictionary = p.serialize()
		p_dict["title"] = p.get_title()
		props_arr.append(p_dict)

	var wars_arr: Array = []
	for w in diplomacy.active_wars:
		wars_arr.append(w.serialize())

	var dip_payload: Dictionary = {
		"factions": facs_data,
		"relationships": rels_data,
		"proposals": props_arr,
		"chronicle": diplomacy.diplomatic_chronicle.duplicate(true),
		"active_wars": wars_arr,
		"war_history": diplomacy.war_history.duplicate(true)
	}
	ui.update_diplomacy_panel(dip_payload)

func _tick_active_wars() -> void:
	if diplomacy == null:
		return
	for war in diplomacy.active_wars:
		if war.status == WarState.STATUS_WAR and not war.attacker_expedition_spawned:
			# Spawn border attack expedition
			var camp_pos: Vector2 = Vector2(world_state.raider_camp_pos.x * 16.0, world_state.raider_camp_pos.y * 16.0)
			for i in range(4):
				var spawn_pos: Vector2 = camp_pos + Vector2((i % 2) * 16.0, (i / 2) * 16.0)
				var unit: MilitaryUnitState = combat.spawn_raider_unit(spawn_pos)
				unit.faction_id = FactionCatalog.get_numeric_faction_id(war.initiating_faction)
				military_units.append(unit)
				war.attacker_expedition_unit_ids.append(unit.id)
			war.attacker_expedition_spawned = true
			if ui != null:
				ui.show_toast("INVASION FORCES ADVANCING: %s troops approaching border!" % [
					diplomacy.factions.get(war.initiating_faction, FactionState.new()).display_name
				], true)
				_update_diplomacy_ui()
		elif war.status in [WarState.STATUS_CEASEFIRE, WarState.STATUS_PEACE]:
			# Clean surviving expedition units from map upon ceasefire/peace
			for uid in war.attacker_expedition_unit_ids:
				var u: MilitaryUnitState = combat._find_unit_by_id(military_units, uid)
				if u != null and not u.is_dead:
					u.is_dead = true

func _on_unit_died(unit: MilitaryUnitState) -> void:
	if diplomacy == null:
		return
	var dead_fac: StringName = FactionCatalog.get_faction_id_from_numeric(unit.faction_id)
	for war in diplomacy.active_wars:
		if war.initiating_faction == dead_fac or war.target_faction == dead_fac:
			war.record_casualty(dead_fac)
			# Check if all expedition attackers are defeated
			if unit.id in war.attacker_expedition_unit_ids:
				var all_repelled: bool = true
				for uid in war.attacker_expedition_unit_ids:
					var u: MilitaryUnitState = combat._find_unit_by_id(military_units, uid)
					if u != null and not u.is_dead:
						all_repelled = false
						break
				if all_repelled:
					war.record_battle(
						current_tick,
						"Crown defenders repelled the border expedition",
						int(war.casualties.get(str(war.initiating_faction), 0)),
						int(war.casualties.get(str(war.target_faction), 0)),
						&"repelled"
					)
					diplomacy.add_chronicle(
						current_tick,
						"BATTLE VICTORY: Crown defenders routed the hostile %s expedition!" % [
							diplomacy.factions.get(war.initiating_faction, FactionState.new()).display_name
						],
						&"battle_victory"
					)
					if ui != null:
						ui.show_toast("BATTLE WON: Enemy expedition repelled! Truce is now viable.", false)
						_update_diplomacy_ui()

func _on_ceasefire_requested(war_id: int) -> void:
	if diplomacy == null or diplomacy_system == null:
		return
	var res: Dictionary = diplomacy_system.negotiate_ceasefire(diplomacy, war_id, current_tick)
	if res.get("ok", false):
		if ui != null:
			ui.show_toast("Ceasefire negotiated. Hostilities paused for 240 ticks.", false)
			_update_diplomacy_ui()
	else:
		if ui != null:
			ui.show_toast(res.get("reason", "Cannot negotiate ceasefire"), true)

func _on_peace_requested(war_id: int) -> void:
	if diplomacy == null or diplomacy_system == null:
		return
	var res: Dictionary = diplomacy_system.conclude_peace_treaty(diplomacy, war_id, current_tick, WarState.OUTCOME_WHITE_PEACE)
	if res.get("ok", false):
		if ui != null:
			ui.show_toast("Peace treaty concluded. Permanent peace restored.", false)
			_update_diplomacy_ui()
	else:
		if ui != null:
			ui.show_toast(res.get("reason", "Cannot conclude peace treaty"), true)

func _on_toggle_world_map_panel() -> void:
	if ui == null or regional_world == null:
		return
	ui.toggle_world_map_panel()
	if ui.is_world_map_visible():
		_update_world_map_ui()

func _on_region_selected(region_id: StringName) -> void:
	if regional_world != null:
		regional_world.selected_region_id = region_id
		_update_world_map_ui()

func _update_world_map_ui() -> void:
	if ui == null or regional_world == null:
		return
	var payload: Dictionary = {
		"regional_world": regional_world,
		"regions": regional_world.regions,
		"routes": regional_world.routes,
		"armies": regional_world.armies,
		"selected_region_id": regional_world.selected_region_id,
		"diplomacy": diplomacy,
		"active_wars": diplomacy.active_wars if diplomacy != null else []
	}
	ui.update_world_map(payload)

func _on_army_march_requested(army_id: int, dest_region_id: StringName) -> void:
	if regional_world == null:
		return
	var res: Dictionary = regional_world.issue_march_order(army_id, dest_region_id, current_tick, diplomacy)
	if res.get("ok", false):
		ui.show_toast("Army dispatched towards %s." % str(dest_region_id), false)
		_update_world_map_ui()
	else:
		ui.show_toast(res.get("reason", "Cannot issue march order"), true)

func _on_army_halt_requested(army_id: int) -> void:
	if regional_world == null:
		return
	var res: Dictionary = regional_world.halt_army(army_id, "Order to hold position", current_tick)
	if res.get("ok", false):
		ui.show_toast("Army holding position.", false)
		_update_world_map_ui()

func _on_army_resupply_requested(army_id: int) -> void:
	if regional_world == null:
		return
	var army: ArmyState = regional_world.get_army(army_id)
	if army == null:
		return
	var res: Dictionary = {}
	if army.current_region_id == RegionCatalog.REGION_CROWNWEFT and not buildings.is_empty():
		res = regional_world.resupply_army(army_id, "local_inventory", buildings[0].inventory, 25, current_tick)
	else:
		var reg: RegionState = regional_world.get_region(army.current_region_id)
		res = regional_world.resupply_army(army_id, "regional_stockpile", reg, 25, current_tick)

	if res.get("ok", false):
		var trans: int = int(res.get("transferred", 0))
		if trans > 0:
			ui.show_toast("Transferred %d Grain to %s." % [trans, army.name], false)
		else:
			ui.show_toast("No supplies available or army capacity full.", true)
		_update_world_map_ui()
	else:
		ui.show_toast(res.get("reason", "Resupply failed"), true)

func _on_save_game() -> void:
	var success: bool = SaveService.save_game_to_file(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		current_tick,
		sim_speed_multiplier,
		SaveService.DEFAULT_SAVE_PATH,
		auto_staffing_enabled,
		government,
		diplomacy,
		regional_world
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
	government = loaded.get("government", GovernmentState.new())
	diplomacy = loaded.get("diplomacy", DiplomacyState.new())
	regional_world = loaded.get("regional_world", RegionalWorldState.new())
	if regional_world.regions.is_empty():
		regional_world.regions = RegionCatalog.create_default_regions()
		regional_world.routes = RegionCatalog.create_default_routes()
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
	auto_staffing_enabled = loaded["meta"].get("auto_staffing_enabled", false)
	
	pathfinding.initialize_from_world(world_state)
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	next_entity_id = 1
	combat.next_unit_id = 1000
	var max_job_id: int = 0
	for b: BuildingState in buildings:
		next_entity_id = maxi(next_entity_id, b.entity_id + 1)
		var b_fp: Vector2i = b.get_footprint()
		for dy in range(b_fp.y):
			for dx in range(b_fp.x):
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
	_update_workforce_panel()
	ui.show_toast("Realm loaded successfully", false)

func _update_building_inspector() -> void:
	if selected_building == null or ui == null:
		return
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(selected_building.definition_id, {})
	var workers_present: int = _count_workers_at_building(selected_building)
	var diag: Dictionary = get_building_diagnostic_details(selected_building)
	ui.show_building_details(selected_building, def_info, workers_present, diag)

func _update_workforce_panel() -> void:
	if ui != null:
		ui.update_workforce_panel(get_workforce_summary(), get_workforce_citizens_data(), auto_staffing_enabled)

func _on_building_priority_changed(delta: int) -> void:
	if selected_building == null:
		return
	var new_pri: int = clampi(selected_building.work_priority + delta, BuildingState.PRIORITY_MIN, BuildingState.PRIORITY_MAX)
	set_building_priority(selected_building, new_pri)
	if ui != null:
		ui.show_toast("Building priority set to %d (%s)" % [new_pri, BuildingState.get_priority_name(new_pri)], false)

func _on_unassign_specific_worker(citizen_id: int) -> void:
	var citizen: CitizenState = _find_citizen_by_id(citizen_id)
	if citizen != null:
		unassign_citizen(citizen)
		if ui != null:
			ui.show_toast("Citizen #%d unassigned" % citizen_id, false)

func _on_toggle_workforce_panel() -> void:
	if ui != null:
		ui.toggle_workforce_panel()
		if ui.is_workforce_panel_visible():
			_update_workforce_panel()

func _on_auto_staffing_toggled(enabled: bool) -> void:
	auto_staffing_enabled = enabled
	if ui != null:
		ui.show_toast("Auto-Staffing %s" % ("Enabled" if auto_staffing_enabled else "Disabled"), false)
	if auto_staffing_enabled:
		auto_staff_workplaces()
	_update_workforce_panel()

func _on_citizen_selected_from_panel(citizen_id: int) -> void:
	var c: CitizenState = _find_citizen_by_id(citizen_id)
	if c == null:
		return
	selected_citizen = c
	selected_building = null
	selected_units.clear()
	if renderer != null:
		renderer.selected_building = null
		renderer.selected_units = selected_units
		renderer.queue_redraw()
	_update_citizen_inspector()
	if camera != null:
		camera.position = Vector2(c.position_tile.x * 16.0, c.position_tile.y * 16.0)

func get_workforce_summary() -> Dictionary:
	var total: int = citizens.size()
	var employed: int = 0
	var unassigned: int = 0
	var travelling: int = 0
	var working: int = 0
	var hauling: int = 0
	var resting: int = 0
	var blocked: int = 0
	var builders: int = 0

	for c in citizens:
		if c.is_resting:
			resting += 1
		if c.current_block_reason != &"":
			blocked += 1
		if c.role_id == &"builder":
			builders += 1
		elif c.role_id == &"hauler":
			hauling += 1

		if c.workplace_id > 0 or c.role_id == &"hauler":
			employed += 1
		elif c.role_id == &"unassigned":
			unassigned += 1

		if not c.is_resting and c.workplace_id > 0 and c.role_id != &"hauler":
			var wp: BuildingState = _find_building_by_entity_id(c.workplace_id)
			if wp != null and _is_adjacent_to_building(c.position_tile, wp, wp.get_footprint()) and c.move_state == CitizenState.MoveState.IDLE:
				working += 1
			elif c.move_state == CitizenState.MoveState.MOVING:
				travelling += 1

	return {
		"total": total,
		"employed": employed,
		"unassigned": unassigned,
		"travelling": travelling,
		"working": working,
		"hauling": hauling,
		"resting": resting,
		"blocked": blocked,
		"builders": builders
	}

func get_workforce_citizens_data() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for c in citizens:
		var wp: BuildingState = _find_building_by_entity_id(c.workplace_id) if c.workplace_id > 0 else null
		var wp_str: String = "None"
		if wp != null:
			var wp_def = BuildingCatalog.get_all_defs().get(wp.definition_id, {})
			wp_str = "%s (#%d)" % [wp_def.get("display_name", str(wp.definition_id)), wp.entity_id]
		elif c.role_id == &"hauler":
			wp_str = "Logistics"

		var is_working: bool = false
		var is_travelling: bool = false
		if not c.is_resting and wp != null and c.role_id != &"hauler":
			if _is_adjacent_to_building(c.position_tile, wp, wp.get_footprint()) and c.move_state == CitizenState.MoveState.IDLE:
				is_working = true
			elif c.move_state == CitizenState.MoveState.MOVING:
				is_travelling = true

		var state_str: String = "Idle"
		if c.is_resting:
			state_str = "Resting"
		elif c.current_block_reason != &"":
			state_str = "Blocked"
		elif is_working:
			state_str = "Working"
		elif is_travelling:
			state_str = "Travelling"
		elif c.role_id == &"hauler":
			state_str = "Hauling" if c.carried_amount > 0 else "Hauler Idle"

		var prim_skill: StringName = &"farming"
		if wp != null:
			prim_skill = &"masonry" if wp.is_under_construction() else ProductionSystem.get_relevant_skill(wp.definition_id)
		elif c.role_id == &"hauler":
			prim_skill = &"hauling"
		else:
			var best_s: StringName = CitizenState.SKILL_NAMES[0]
			var best_v: float = -1.0
			for s in CitizenState.SKILL_NAMES:
				var v = c.get_skill(s)
				if v > best_v:
					best_v = v
					best_s = s
			prim_skill = best_s

		list.append({
			"id": c.id,
			"species_id": c.species_id,
			"species_name": SpeciesCatalog.get_display_name(c.species_id),
			"social_status_id": c.social_status_id,
			"social_status_name": SocialClassCatalog.get_display_name(c.social_status_id),
			"culture_id": c.culture_id,
			"culture_name": CultureCatalog.get_display_name(c.culture_id),
			"religion_id": c.religion_id,
			"religion_name": ReligionCatalog.get_display_name(c.religion_id),
			"doctrine_id": c.doctrine_id,
			"doctrine_name": DoctrineCatalog.get_display_name(c.doctrine_id),
			"active_belief_conflict": c.get_active_belief_conflict(government),
			"role": c.role_id,
			"workplace_id": c.workplace_id,
			"workplace_str": wp_str,
			"is_working": is_working,
			"is_travelling": is_travelling,
			"is_resting": c.is_resting,
			"is_blocked": c.current_block_reason != &"",
			"state_str": state_str,
			"energy": int(roundf(c.energy)),
			"primary_skill_name": prim_skill,
			"primary_skill_val": int(roundf(c.get_skill(prim_skill)))
		})
	return list

func get_assigned_citizens_for_building(building: BuildingState) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if building == null:
		return list
	var relevant_skill: StringName = &"masonry" if building.is_under_construction() else ProductionSystem.get_relevant_skill(building.definition_id)
	for c in citizens:
		if c.workplace_id == building.entity_id:
			var is_at_work: bool = not c.is_resting and _is_adjacent_to_building(c.position_tile, building, building.get_footprint()) and c.move_state == CitizenState.MoveState.IDLE
			var state_str: String = "At Work" if is_at_work else ("Travelling" if c.move_state == CitizenState.MoveState.MOVING else ("Resting" if c.is_resting else "Idle"))
			if c.current_block_reason != &"":
				state_str = "Blocked"
			var s_val: int = int(roundf(c.get_skill(relevant_skill))) if relevant_skill != &"" else 50
			var s_fac: float = c.get_skill_factor(relevant_skill) if relevant_skill != &"" else 1.0
			list.append({
				"id": c.id,
				"species_id": c.species_id,
				"species_name": SpeciesCatalog.get_display_name(c.species_id),
				"social_status_id": c.social_status_id,
				"social_status_name": SocialClassCatalog.get_display_name(c.social_status_id),
				"culture_id": c.culture_id,
				"culture_name": CultureCatalog.get_display_name(c.culture_id),
				"religion_id": c.religion_id,
				"religion_name": ReligionCatalog.get_display_name(c.religion_id),
				"doctrine_id": c.doctrine_id,
				"doctrine_name": DoctrineCatalog.get_display_name(c.doctrine_id),
				"active_belief_conflict": c.get_active_belief_conflict(government),
				"role": c.role_id,
				"state_str": state_str,
				"skill_name": relevant_skill,
				"skill_val": s_val,
				"skill_factor": s_fac
			})
	return list

func spawn_citizen(
	pos: Vector2i,
	role: StringName = &"unassigned",
	species: StringName = &"",
	status: StringName = &"",
	culture: StringName = &"",
	religion: StringName = &"",
	doctrine: StringName = &""
) -> CitizenState:
	var s_id: StringName = SpeciesCatalog.validate_species_id(species) if species != &"" else SpeciesCatalog.DEFAULT_SPECIES_ID
	var st_id: StringName = SocialClassCatalog.validate_status_id(status) if status != &"" else SocialClassCatalog.DEFAULT_STATUS_ID
	var c_id: StringName = CultureCatalog.validate_culture_id(culture) if culture != &"" else CultureCatalog.DEFAULT_CULTURE_ID
	var r_id: StringName = ReligionCatalog.validate_religion_id(religion) if religion != &"" else ReligionCatalog.DEFAULT_RELIGION_ID
	var d_id: StringName = DoctrineCatalog.validate_doctrine_id(doctrine) if doctrine != &"" else CultureCatalog.get_default_doctrine(c_id)
	var citizen: CitizenState = CitizenState.new(next_entity_id, pos, role, s_id, st_id, c_id, r_id, d_id)
	next_entity_id += 1
	citizens.append(citizen)
	return citizen

func spawn_citizen_with_distribution(pos: Vector2i, role: StringName = &"unassigned", rng_seed: int = 0, status: StringName = &"", culture: StringName = &"") -> CitizenState:
	var s_ids: Array[StringName] = SpeciesCatalog.SPECIES_IDS
	var pick_idx: int = absi(rng_seed) % s_ids.size()
	var s_id: StringName = s_ids[pick_idx]
	return spawn_citizen(pos, role, s_id, status, culture)

func unassign_citizen(citizen: CitizenState) -> void:
	if citizen == null or citizen.workplace_id <= 0:
		return
	var wp: BuildingState = _find_building_by_entity_id(citizen.workplace_id)
	if wp != null:
		wp.assigned_workers = maxi(0, wp.assigned_workers - 1)
	citizen.workplace_id = 0
	citizen.role_id = &"unassigned"
	citizen.path.clear()
	citizen.move_state = CitizenState.MoveState.IDLE
	citizen.target_tile = citizen.position_tile
	if selected_building != null and selected_building == wp:
		_update_building_inspector()
	_update_workforce_panel()
	if renderer != null:
		renderer.queue_redraw()

func set_building_priority(building: BuildingState, new_priority: int) -> void:
	if building == null:
		return
	building.work_priority = clampi(new_priority, BuildingState.PRIORITY_MIN, BuildingState.PRIORITY_MAX)
	if selected_building == building:
		_update_building_inspector()

func auto_staff_workplaces() -> void:
	var candidate_workplaces: Array[BuildingState] = []
	for b in buildings:
		if b.is_under_construction():
			if b.has_all_construction_materials() and b.assigned_workers < 3:
				candidate_workplaces.append(b)
		elif b.status == BuildingState.Status.ACTIVE:
			var max_slots: int = BuildingCatalog.get_worker_slots_for_footprint(b.definition_id, b.get_footprint())
			if b.assigned_workers < max_slots:
				candidate_workplaces.append(b)

	if candidate_workplaces.is_empty():
		return

	candidate_workplaces.sort_custom(func(a: BuildingState, b: BuildingState) -> bool:
		if a.work_priority != b.work_priority:
			return a.work_priority > b.work_priority
		var a_max: float = 3.0 if a.is_under_construction() else float(BuildingCatalog.get_worker_slots_for_footprint(a.definition_id, a.get_footprint()))
		var b_max: float = 3.0 if b.is_under_construction() else float(BuildingCatalog.get_worker_slots_for_footprint(b.definition_id, b.get_footprint()))
		var a_ratio: float = float(a.assigned_workers) / maxf(1.0, a_max)
		var b_ratio: float = float(b.assigned_workers) / maxf(1.0, b_max)
		if not is_equal_approx(a_ratio, b_ratio):
			return a_ratio < b_ratio
		return a.entity_id < b.entity_id
	)

	for workplace in candidate_workplaces:
		var max_slots: int = 3 if workplace.is_under_construction() else BuildingCatalog.get_worker_slots_for_footprint(workplace.definition_id, workplace.get_footprint())
		var needed: int = max_slots - workplace.assigned_workers
		if needed <= 0:
			continue

		var relevant_skill: StringName = &"masonry" if workplace.is_under_construction() else ProductionSystem.get_relevant_skill(workplace.definition_id)

		for _i in range(needed):
			var best_citizen: CitizenState = null
			var best_score: float = -999999.0

			for citizen in citizens:
				if citizen.role_id != &"unassigned" or citizen.workplace_id > 0 or citizen.is_resting:
					continue
				if workplace.definition_id == &"town_hall" and not (citizen.social_status_id in [&"administrator", &"noble", &"scholar"]):
					continue
				var s_fac: float = citizen.get_skill_factor(relevant_skill) if relevant_skill != &"" else 1.0
				var eff_skill: float = s_fac * 100.0
				var dist: float = float(absi(citizen.position_tile.x - workplace.tile_origin.x) + absi(citizen.position_tile.y - workplace.tile_origin.y))
				var score: float = eff_skill * 10.0 - dist
				if score > best_score:
					best_score = score
					best_citizen = citizen

			if best_citizen == null:
				break

			workplace.assigned_workers += 1
			best_citizen.workplace_id = workplace.entity_id
			best_citizen.role_id = &"builder" if workplace.is_under_construction() else _worker_role_for_building(workplace.definition_id)
			best_citizen.path.clear()
			best_citizen.move_state = CitizenState.MoveState.MOVING

func get_building_production_chain(building: BuildingState) -> Dictionary:
	if building == null:
		return {}

	var real_status: String = "ACTIVE"
	var primary_blocker: String = ""
	var secondary_blocker: String = ""
	var upstream_summary: String = ""
	var downstream_summary: String = ""

	if building.is_under_construction():
		real_status = "UNDER_CONSTRUCTION" if building.status == BuildingState.Status.UNDER_CONSTRUCTION else "PLANNED"
		if building.construction_block_reason != &"":
			primary_blocker = str(building.construction_block_reason)
		elif not building.has_all_construction_materials():
			primary_blocker = "WAITING_MATERIALS"
		elif building.assigned_workers == 0:
			primary_blocker = "NO_BUILDERS"
		elif _count_workers_at_building(building) == 0:
			primary_blocker = "WAITING_FOR_BUILDERS"

		var missing: Dictionary = building.get_outstanding_materials()
		for res_id in building.construction_cost:
			var req: int = building.construction_cost[res_id]
			var deliv: int = building.get_delivered_materials().get(res_id, 0)
			var in_transit: int = 0
			for job: HaulJob in job_board.jobs.values():
				if job.destination_inventory_id == building.construction_inventory.owner_id and job.resource_id == res_id and job.status in [HaulJob.Status.ASSIGNED, HaulJob.Status.IN_TRANSIT]:
					in_transit += job.amount
			upstream_summary += "    • %s: %d/%d delivered | In transit: %d | Missing: %d\n" % [
				str(res_id).capitalize(), deliv, req, in_transit, missing.get(res_id, 0)
			]

		return {
			"real_status": real_status,
			"primary_blocker": primary_blocker,
			"secondary_blocker": secondary_blocker,
			"upstream_summary": upstream_summary.strip_edges(),
			"downstream_summary": "Construction site does not produce outputs."
		}

	var def_info: Dictionary = BuildingCatalog.get_all_defs().get(building.definition_id, {})
	var recipe: RecipeDef = def_info.get("recipe", null)
	var max_slots: int = BuildingCatalog.get_worker_slots_for_footprint(building.definition_id, building.get_footprint())
	var workers_present: int = _count_workers_at_building(building)

	if building.current_block_reason != &"":
		primary_blocker = str(building.current_block_reason)
		real_status = "BLOCKED"
	elif building.assigned_workers == 0 and max_slots > 0:
		primary_blocker = "UNSTAFFED"
		real_status = "UNSTAFFED"
	elif workers_present == 0 and building.assigned_workers > 0:
		primary_blocker = "WAITING_FOR_WORKERS"
		real_status = "WAITING_FOR_WORKERS"
	elif recipe != null:
		real_status = "PRODUCING"

	for c in citizens:
		if c.workplace_id == building.entity_id and c.is_resting:
			secondary_blocker = "Worker resting at home"
			break

	if recipe != null and not recipe.inputs.is_empty():
		for in_res in recipe.inputs:
			var req: int = recipe.inputs[in_res]
			var have: int = building.inventory.get_quantity(in_res)
			var reserved_in: int = building.inventory.get_reserved_in(in_res)
			var in_transit: int = 0
			for job: HaulJob in job_board.jobs.values():
				if job.destination_inventory_id == building.inventory.owner_id and job.resource_id == in_res and job.status in [HaulJob.Status.ASSIGNED, HaulJob.Status.IN_TRANSIT]:
					in_transit += job.amount

			var supplier_info: String = "No supplier"
			for other_b in buildings:
				if other_b != building and other_b.status == BuildingState.Status.ACTIVE:
					var other_def = BuildingCatalog.get_all_defs().get(other_b.definition_id, {})
					var other_recipe: RecipeDef = other_def.get("recipe", null)
					if other_recipe != null and other_recipe.outputs.has(in_res):
						supplier_info = "%s (#%d): %d stored" % [other_def.get("display_name", str(other_b.definition_id)), other_b.entity_id, other_b.inventory.get_quantity(in_res)]
						break

			var input_state: String = "READY" if have >= req else ("IN_TRANSIT" if (in_transit > 0 or reserved_in > 0) else "WAITING_SUPPLY")
			upstream_summary += "    • %s: Stored: %d/%d (State: %s) | In transit: %d | Source: %s\n" % [
				str(in_res).capitalize(), have, req, input_state, in_transit, supplier_info
			]
	else:
		if def_info.has("harvest_deposit"):
			upstream_summary = "    • Resource Source: Natural %s deposit" % ("forest" if def_info["harvest_deposit"] == &"trees" else "rock")
		else:
			upstream_summary = "    • No raw inputs required"

	if recipe != null and not recipe.outputs.is_empty():
		for out_res in recipe.outputs:
			var have_out: int = building.inventory.get_quantity(out_res)
			var in_transit_out: int = 0
			for job: HaulJob in job_board.jobs.values():
				if job.source_inventory_id == building.inventory.owner_id and job.resource_id == out_res and job.status in [HaulJob.Status.ASSIGNED, HaulJob.Status.IN_TRANSIT]:
					in_transit_out += job.amount

			var consumer_info: String = "None"
			for other_b in buildings:
				if other_b != building and other_b.status == BuildingState.Status.ACTIVE:
					if other_b.inventory.accepts(out_res):
						var other_def = BuildingCatalog.get_all_defs().get(other_b.definition_id, {})
						consumer_info = "%s (#%d): %d free space" % [
							other_def.get("display_name", str(other_b.definition_id)),
							other_b.entity_id,
							other_b.inventory.get_free_capacity()
						]
						break

			var out_state: String = "FULL" if building.inventory.get_free_capacity() == 0 else ("HAULING" if in_transit_out > 0 else "STORING")
			downstream_summary += "    • %s: Stored: %d (State: %s) | Hauling away: %d | Consumer: %s\n" % [
				str(out_res).capitalize(), have_out, out_state, in_transit_out, consumer_info
			]
	else:
		downstream_summary = "    • Storage / Service building — receives incoming goods"

	return {
		"real_status": real_status,
		"primary_blocker": primary_blocker,
		"secondary_blocker": secondary_blocker,
		"upstream_summary": upstream_summary.strip_edges(),
		"downstream_summary": downstream_summary.strip_edges()
	}

func get_building_diagnostic_details(building: BuildingState) -> Dictionary:
	if building == null:
		return {}

	var max_slots: int = 3 if building.is_under_construction() else BuildingCatalog.get_worker_slots_for_footprint(building.definition_id, building.get_footprint())
	var slot_reason: String = ""
	if building.assigned_workers < max_slots:
		slot_reason = "%d open slot(s) (Priority %s — waiting for unassigned citizen)" % [
			max_slots - building.assigned_workers,
			BuildingState.get_priority_name(building.work_priority)
		]
	else:
		slot_reason = "All slots filled"

	var formatted_logs: Array[String] = []
	var raw_logs: Array = building.inventory.transaction_log
	var start_idx: int = maxi(0, raw_logs.size() - 4)
	for i in range(start_idx, raw_logs.size()):
		var entry = raw_logs[i]
		if entry is Dictionary:
			var sign_str: String = "+" if entry.get("type", "") == "ADD" else "-"
			formatted_logs.append("%s%d %s (%s)" % [
				sign_str,
				entry.get("amount", 0),
				str(entry.get("resource_id", "")).capitalize(),
				entry.get("reason", "")
			])

	return {
		"assigned_citizens": get_assigned_citizens_for_building(building),
		"open_slot_reason": slot_reason,
		"production_chain": get_building_production_chain(building),
		"recent_transactions": formatted_logs
	}

