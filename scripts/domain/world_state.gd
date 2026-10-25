class_name WorldState
extends RefCounted

const DEFAULT_WIDTH: int = 96
const DEFAULT_HEIGHT: int = 96
const GENERATOR_VERSION: int = 1

@export var width: int = DEFAULT_WIDTH
@export var height: int = DEFAULT_HEIGHT
@export var seed_val: int = 0
@export var generator_version: int = GENERATOR_VERSION

var tiles: Array[WorldTile] = [] # 1D flattened array (size width * height)
var start_settlement_pos: Vector2i = Vector2i.ZERO
var raider_camp_pos: Vector2i = Vector2i.ZERO

func _init(p_width: int = DEFAULT_WIDTH, p_height: int = DEFAULT_HEIGHT, p_seed: int = 0) -> void:
	width = p_width
	height = p_height
	seed_val = p_seed
	tiles.resize(width * height)

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < width and coord.y >= 0 and coord.y < height

func get_tile(coord: Vector2i) -> WorldTile:
	if not is_valid_coord(coord):
		return null
	var idx: int = coord.y * width + coord.x
	return tiles[idx]

func set_tile(coord: Vector2i, tile: WorldTile) -> void:
	if not is_valid_coord(coord):
		return
	var idx: int = coord.y * width + coord.x
	tiles[idx] = tile
