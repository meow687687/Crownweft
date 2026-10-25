class_name PathfindingService
extends RefCounted

var astar_grid: AStarGrid2D = null
var width: int = 96
var height: int = 96

const WEIGHT_ROAD: float = 0.5
const WEIGHT_GRASS: float = 1.0
const WEIGHT_FOREST: float = 1.6

func _init(p_width: int = 96, p_height: int = 96) -> void:
	width = p_width
	height = p_height
	_setup_grid()

func _setup_grid() -> void:
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, width, height)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()

func initialize_from_world(world: WorldState) -> void:
	width = world.width
	height = world.height
	_setup_grid()
	
	for y in range(height):
		for x in range(width):
			var coord: Vector2i = Vector2i(x, y)
			var tile: WorldTile = world.get_tile(coord)
			if tile == null:
				continue
			
			if not tile.is_walkable:
				astar_grid.set_point_solid(coord, true)
			else:
				astar_grid.set_point_solid(coord, false)
				if tile.road_level > 0:
					astar_grid.set_point_weight_scale(coord, WEIGHT_ROAD)
				elif tile.terrain_id == &"forest":
					astar_grid.set_point_weight_scale(coord, WEIGHT_FOREST)
				else:
					astar_grid.set_point_weight_scale(coord, WEIGHT_GRASS)

func set_solid(coord: Vector2i, solid: bool) -> void:
	if astar_grid.is_in_bounds(coord.x, coord.y):
		astar_grid.set_point_solid(coord, solid)

func set_road(coord: Vector2i, has_road: bool) -> void:
	if astar_grid.is_in_bounds(coord.x, coord.y):
		astar_grid.set_point_solid(coord, false)
		astar_grid.set_point_weight_scale(coord, WEIGHT_ROAD if has_road else WEIGHT_GRASS)

func find_path(from_coord: Vector2i, to_coord: Vector2i) -> Array[Vector2i]:
	if not astar_grid.is_in_bounds(from_coord.x, from_coord.y) or not astar_grid.is_in_bounds(to_coord.x, to_coord.y):
		return []
	
	# If destination is solid (e.g. clicking a building), AStarGrid2D won't route unless we allow neighbor routing
	# For normal tile-to-tile:
	var path_arr: Array[Vector2i] = astar_grid.get_id_path(from_coord, to_coord)
	return path_arr

func find_path_to_adjacent(from_coord: Vector2i, target_coord: Vector2i) -> Array[Vector2i]:
	# Used when walking to a building footprint that is solid
	var neighbors: Array[Vector2i] = [
		target_coord + Vector2i.UP,
		target_coord + Vector2i.DOWN,
		target_coord + Vector2i.LEFT,
		target_coord + Vector2i.RIGHT
	]
	
	var best_path: Array[Vector2i] = []
	var best_length: int = 999999
	
	for n in neighbors:
		if astar_grid.is_in_bounds(n.x, n.y) and not astar_grid.is_point_solid(n):
			var p = find_path(from_coord, n)
			if not p.is_empty() and p.size() < best_length:
				best_path = p
				best_length = p.size()
				
	return best_path

func is_reachable(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	return not find_path(from_coord, to_coord).is_empty()
