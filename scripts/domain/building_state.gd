class_name BuildingState
extends RefCounted

enum Status {
	PLANNED,
	UNDER_CONSTRUCTION,
	ACTIVE,
	DESTROYED
}

@export var entity_id: int = 0
@export var definition_id: StringName = &""
var inventory: Inventory = null
var assigned_workers: int = 0
var enabled: bool = true
var production_progress: int = 0
var production_work_accum: float = 0.0
var current_block_reason: StringName = &""
var tile_origin: Vector2i = Vector2i.ZERO
var health: int = 100
var max_health: int = 100
var is_destroyed: bool = false

# Staged construction properties
@export var status: Status = Status.ACTIVE
@export var construction_progress: float = 1.0
@export var construction_ticks: int = 0
var construction_labor_accum: float = 0.0
@export var construction_required_ticks: int = 10
var construction_cost: Dictionary = {} # StringName -> int
var construction_inventory: Inventory = null
var construction_block_reason: StringName = &""

# Explicit building entrance & doorway routing properties
var entrance_offset: Vector2i = Vector2i.ZERO
var doorway_tile: Vector2i = Vector2i.ZERO
var staging_offsets: Array[Vector2i] = []

func _init(p_entity_id: int = 0, p_def_id: StringName = &"", p_capacity: int = 50, p_accepted: Array = []) -> void:
	entity_id = p_entity_id
	definition_id = p_def_id
	inventory = Inventory.new(p_entity_id, p_capacity, p_accepted)
	if p_def_id != &"":
		_init_entrance_from_catalog(p_def_id)

func _init_entrance_from_catalog(p_def_id: StringName) -> void:
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var def_info: Dictionary = defs.get(p_def_id, {})
	if not def_info.is_empty():
		entrance_offset = def_info.get("entrance_offset", Vector2i.ZERO)
		doorway_tile = def_info.get("doorway_tile", Vector2i.ZERO)
		var stagings: Array = def_info.get("staging_offsets", [])
		staging_offsets.clear()
		for s in stagings:
			staging_offsets.append(s as Vector2i)

func get_entrance_tile() -> Vector2i:
	if entrance_offset != Vector2i.ZERO:
		return tile_origin + entrance_offset
	# Default fallback to south edge center
	var defs: Dictionary = BuildingCatalog.get_all_defs()
	var footprint: Vector2i = defs.get(definition_id, {}).get("footprint", Vector2i(2, 2))
	return tile_origin + Vector2i(footprint.x / 2, footprint.y)

func get_doorway_world_tile() -> Vector2i:
	return tile_origin + doorway_tile

func get_interaction_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not staging_offsets.is_empty():
		for s in staging_offsets:
			tiles.append(tile_origin + s)
	else:
		tiles.append(get_entrance_tile())
	return tiles

func get_staging_tile(slot_index: int) -> Vector2i:
	if staging_offsets.is_empty():
		return get_entrance_tile()
	var idx: int = slot_index % staging_offsets.size()
	return tile_origin + staging_offsets[idx]

func is_at_entrance_or_staging(coord: Vector2i) -> bool:
	if coord == get_entrance_tile():
		return true
	for s in get_interaction_tiles():
		if coord == s:
			return true
	return false

func is_under_construction() -> bool:
	return (status == Status.PLANNED or status == Status.UNDER_CONSTRUCTION) and not is_destroyed

func is_active() -> bool:
	return status == Status.ACTIVE and not is_destroyed and enabled

func has_all_construction_materials() -> bool:
	if construction_cost.is_empty():
		return true
	if construction_inventory == null:
		return false
	for res_id: StringName in construction_cost:
		var req: int = construction_cost[res_id]
		if construction_inventory.get_quantity(res_id) < req:
			return false
	return true

func get_delivered_materials() -> Dictionary:
	var delivered: Dictionary = {}
	if construction_inventory == null:
		return delivered
	for res_id: StringName in construction_cost:
		delivered[res_id] = construction_inventory.get_quantity(res_id)
	return delivered

func get_outstanding_materials() -> Dictionary:
	var outstanding: Dictionary = {}
	if construction_inventory == null:
		return construction_cost.duplicate()
	for res_id: StringName in construction_cost:
		var req: int = construction_cost[res_id]
		var delivered: int = construction_inventory.get_quantity(res_id)
		outstanding[res_id] = maxi(0, req - delivered)
	return outstanding

func get_unreserved_materials_needed() -> Dictionary:
	var needed: Dictionary = {}
	if construction_inventory == null:
		return construction_cost.duplicate()
	for res_id: StringName in construction_cost:
		var req: int = construction_cost[res_id]
		var delivered: int = construction_inventory.get_quantity(res_id)
		var inbound: int = construction_inventory.get_reserved_in(res_id)
		var rem: int = maxi(0, req - delivered - inbound)
		if rem > 0:
			needed[res_id] = rem
	return needed

func get_construction_state() -> Dictionary:
	var status_name: String = "ACTIVE"
	match status:
		Status.PLANNED: status_name = "PLANNED"
		Status.UNDER_CONSTRUCTION: status_name = "UNDER_CONSTRUCTION"
		Status.ACTIVE: status_name = "ACTIVE"
		Status.DESTROYED: status_name = "DESTROYED"
	return {
		"status": status,
		"status_name": status_name,
		"progress": construction_progress,
		"ticks_completed": construction_ticks,
		"ticks_required": construction_required_ticks,
		"required_materials": construction_cost.duplicate(),
		"delivered_materials": get_delivered_materials(),
		"outstanding_materials": get_outstanding_materials(),
		"unreserved_materials_needed": get_unreserved_materials_needed(),
		"blocked_reason": construction_block_reason
	}

