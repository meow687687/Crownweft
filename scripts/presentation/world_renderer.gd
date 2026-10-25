class_name WorldRenderer
extends Node2D

const TILE_SIZE: float = 16.0

var world_state: WorldState = null
var buildings: Array[BuildingState] = []
var citizens: Array[CitizenState] = []
var active_jobs: Array[HaulJob] = []
var show_logistics_overlay: bool = false
var selected_building: BuildingState = null

func _draw() -> void:
	if world_state == null:
		return
		
	# Draw terrain
	_draw_terrain()
	
	# Draw buildings
	_draw_buildings()
	
	# Draw citizens
	_draw_citizens()
	
	# Draw logistics overlay
	if show_logistics_overlay:
		_draw_logistics_overlay()

func _draw_terrain() -> void:
	var grass_color: Color = Color(0.35, 0.65, 0.3)
	var forest_color: Color = Color(0.18, 0.45, 0.2)
	var rock_color: Color = Color(0.5, 0.52, 0.55)
	var water_color: Color = Color(0.25, 0.48, 0.78)
	var road_color: Color = Color(0.68, 0.54, 0.38)
	
	for y in range(world_state.height):
		for x in range(world_state.width):
			var tile: WorldTile = world_state.get_tile(Vector2i(x, y))
			if tile == null:
				continue
				
			var rect: Rect2 = Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var col: Color = grass_color
			
			match tile.terrain_id:
				&"water":
					col = water_color
				&"rock":
					col = rock_color
				&"forest":
					col = forest_color
				_:
					col = grass_color
					
			draw_rect(rect, col)
			
			if tile.road_level > 0:
				var road_rect: Rect2 = Rect2(float(x) * TILE_SIZE + 2.0, float(y) * TILE_SIZE + 2.0, TILE_SIZE - 4.0, TILE_SIZE - 4.0)
				draw_rect(road_rect, road_color)

func _draw_buildings() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for b in buildings:
		var def_data: Dictionary = defs.get(b.definition_id, {})
		var footprint: Vector2i = def_data.get("footprint", Vector2i(2, 2))
		var col: Color = def_data.get("color", Color.WHITE)
		
		var b_pos: Vector2 = Vector2(b.tile_origin.x * TILE_SIZE, b.tile_origin.y * TILE_SIZE)
		var b_size: Vector2 = Vector2(footprint.x * TILE_SIZE, footprint.y * TILE_SIZE)
		var b_rect: Rect2 = Rect2(b_pos, b_size)
		
		draw_rect(b_rect, col)
		draw_rect(b_rect, Color.BLACK, false, 1.0)
		
		# Selection border
		if b == selected_building:
			draw_rect(b_rect.grow(2.0), Color(1.0, 0.9, 0.2), false, 2.0)
			
		# Status indicator dot
		if b.current_block_reason != &"":
			var warn_pos: Vector2 = b_pos + Vector2(b_size.x - 4.0, 4.0)
			draw_circle(warn_pos, 3.0, Color.RED)

func _draw_citizens() -> void:
	for c in citizens:
		var c_pos: Vector2 = Vector2(c.position_tile.x * TILE_SIZE + TILE_SIZE * 0.5, c.position_tile.y * TILE_SIZE + TILE_SIZE * 0.5)
		var col: Color = Color.WHITE
		if c.role_id == &"hauler":
			col = Color(0.9, 0.7, 0.1) # Gold hauler
		elif c.role_id == &"farmer":
			col = Color(0.4, 0.8, 0.3)
		elif c.food_state == CitizenState.FoodState.HUNGRY:
			col = Color.ORANGE
		elif c.food_state == CitizenState.FoodState.AT_RISK:
			col = Color.RED
			
		draw_circle(c_pos, 3.5, col)
		draw_circle(c_pos, 3.5, Color.BLACK, false, 0.8)
		
		if c.carried_amount > 0:
			draw_rect(Rect2(c_pos + Vector2(2, -4), Vector2(4, 4)), Color.YELLOW)

func _draw_logistics_overlay() -> void:
	for job in active_jobs:
		# Draw vector line between source and destination buildings
		var src_b: BuildingState = _find_building_by_inv_id(job.source_inventory_id)
		var dst_b: BuildingState = _find_building_by_inv_id(job.destination_inventory_id)
		if src_b != null and dst_b != null:
			var p1: Vector2 = Vector2(src_b.tile_origin.x * TILE_SIZE + 8.0, src_b.tile_origin.y * TILE_SIZE + 8.0)
			var p2: Vector2 = Vector2(dst_b.tile_origin.x * TILE_SIZE + 8.0, dst_b.tile_origin.y * TILE_SIZE + 8.0)
			var line_col: Color = Color(0.2, 0.8, 1.0, 0.7) # Cyan haul line
			if job.status == HaulJob.Status.BLOCKED or job.status == HaulJob.Status.CANCELLED:
				line_col = Color(1.0, 0.2, 0.2, 0.8)
			draw_line(p1, p2, line_col, 1.5)

func _find_building_by_inv_id(inv_id: int) -> BuildingState:
	for b in buildings:
		if b.inventory.owner_id == inv_id:
			return b
	return null
