class_name WorldGenerationService
extends RefCounted

const MAX_ATTEMPTS: int = 10
const MAP_WIDTH: int = 96
const MAP_HEIGHT: int = 96

func generate_world(seed_val: int) -> WorldState:
	for attempt in range(MAX_ATTEMPTS):
		var actual_seed: int = seed_val + attempt * 10007
		var world: WorldState = _build_raw_map(actual_seed)
		if _validate_world(world):
			return world
			
	# Fallback: if all random noise maps failed validation, construct a guaranteed starter map
	var fallback: WorldState = _build_guaranteed_map(seed_val)
	return fallback

func _build_raw_map(seed_val: int) -> WorldState:
	var world: WorldState = WorldState.new(MAP_WIDTH, MAP_HEIGHT, seed_val)
	
	# Noise generators
	var elev_noise: FastNoiseLite = FastNoiseLite.new()
	elev_noise.seed = seed_val
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.frequency = 0.03
	
	var forest_noise: FastNoiseLite = FastNoiseLite.new()
	forest_noise.seed = seed_val + 101
	forest_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	forest_noise.frequency = 0.06
	
	var fertility_noise: FastNoiseLite = FastNoiseLite.new()
	fertility_noise.seed = seed_val + 202
	fertility_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	fertility_noise.frequency = 0.04
	
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var coord: Vector2i = Vector2i(x, y)
			var elev: float = elev_noise.get_noise_2d(float(x), float(y)) # -1.0 to 1.0
			var veg: float = forest_noise.get_noise_2d(float(x), float(y))
			var fert: float = clampf((fertility_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5, 0.0, 1.0)
			
			var terrain: StringName = &"grass"
			if elev < -0.35:
				terrain = &"water"
				fert = 0.0
			elif elev > 0.40:
				terrain = &"rock"
				fert = 0.1
			elif veg > 0.15:
				terrain = &"forest"
			else:
				terrain = &"grass"
				
			var tile: WorldTile = WorldTile.new(coord, terrain, fert)
			world.set_tile(coord, tile)
	
	# Designate settlement center and raider camp
	world.start_settlement_pos = Vector2i(28, 48)
	world.raider_camp_pos = Vector2i(78, 20)
	
	# Carve clear buildable area around player start
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c: Vector2i = world.start_settlement_pos + Vector2i(dx, dy)
			if world.is_valid_coord(c):
				var t: WorldTile = world.get_tile(c)
				t.terrain_id = &"grass"
				t.fertility = maxf(t.fertility, 0.7)
				t._update_flags()
				
	# Place nearby starter forest and rock deposits if missing
	_ensure_resource_proximity(world, world.start_settlement_pos)
	
	# Ensure raider camp tile is walkable
	var raider_tile: WorldTile = world.get_tile(world.raider_camp_pos)
	if raider_tile != null:
		raider_tile.terrain_id = &"grass"
		raider_tile._update_flags()
		
	return world

func _ensure_resource_proximity(world: WorldState, center: Vector2i) -> void:
	# Ensure a cluster of trees within 8 tiles
	var forest_center: Vector2i = center + Vector2i(7, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c: Vector2i = forest_center + Vector2i(dx, dy)
			if world.is_valid_coord(c):
				var t: WorldTile = world.get_tile(c)
				t.terrain_id = &"forest"
				t._update_flags()
				
	# Ensure a cluster of rock within 12 tiles
	var rock_center: Vector2i = center + Vector2i(0, 9)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = rock_center + Vector2i(dx, dy)
			if world.is_valid_coord(c):
				var t: WorldTile = world.get_tile(c)
				t.terrain_id = &"rock"
				t._update_flags()

func _validate_world(world: WorldState) -> bool:
	var pf: PathfindingService = PathfindingService.new(world.width, world.height)
	pf.initialize_from_world(world)
	
	# 1. Connectivity check: raider camp must be reachable from player start
	var path_to_raider: Array[Vector2i] = pf.find_path(world.start_settlement_pos, world.raider_camp_pos)
	if path_to_raider.is_empty():
		return false
		
	# 2. Starting resource check: trees within radius 12, rocks within radius 16
	var found_trees: bool = false
	var found_stone: bool = false
	var buildable_count: int = 0
	
	var r: int = 16
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = world.start_settlement_pos + Vector2i(dx, dy)
			var tile: WorldTile = world.get_tile(c)
			if tile == null:
				continue
			var dist: float = float(dx * dx + dy * dy)
			if dist <= 25.0 and tile.is_buildable:
				buildable_count += 1
			if dist <= 144.0 and tile.terrain_id == &"forest":
				found_trees = true
			if dist <= 256.0 and tile.terrain_id == &"rock":
				found_stone = true
				
	return (buildable_count >= 15) and found_trees and found_stone

func _build_guaranteed_map(seed_val: int) -> WorldState:
	var world: WorldState = WorldState.new(MAP_WIDTH, MAP_HEIGHT, seed_val)
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var coord: Vector2i = Vector2i(x, y)
			# Perimeter border of rocks
			var terrain: StringName = &"grass"
			if x == 0 or x == MAP_WIDTH - 1 or y == 0 or y == MAP_HEIGHT - 1:
				terrain = &"rock"
			var tile: WorldTile = WorldTile.new(coord, terrain, 0.6)
			world.set_tile(coord, tile)
			
	world.start_settlement_pos = Vector2i(30, 48)
	world.raider_camp_pos = Vector2i(75, 20)
	_ensure_resource_proximity(world, world.start_settlement_pos)
	return world
