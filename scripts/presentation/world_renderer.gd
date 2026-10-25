class_name WorldRenderer
extends Node2D

const TILE_SIZE: float = 16.0

var world_state: WorldState = null
var buildings: Array[BuildingState] = []
var citizens: Array[CitizenState] = []
var military_units: Array[MilitaryUnitState] = []
var selected_units: Array[MilitaryUnitState] = []
var active_jobs: Array[HaulJob] = []
var show_logistics_overlay: bool = false
var selected_building: BuildingState = null

# Building Placement Ghost
var active_build_id: StringName = &""
var hover_tile: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false

func _draw() -> void:
	if world_state == null:
		return
		
	# 1. Terrain Layer
	_draw_terrain()
	
	# 2. Roads Layer
	_draw_roads()
	
	# 3. Buildings Layer
	_draw_buildings()
	
	# 4. Logistics Overlay
	if show_logistics_overlay:
		_draw_logistics_overlay()
		
	# 5. Citizens Layer
	_draw_citizens()
	
	# 6. Military Units Layer
	_draw_military_units()
	
	# 7. Building Placement Ghost (Topmost preview)
	if active_build_id != &"" and hover_tile.x >= 0 and hover_tile.y >= 0:
		_draw_build_ghost()

func _draw_terrain() -> void:
	var grass_color: Color = Color(0.32, 0.58, 0.28)
	var forest_color: Color = Color(0.16, 0.38, 0.18)
	var rock_color: Color = Color(0.48, 0.50, 0.54)
	var water_color: Color = Color(0.22, 0.45, 0.75)
	var grid_line_color: Color = Color(0.0, 0.0, 0.0, 0.06)
	
	for y in range(world_state.height):
		for x in range(world_state.width):
			var tile: WorldTile = world_state.get_tile(Vector2i(x, y))
			if tile == null:
				continue
				
			var rect: Rect2 = Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			
			match tile.terrain_id:
				&"water":
					draw_rect(rect, water_color)
					# Subtle wave highlight
					draw_line(rect.position + Vector2(2, 6), rect.position + Vector2(8, 6), Color(0.4, 0.65, 0.9, 0.6), 1.0)
					draw_line(rect.position + Vector2(6, 12), rect.position + Vector2(13, 12), Color(0.4, 0.65, 0.9, 0.6), 1.0)
				&"rock":
					draw_rect(rect, rock_color)
					# Rock boulders
					draw_circle(rect.position + Vector2(8, 8), 5.0, Color(0.38, 0.40, 0.44))
					draw_circle(rect.position + Vector2(12, 11), 3.0, Color(0.32, 0.34, 0.38))
				&"forest":
					draw_rect(rect, forest_color)
					# Tree canopies
					draw_circle(rect.position + Vector2(8, 8), 6.0, Color(0.12, 0.30, 0.14))
					draw_circle(rect.position + Vector2(6, 6), 4.5, Color(0.18, 0.44, 0.20))
				_:
					# Grass meadow
					draw_rect(rect, grass_color)
					# Subtle fertility variation
					if tile.fertility > 0.65:
						draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(2, 2)), Color(0.38, 0.68, 0.32, 0.7))
						
			# Soft tile grid border
			draw_rect(rect, grid_line_color, false, 0.5)

func _draw_roads() -> void:
	var road_color: Color = Color(0.70, 0.58, 0.40)
	var road_border: Color = Color(0.50, 0.40, 0.26)
	
	for y in range(world_state.height):
		for x in range(world_state.width):
			var tile: WorldTile = world_state.get_tile(Vector2i(x, y))
			if tile != null and tile.road_level > 0:
				var rect: Rect2 = Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				draw_rect(rect.grow(-1.0), road_color)
				draw_rect(rect.grow(-1.0), road_border, false, 1.0)

func _draw_buildings() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for b in buildings:
		var def_data: Dictionary = defs.get(b.definition_id, {})
		var footprint: Vector2i = def_data.get("footprint", Vector2i(2, 2))
		var base_col: Color = def_data.get("color", Color.WHITE)
		
		var b_pos: Vector2 = Vector2(b.tile_origin.x * TILE_SIZE, b.tile_origin.y * TILE_SIZE)
		var b_size: Vector2 = Vector2(footprint.x * TILE_SIZE, footprint.y * TILE_SIZE)
		var b_rect: Rect2 = Rect2(b_pos, b_size)
		
		# Building base structure with shadow
		draw_rect(Rect2(b_pos + Vector2(2, 2), b_size), Color(0, 0, 0, 0.3)) # Shadow
		draw_rect(b_rect, base_col)
		draw_rect(b_rect, Color(0.15, 0.15, 0.18), false, 1.5) # Dark trim
		
		# Roof accent / Door
		var door_w: float = 6.0
		var door_h: float = 8.0
		var door_pos: Vector2 = b_pos + Vector2(b_size.x * 0.5 - door_w * 0.5, b_size.y - door_h)
		draw_rect(Rect2(door_pos, Vector2(door_w, door_h)), Color(0.2, 0.15, 0.1))
		
		# Building Name Abbreviation
		var abbrev: String = str(b.definition_id).substr(0, 4).to_upper()
		draw_string(ThemeDB.fallback_font, b_pos + Vector2(4, 12), abbrev, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		
		# Selection glow
		if b == selected_building:
			draw_rect(b_rect.grow(3.0), Color(1.0, 0.85, 0.2), false, 2.5)
			
		# Status indicator badge
		if b.current_block_reason != &"":
			var warn_pos: Vector2 = b_pos + Vector2(b_size.x - 6.0, 6.0)
			draw_circle(warn_pos, 4.5, Color.RED)
			draw_circle(warn_pos, 4.5, Color.WHITE, false, 1.0)
		elif b.assigned_workers > 0 and def_data.has("recipe"):
			var active_pos: Vector2 = b_pos + Vector2(b_size.x - 6.0, 6.0)
			draw_circle(active_pos, 3.5, Color(0.2, 0.9, 0.3))

func _draw_build_ghost() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(active_build_id, {})
	var footprint: Vector2i = def_info.get("footprint", Vector2i(1, 1))
	
	var ghost_pos: Vector2 = Vector2(hover_tile.x * TILE_SIZE, hover_tile.y * TILE_SIZE)
	var ghost_size: Vector2 = Vector2(footprint.x * TILE_SIZE, footprint.y * TILE_SIZE)
	var ghost_rect: Rect2 = Rect2(ghost_pos, ghost_size)
	
	var fill_color: Color = Color(0.2, 0.85, 0.3, 0.45) if is_hover_valid else Color(0.9, 0.2, 0.2, 0.45)
	var outline_color: Color = Color(0.2, 1.0, 0.3) if is_hover_valid else Color(1.0, 0.2, 0.2)
	
	draw_rect(ghost_rect, fill_color)
	draw_rect(ghost_rect, outline_color, false, 2.0)
	
	# Draw footprint grid markers
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var sub_pos: Vector2 = ghost_pos + Vector2(dx * TILE_SIZE, dy * TILE_SIZE)
			draw_rect(Rect2(sub_pos, Vector2(TILE_SIZE, TILE_SIZE)), outline_color, false, 0.8)

func _draw_citizens() -> void:
	for c in citizens:
		var c_pos: Vector2 = Vector2(c.position_tile.x * TILE_SIZE + TILE_SIZE * 0.5, c.position_tile.y * TILE_SIZE + TILE_SIZE * 0.5)
		
		# Shadow
		draw_circle(c_pos + Vector2(0, 2), 4.0, Color(0, 0, 0, 0.35))
		
		# Citizen Body
		var col: Color = Color(0.85, 0.85, 0.9)
		if c.role_id == &"hauler":
			col = Color(0.95, 0.75, 0.15) # Gold hauler
		elif c.role_id == &"farmer":
			col = Color(0.4, 0.8, 0.3)
		elif c.food_state == CitizenState.FoodState.HUNGRY:
			col = Color.ORANGE
		elif c.food_state == CitizenState.FoodState.AT_RISK:
			col = Color.RED
			
		draw_circle(c_pos, 4.0, col)
		draw_circle(c_pos, 4.0, Color(0.15, 0.15, 0.15), false, 1.0)
		
		# Carried Goods Crate
		if c.carried_amount > 0:
			var crate_rect: Rect2 = Rect2(c_pos + Vector2(2, -6), Vector2(6, 6))
			draw_rect(crate_rect, Color(0.85, 0.65, 0.2))
			draw_rect(crate_rect, Color.BLACK, false, 1.0)

func _draw_military_units() -> void:
	var defs: Dictionary = UnitDef.get_all_defs()
	for u in military_units:
		if u.is_dead:
			continue
			
		var def: UnitDef = defs.get(u.unit_definition_id, null)
		var col: Color = def.unit_color if def != null else Color.WHITE
		
		# Shadow
		draw_circle(u.position + Vector2(0, 3), 6.0, Color(0, 0, 0, 0.4))
		
		# Unit circle
		draw_circle(u.position, 6.5, col)
		draw_circle(u.position, 6.5, Color.BLACK, false, 1.5)
		
		# Starving indicator (cross)
		if u.is_starving:
			draw_circle(u.position, 3.0, Color.ORANGE_RED)
			
		# Selection ring
		if u in selected_units:
			draw_circle(u.position, 10.0, Color(1.0, 0.9, 0.2), false, 2.0)
			
		# Health bar
		if u.health < u.max_health:
			var bar_w: float = 16.0
			var bar_h: float = 3.5
			var bar_pos: Vector2 = u.position + Vector2(-bar_w * 0.5, -13.0)
			var health_ratio: float = clampf(float(u.health) / float(u.max_health), 0.0, 1.0)
			
			draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.2, 0.2, 0.2))
			draw_rect(Rect2(bar_pos, Vector2(bar_w * health_ratio, bar_h)), Color(0.2, 0.9, 0.2))

func _draw_logistics_overlay() -> void:
	for job in active_jobs:
		var src_b: BuildingState = _find_building_by_inv_id(job.source_inventory_id)
		var dst_b: BuildingState = _find_building_by_inv_id(job.destination_inventory_id)
		if src_b != null and dst_b != null:
			var p1: Vector2 = Vector2(src_b.tile_origin.x * TILE_SIZE + 16.0, src_b.tile_origin.y * TILE_SIZE + 16.0)
			var p2: Vector2 = Vector2(dst_b.tile_origin.x * TILE_SIZE + 16.0, dst_b.tile_origin.y * TILE_SIZE + 16.0)
			var line_col: Color = Color(0.2, 0.85, 1.0, 0.8)
			if job.status == HaulJob.Status.BLOCKED or job.status == HaulJob.Status.CANCELLED:
				line_col = Color(1.0, 0.2, 0.2, 0.9)
			draw_line(p1, p2, line_col, 2.0)
			draw_circle(p1, 3.0, line_col)
			draw_circle(p2, 3.0, line_col)

func _find_building_by_inv_id(inv_id: int) -> BuildingState:
	for b in buildings:
		if b.inventory.owner_id == inv_id:
			return b
	return null
