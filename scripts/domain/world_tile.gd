class_name WorldTile
extends RefCounted

@export var coord: Vector2i = Vector2i.ZERO
@export var terrain_id: StringName = &"grass" # &"grass", &"forest", &"rock", &"water"
@export var fertility: float = 0.5 # 0.0 to 1.0
@export var resource_deposit_id: StringName = &"" # &"trees", &"stone_deposit", etc.
@export var building_id: int = 0
@export var road_level: int = 0 # 0 = none, 1 = dirt road
@export var is_buildable: bool = true
@export var is_walkable: bool = true

func _init(p_coord: Vector2i = Vector2i.ZERO, p_terrain: StringName = &"grass", p_fertility: float = 0.5) -> void:
	coord = p_coord
	terrain_id = p_terrain
	fertility = p_fertility
	_update_flags()

func _update_flags() -> void:
	match terrain_id:
		&"water":
			is_buildable = false
			is_walkable = false
		&"rock":
			is_buildable = false
			is_walkable = false
			resource_deposit_id = &"stone_deposit"
		&"forest":
			is_buildable = false # must clear trees to build or woodcutter harvests
			is_walkable = true
			resource_deposit_id = &"trees"
		&"grass":
			is_buildable = (building_id == 0)
			is_walkable = (building_id == 0 or road_level > 0)
