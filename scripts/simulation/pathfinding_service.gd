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

func find_path_to_adjacent(
	from_coord: Vector2i,
	target_coord: Vector2i,
	footprint: Vector2i = Vector2i.ONE
) -> Array[Vector2i]:
	# Find a reachable tile along the complete perimeter of the target footprint.
	# Checking only the top-left tile's four neighbors makes most edges of 2x2/3x3
	# buildings inaccessible once the whole footprint is marked solid.
	var neighbors: Array[Vector2i] = []
	for x in range(footprint.x):
		neighbors.append(target_coord + Vector2i(x, -1))
		neighbors.append(target_coord + Vector2i(x, footprint.y))
	for y in range(footprint.y):
		neighbors.append(target_coord + Vector2i(-1, y))
		neighbors.append(target_coord + Vector2i(footprint.x, y))

	var best_path: Array[Vector2i] = []
	var best_length: int = 999999
	for neighbor: Vector2i in neighbors:
		if not astar_grid.is_in_bounds(neighbor.x, neighbor.y):
			continue
		if astar_grid.is_point_solid(neighbor):
			continue
		var candidate: Array[Vector2i] = find_path(from_coord, neighbor)
		if not candidate.is_empty() and candidate.size() < best_length:
			best_path = candidate
			best_length = candidate.size()
	return best_path

func find_path_to_entrance(
	from_coord: Vector2i,
	building: BuildingState,
	preferred_slot: int = 0,
	occupied_positions: Array[Vector2i] = []
) -> Array[Vector2i]:
	if building == null:
		return []
		
	# 1. If building has explicit interaction tiles, evaluate them
	var candidates: Array[Vector2i] = []
	var all_staging: Array[Vector2i] = building.get_interaction_tiles()
	
	# Start with the preferred slot if within range and not occupied
	if preferred_slot >= 0 and preferred_slot < all_staging.size():
		var preferred_tile: Vector2i = all_staging[preferred_slot]
		if not preferred_tile in occupied_positions:
			candidates.append(preferred_tile)
			
	# Add remaining non-occupied staging tiles
	for s in all_staging:
		if not s in candidates and not s in occupied_positions:
			candidates.append(s)
			
	# If all slots are occupied by other workers, allow queuing at the primary/staging tiles
	if candidates.is_empty():
		for s in all_staging:
			if not s in candidates:
				candidates.append(s)

	# 2. Try to find path to the best reachable candidate
	var best_path: Array[Vector2i] = []
	var best_len: int = 999999
	for candidate: Vector2i in candidates:
		if not astar_grid.is_in_bounds(candidate.x, candidate.y):
			continue
		if astar_grid.is_point_solid(candidate):
			continue
		var path_res: Array[Vector2i] = find_path(from_coord, candidate)
		if not path_res.is_empty() and path_res.size() < best_len:
			best_path = path_res
			best_len = path_res.size()
			if candidate == candidates[0]:
				break

	if not best_path.is_empty():
		return best_path

	# 3. Fallback: if building has no valid interaction tiles or all are blocked, fall back to perimeter adjacency
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var footprint: Vector2i = defs.get(building.definition_id, {}).get("footprint", Vector2i(2, 2))
	return find_path_to_adjacent(from_coord, building.tile_origin, footprint)

func is_entrance_walkable(building: BuildingState) -> bool:
	if building == null:
		return false
	var ent_tile: Vector2i = building.get_entrance_tile()
	if not astar_grid.is_in_bounds(ent_tile.x, ent_tile.y):
		return false
	return not astar_grid.is_point_solid(ent_tile)

func is_reachable(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	return not find_path(from_coord, to_coord).is_empty()
