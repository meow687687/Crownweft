class_name WorldRenderer
extends Node2D

const RoadAutotiler = preload("res://scripts/presentation/road_autotiler.gd")

const TILE_SIZE: float = 16.0

# Small hand-authored pixel sprites; nearest-neighbour filtering preserves their pixels.
const TEX_GRASS_A = preload("res://assets/pixel/tiles/grass_a.png")
const TEX_GRASS_B = preload("res://assets/pixel/tiles/grass_b.png")
const TEX_FOREST_A = preload("res://assets/pixel/tiles/forest_a.png")
const TEX_FOREST_B = preload("res://assets/pixel/tiles/forest_b.png")
const TEX_ROCK = preload("res://assets/pixel/tiles/rock.png")
const TEX_WATER = preload("res://assets/pixel/tiles/water.png")
const TEX_ROAD = preload("res://assets/pixel/tiles/road.png")
const TEX_TOWN_HALL = preload("res://assets/pixel/buildings/town_hall.png")
const TEX_HOUSE = preload("res://assets/pixel/buildings/house.png")
const TEX_FARM = preload("res://assets/pixel/buildings/farm.png")
const TEX_WOODCUTTER = preload("res://assets/pixel/buildings/woodcutter.png")
const TEX_QUARRY = preload("res://assets/pixel/buildings/quarry.png")
const TEX_BAKERY = preload("res://assets/pixel/buildings/bakery.png")
const TEX_STOREHOUSE = preload("res://assets/pixel/buildings/storehouse.png")
const TEX_BARRACKS = preload("res://assets/pixel/buildings/barracks.png")
const TEX_CITIZEN = preload("res://assets/pixel/units/citizen.png")
const TEX_HAULER = preload("res://assets/pixel/units/hauler.png")
const TEX_FARMER = preload("res://assets/pixel/units/farmer.png")
const TEX_SPEARMAN = preload("res://assets/pixel/units/spearman.png")
const TEX_ARCHER = preload("res://assets/pixel/units/archer.png")
const TEX_RAIDER = preload("res://assets/pixel/units/raider.png")

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
var hover_footprint: Vector2i = Vector2i.ZERO
var is_hover_valid: bool = false
var _redraw_accumulator: float = 0.0
const VISUAL_REFRESH_INTERVAL: float = 1.0 / 30.0
var _terrain_cache: Texture2D = null
var _road_cache: ImageTexture = null
var _road_image_cache: Image = null
var _terrain_cache_world: WorldState = null
var _road_cache_world: WorldState = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func _process(delta: float) -> void:
	# Combat motion advances every frame; redraw at a capped visual rate instead
	# of only redrawing on the slower economic tick (which made troops stutter).
	_redraw_accumulator += delta
	if _redraw_accumulator >= VISUAL_REFRESH_INTERVAL:
		_redraw_accumulator = fmod(_redraw_accumulator, VISUAL_REFRESH_INTERVAL)
		queue_redraw()

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

func invalidate_world_visuals() -> void:
	_terrain_cache = null
	_road_cache = null
	_road_image_cache = null
	_terrain_cache_world = null
	_road_cache_world = null
	queue_redraw()

func _draw_terrain() -> void:
	if _terrain_cache == null or _terrain_cache_world != world_state:
		_rebuild_terrain_cache()
	if _terrain_cache != null:
		draw_texture_rect(
			_terrain_cache,
			Rect2(Vector2.ZERO, Vector2(world_state.width * TILE_SIZE, world_state.height * TILE_SIZE)),
			false
		)

func _rebuild_terrain_cache() -> void:
	var terrain_image: Image = Image.create(world_state.width * int(TILE_SIZE), world_state.height * int(TILE_SIZE), false, Image.FORMAT_RGBA8)
	var tile_images: Dictionary = {
		&"grass_a": TEX_GRASS_A.get_image(),
		&"grass_b": TEX_GRASS_B.get_image(),
		&"forest_a": TEX_FOREST_A.get_image(),
		&"forest_b": TEX_FOREST_B.get_image(),
		&"rock": TEX_ROCK.get_image(),
		&"water": TEX_WATER.get_image()
	}
	for y in range(world_state.height):
		for x in range(world_state.width):
			var tile: WorldTile = world_state.get_tile(Vector2i(x, y))
			if tile == null:
				continue
			var sprite_key: StringName = &"grass_a"
			match tile.terrain_id:
				&"water":
					sprite_key = &"water"
				&"rock":
					sprite_key = &"rock"
				&"forest":
					sprite_key = &"forest_a" if ((x + y + world_state.seed_val) % 2 == 0) else &"forest_b"
				_:
					sprite_key = &"grass_a" if ((x * 3 + y + world_state.seed_val) % 3 != 0) else &"grass_b"
			var sprite_image: Image = tile_images[sprite_key]
			terrain_image.blit_rect(
				sprite_image,
				Rect2i(Vector2i.ZERO, sprite_image.get_size()),
				Vector2i(x * int(TILE_SIZE), y * int(TILE_SIZE))
			)
	_terrain_cache = ImageTexture.create_from_image(terrain_image)
	_terrain_cache_world = world_state

func _draw_roads() -> void:
	if _road_cache == null or _road_cache_world != world_state:
		_rebuild_road_cache()
	if _road_cache != null:
		draw_texture_rect(
			_road_cache,
			Rect2(Vector2.ZERO, Vector2(world_state.width * TILE_SIZE, world_state.height * TILE_SIZE)),
			false
		)

func _rebuild_road_cache() -> void:
	if world_state == null:
		return
	_road_image_cache = Image.create(world_state.width * int(TILE_SIZE), world_state.height * int(TILE_SIZE), false, Image.FORMAT_RGBA8)
	_road_image_cache.fill(Color(0, 0, 0, 0))
	for y in range(world_state.height):
		for x in range(world_state.width):
			var c := Vector2i(x, y)
			if RoadAutotiler.has_road(world_state, c):
				var mask: int = RoadAutotiler.get_road_mask(world_state, c)
				var tile_img: Image = RoadAutotiler.get_variant_image(mask)
				_road_image_cache.blit_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), Vector2i(x * int(TILE_SIZE), y * int(TILE_SIZE)))
	_road_cache = ImageTexture.create_from_image(_road_image_cache)
	_road_cache_world = world_state

func refresh_road_cells(affected_coords: Array[Vector2i]) -> void:
	if world_state == null:
		return
	if _road_cache == null or _road_cache_world != world_state or _road_image_cache == null:
		_rebuild_road_cache()
		queue_redraw()
		return
		
	var tile_rect := Rect2i(Vector2i.ZERO, Vector2i(int(TILE_SIZE), int(TILE_SIZE)))
	for coord in affected_coords:
		if not world_state.is_valid_coord(coord):
			continue
		var dst_pos := Vector2i(coord.x * int(TILE_SIZE), coord.y * int(TILE_SIZE))
		if RoadAutotiler.has_road(world_state, coord):
			var mask: int = RoadAutotiler.get_road_mask(world_state, coord)
			var tile_img: Image = RoadAutotiler.get_variant_image(mask)
			_road_image_cache.fill_rect(Rect2i(dst_pos, Vector2i(int(TILE_SIZE), int(TILE_SIZE))), Color(0, 0, 0, 0))
			_road_image_cache.blit_rect(tile_img, tile_rect, dst_pos)
		else:
			_road_image_cache.fill_rect(Rect2i(dst_pos, Vector2i(int(TILE_SIZE), int(TILE_SIZE))), Color(0, 0, 0, 0))
			
	_road_cache.update(_road_image_cache)
	queue_redraw()

func _draw_buildings() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	for building: BuildingState in buildings:
		var def_data: Dictionary = defs.get(building.definition_id, {})
		var footprint: Vector2i = building.get_footprint()
		var b_pos: Vector2 = Vector2(building.tile_origin.x * TILE_SIZE, building.tile_origin.y * TILE_SIZE)
		var b_size: Vector2 = Vector2(footprint.x * TILE_SIZE, footprint.y * TILE_SIZE)
		var b_rect: Rect2 = Rect2(b_pos, b_size)
		var texture: Texture2D = _building_texture(building.definition_id)
		
		if building.is_under_construction():
			# Foundation / earth floor
			draw_rect(b_rect, Color(0.24, 0.21, 0.18, 0.85))
			if texture != null:
				draw_texture_rect(texture, b_rect, false, Color(1.0, 1.0, 1.0, 0.35))
			# Scaffolding cross-beams
			draw_line(b_pos, b_pos + b_size, Color(0.85, 0.7, 0.25, 0.45), 1.0)
			draw_line(Vector2(b_pos.x, b_pos.y + b_size.y), Vector2(b_pos.x + b_size.x, b_pos.y), Color(0.85, 0.7, 0.25, 0.45), 1.0)
			draw_rect(b_rect, Color(0.9, 0.75, 0.2, 0.85), false, 1.5)
			
			# Construction progress bar at bottom of footprint
			var bar_w: float = b_size.x - 4.0
			var bar_pos: Vector2 = b_pos + Vector2(2.0, b_size.y - 5.0)
			draw_rect(Rect2(bar_pos, Vector2(bar_w, 3.0)), Color(0.12, 0.12, 0.14, 0.9))
			if building.construction_progress > 0.0:
				draw_rect(Rect2(bar_pos, Vector2(bar_w * building.construction_progress, 3.0)), Color(0.95, 0.78, 0.24))
		else:
			if texture != null:
				draw_texture_rect(texture, b_rect, false)
			else:
				# Safe fallback for future building definitions without a sprite yet.
				var base_col: Color = def_data.get("color", Color.WHITE)
				draw_rect(Rect2(b_pos + Vector2(2, 2), b_size), Color(0, 0, 0, 0.3))
				draw_rect(b_rect, base_col)
				draw_rect(b_rect, Color(0.15, 0.15, 0.18), false, 1.0)

		if building == selected_building:
			draw_rect(b_rect.grow(2.0), Color(1.0, 0.82, 0.28), false, 1.0)
		if building.is_under_construction():
			if building.construction_block_reason != &"":
				draw_rect(Rect2(b_pos + Vector2(b_size.x - 6.0, 2.0), Vector2(4, 4)), Color("#e8a838"))
			elif building.status == BuildingState.Status.UNDER_CONSTRUCTION:
				draw_rect(Rect2(b_pos + Vector2(b_size.x - 6.0, 2.0), Vector2(4, 4)), Color("#7bd389"))
		else:
			if building.current_block_reason != &"":
				draw_rect(Rect2(b_pos + Vector2(b_size.x - 6.0, 2.0), Vector2(4, 4)), Color("#f06c5e"))
			elif building.assigned_workers > 0 and def_data.has("recipe"):
				draw_rect(Rect2(b_pos + Vector2(b_size.x - 6.0, 2.0), Vector2(3, 3)), Color("#b8e078"))
		if building.health < building.max_health:
			draw_rect(Rect2(b_pos + Vector2(2, -3), Vector2(b_size.x - 4, 2)), Color("#2b2925"))
			draw_rect(Rect2(b_pos + Vector2(2, -3), Vector2((b_size.x - 4) * float(building.health) / maxf(1.0, float(building.max_health)), 2)), Color("#bc5949"))

		# Draw entrance / doorway threshold marker
		if building.entrance_offset != Vector2i.ZERO:
			var door_tile: Vector2i = building.get_doorway_world_tile()
			var door_pos: Vector2 = Vector2(door_tile.x * TILE_SIZE, door_tile.y * TILE_SIZE)
			draw_rect(Rect2(door_pos + Vector2(3, TILE_SIZE - 3), Vector2(TILE_SIZE - 6, 2)), Color(0.3, 0.2, 0.1, 0.8))
			if building == selected_building:
				var ent_tile: Vector2i = building.get_entrance_tile()
				var ent_pos: Vector2 = Vector2(ent_tile.x * TILE_SIZE, ent_tile.y * TILE_SIZE)
				var wt: WorldTile = world_state.get_tile(ent_tile) if world_state != null else null
				var is_blocked: bool = (wt == null or not wt.is_walkable or wt.terrain_id in [&"water", &"rock"])
				if is_blocked:
					draw_rect(Rect2(ent_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(1.0, 0.2, 0.2, 0.35))
					draw_rect(Rect2(ent_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(1.0, 0.2, 0.2, 0.9), false, 1.5)
					draw_line(ent_pos + Vector2(2, 2), ent_pos + Vector2(TILE_SIZE - 2, TILE_SIZE - 2), Color.RED, 1.5)
					draw_line(ent_pos + Vector2(TILE_SIZE - 2, 2), ent_pos + Vector2(2, TILE_SIZE - 2), Color.RED, 1.5)
				else:
					draw_rect(Rect2(ent_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(0.2, 0.7, 1.0, 0.25))
					draw_rect(Rect2(ent_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(0.2, 0.8, 1.0, 0.8), false, 1.5)

func _building_texture(building_id: StringName) -> Texture2D:
	match building_id:
		&"town_hall": return TEX_TOWN_HALL
		&"house": return TEX_HOUSE
		&"farm": return TEX_FARM
		&"woodcutter": return TEX_WOODCUTTER
		&"quarry": return TEX_QUARRY
		&"bakery": return TEX_BAKERY
		&"storehouse": return TEX_STOREHOUSE
		&"barracks": return TEX_BARRACKS
		_: return null

func _draw_build_ghost() -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(active_build_id, {})
	var footprint: Vector2i = hover_footprint if hover_footprint != Vector2i.ZERO else def_info.get("footprint", Vector2i(1, 1))
	
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

	# Draw entrance / doorway indicator in placement preview
	var door_x: int = footprint.x / 2
	var ent_offset: Vector2i = Vector2i(door_x, footprint.y)
	if not def_info.get("is_resizable", false) and def_info.has("entrance_offset"):
		ent_offset = def_info.get("entrance_offset", Vector2i.ZERO)
	if ent_offset != Vector2i.ZERO:
		var ent_world_tile: Vector2i = hover_tile + ent_offset
		var ent_pos: Vector2 = Vector2(ent_world_tile.x * TILE_SIZE, ent_world_tile.y * TILE_SIZE)
		var ent_rect: Rect2 = Rect2(ent_pos, Vector2(TILE_SIZE, TILE_SIZE))
		var ent_color: Color = Color(0.2, 0.8, 1.0, 0.6) if is_hover_valid else Color(1.0, 0.2, 0.2, 0.6)
		draw_rect(ent_rect, Color(ent_color.r, ent_color.g, ent_color.b, 0.2))
		draw_rect(ent_rect, ent_color, false, 1.5)

func _draw_citizens() -> void:
	for citizen: CitizenState in citizens:
		var c_pos: Vector2 = Vector2(citizen.position_tile.x * TILE_SIZE + TILE_SIZE * 0.5, citizen.position_tile.y * TILE_SIZE + TILE_SIZE * 0.5)
		var texture: Texture2D = TEX_CITIZEN
		if citizen.role_id == &"hauler":
			texture = TEX_HAULER
		elif citizen.role_id == &"farmer":
			texture = TEX_FARMER
		draw_texture_rect(texture, Rect2(c_pos - Vector2(6, 8), Vector2(12, 16)), false)
		if citizen.carried_amount > 0:
			draw_rect(Rect2(c_pos + Vector2(2, -7), Vector2(5, 5)), Color("#b58a4e"))
			draw_rect(Rect2(c_pos + Vector2(3, -6), Vector2(3, 3)), Color("#dfbd79"))

func _draw_military_units() -> void:
	for unit: MilitaryUnitState in military_units:
		if unit.is_dead:
			continue
		var texture: Texture2D = TEX_RAIDER
		if unit.faction_id == 0:
			texture = TEX_ARCHER if unit.unit_definition_id == &"archer" else TEX_SPEARMAN
		draw_texture_rect(texture, Rect2(unit.position - Vector2(7, 8), Vector2(14, 16)), false)
		if unit in selected_units:
			draw_rect(Rect2(unit.position - Vector2(9, 10), Vector2(18, 20)), Color("#f4d36c"), false, 1.0)
		if unit.health < unit.max_health:
			var bar_pos: Vector2 = unit.position + Vector2(-8, -12)
			var ratio: float = clampf(float(unit.health) / maxf(1.0, float(unit.max_health)), 0.0, 1.0)
			draw_rect(Rect2(bar_pos, Vector2(16, 3)), Color("#2a2721"))
			draw_rect(Rect2(bar_pos, Vector2(16 * ratio, 3)), Color("#b9d879" if not unit.is_starving else "#dc8a56"))

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
