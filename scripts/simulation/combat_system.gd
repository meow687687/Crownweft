class_name CombatSystem
extends RefCounted

signal unit_attacked(attacker: MilitaryUnitState, target: MilitaryUnitState, damage: int)
signal unit_died(unit: MilitaryUnitState)
signal building_attacked(attacker: MilitaryUnitState, target: BuildingState, damage: int)
signal building_destroyed(target: BuildingState)
signal raid_announced(seconds_until_attack: float)
signal raid_started()

var raid_countdown: float = 90.0 # Time until raid begins
var raid_warning_threshold: float = 20.0
var raid_warning_sent: bool = false
var raid_spawned: bool = false

var next_unit_id: int = 1000
var unit_navigation: Dictionary = {} # unit_id -> cached grid path and target signature

func spawn_player_unit(unit_def_id: StringName, pos: Vector2) -> MilitaryUnitState:
	var unit: MilitaryUnitState = MilitaryUnitState.new(next_unit_id, unit_def_id, 0, pos)
	next_unit_id += 1
	return unit

func spawn_raider_unit(pos: Vector2) -> MilitaryUnitState:
	var unit: MilitaryUnitState = MilitaryUnitState.new(next_unit_id, &"raider", 1, pos)
	next_unit_id += 1
	return unit

func tick_combat(
	units: Array[MilitaryUnitState],
	delta: float,
	buildings: Array[BuildingState] = [],
	pathfinding: PathfindingService = null
) -> void:
	var defs: Dictionary = UnitDef.get_all_defs()
	
	for unit in units:
		if unit.is_dead:
			continue
			
		var def: UnitDef = defs.get(unit.unit_definition_id, null)
		if def == null:
			continue
			
		if unit.attack_timer > 0.0:
			unit.attack_timer -= delta
			
		if unit.faction_id == 0:
			# Player Unit AI / Order execution
			_execute_player_unit_order(unit, def, units, delta, pathfinding)
		else:
			# Raiders fight defenders first, then attack settlement buildings.
			_execute_raider_ai(unit, def, units, delta, buildings, pathfinding)

func _execute_player_unit_order(
	unit: MilitaryUnitState,
	def: UnitDef,
	all_units: Array[MilitaryUnitState],
	delta: float,
	pathfinding: PathfindingService = null
) -> void:
	match unit.order_type:
		MilitaryUnitState.OrderType.HOLD:
			var target: MilitaryUnitState = _find_nearest_enemy_in_range(unit, all_units, def.attack_range)
			if target != null:
				_perform_attack(unit, def, target)
				
		MilitaryUnitState.OrderType.MOVE:
			var dist: float = unit.position.distance_to(unit.target_pos)
			if dist > 2.0:
				_move_unit_toward(unit, def, unit.target_pos, delta, pathfinding, "move:%d:%d" % [floori(unit.target_pos.x / 16.0), floori(unit.target_pos.y / 16.0)])
			else:
				unit.set_hold_order()
				unit_navigation.erase(unit.id)
				
		MilitaryUnitState.OrderType.ATTACK_MOVE:
			# Scan for enemy in awareness radius (120 px)
			var enemy: MilitaryUnitState = _find_nearest_enemy_in_range(unit, all_units, 120.0)
			if enemy != null:
				_engage_target(unit, def, enemy, delta, pathfinding)
			else:
				var dist: float = unit.position.distance_to(unit.target_pos)
				if dist > 2.0:
					_move_unit_toward(unit, def, unit.target_pos, delta, pathfinding, "attack_move:%d:%d" % [floori(unit.target_pos.x / 16.0), floori(unit.target_pos.y / 16.0)])
				else:
					unit.set_hold_order()
					unit_navigation.erase(unit.id)
					
		MilitaryUnitState.OrderType.ATTACK_TARGET:
			var target: MilitaryUnitState = _find_unit_by_id(all_units, unit.target_unit_id)
			if target != null and not target.is_dead:
				_engage_target(unit, def, target, delta, pathfinding)
			else:
				unit.set_hold_order()

func _execute_raider_ai(
	unit: MilitaryUnitState,
	def: UnitDef,
	all_units: Array[MilitaryUnitState],
	delta: float,
	buildings: Array[BuildingState],
	pathfinding: PathfindingService = null
) -> void:
	# Engage nearby defenders, but do not chase them across the entire map:
	# raids must continue to threaten the settlement and its supply infrastructure.
	var target: MilitaryUnitState = _find_nearest_player_unit(unit, all_units)
	if target != null and unit.position.distance_to(target.position) <= 128.0:
		_engage_target(unit, def, target, delta, pathfinding)
		return
	var building_target: BuildingState = _find_nearest_building(unit, buildings)
	if building_target != null:
		_engage_building(unit, def, building_target, delta, pathfinding)

func _find_nearest_building(unit: MilitaryUnitState, buildings: Array[BuildingState]) -> BuildingState:
	var nearest: BuildingState = null
	var nearest_distance: float = INF
	for building: BuildingState in buildings:
		if building == null or building.is_destroyed:
			continue
		var closest: Vector2 = _closest_point_on_rect(_building_rect(building), unit.position)
		var distance: float = unit.position.distance_to(closest)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = building
	return nearest

static func _closest_point_on_rect(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)

func _building_rect(building: BuildingState) -> Rect2:
	var footprint: Vector2i = building.get_footprint()
	return Rect2(Vector2(building.tile_origin) * 16.0, Vector2(footprint) * 16.0)

func _engage_building(
	unit: MilitaryUnitState,
	def: UnitDef,
	target: BuildingState,
	delta: float,
	pathfinding: PathfindingService = null
) -> void:
	var rect: Rect2 = _building_rect(target)
	var closest: Vector2 = _closest_point_on_rect(rect, unit.position)
	var offset: Vector2 = closest - unit.position
	var distance: float = offset.length()
	if distance <= def.attack_range + 2.0:
		if unit.attack_timer <= 0.0:
			unit.attack_timer = def.attack_cooldown
			var damage: int = maxi(1, def.damage)
			target.health = maxi(0, target.health - damage)
			building_attacked.emit(unit, target, damage)
			if target.health == 0:
				target.is_destroyed = true
				building_destroyed.emit(target)
	elif distance > 0.1:
		var footprint: Vector2i = target.get_footprint()
		_move_unit_toward(
			unit, def, closest, delta, pathfinding,
			"building:%d" % target.entity_id, target.tile_origin, footprint
		)

func _engage_target(
	unit: MilitaryUnitState,
	def: UnitDef,
	target: MilitaryUnitState,
	delta: float,
	pathfinding: PathfindingService = null
) -> void:
	var dist: float = unit.position.distance_to(target.position)
	if dist <= def.attack_range:
		# In range, attack
		_perform_attack(unit, def, target)
	else:
		# Follow a path to an adjacent tile instead of walking straight through buildings/water.
		var target_tile := Vector2i(floori(target.position.x / 16.0), floori(target.position.y / 16.0))
		_move_unit_toward(
			unit, def, target.position, delta, pathfinding,
			"unit:%d" % target.id, target_tile, Vector2i.ONE
		)

func _move_unit_toward(
	unit: MilitaryUnitState,
	def: UnitDef,
	target_pos: Vector2,
	delta: float,
	pathfinding: PathfindingService,
	target_key: String,
	target_tile_override: Vector2i = Vector2i(-1, -1),
	approach_footprint: Vector2i = Vector2i.ZERO
) -> void:
	var direct_distance: float = unit.position.distance_to(target_pos)
	if direct_distance <= 1.5:
		return
	if pathfinding == null:
		unit.position += (target_pos - unit.position).normalized() * minf(def.speed * delta, direct_distance)
		return

	var current_tile := Vector2i(floori(unit.position.x / 16.0), floori(unit.position.y / 16.0))
	var target_tile := target_tile_override if target_tile_override.x >= 0 and target_tile_override.y >= 0 else Vector2i(floori(target_pos.x / 16.0), floori(target_pos.y / 16.0))
	if not pathfinding.astar_grid.is_in_bounds(target_tile.x, target_tile.y):
		return
	var target_is_solid: bool = pathfinding.astar_grid.is_point_solid(target_tile)
	var requested_footprint: Vector2i = approach_footprint
	if requested_footprint == Vector2i.ZERO and target_is_solid:
		requested_footprint = Vector2i.ONE
	var stop_at_path_end: bool = requested_footprint != Vector2i.ZERO

	var nav: Dictionary = unit_navigation.get(unit.id, {})
	var cached_path: Array[Vector2i] = []
	cached_path.assign(nav.get("path", []))
	var path_index: int = int(nav.get("index", 1))
	var needs_repath: bool = nav.get("target_key", "") != target_key or nav.get("target_tile", Vector2i(-1, -1)) != target_tile
	if not cached_path.is_empty() and path_index < cached_path.size() and pathfinding.astar_grid.is_point_solid(cached_path[path_index]):
		needs_repath = true
	if needs_repath:
		if requested_footprint != Vector2i.ZERO:
			cached_path = pathfinding.find_path_to_adjacent(current_tile, target_tile, requested_footprint)
		else:
			cached_path = pathfinding.find_path(current_tile, target_tile)
		path_index = 1 # A* includes the start tile.
		nav = {"target_key": target_key, "target_tile": target_tile, "path": cached_path, "index": path_index, "stop_at_end": stop_at_path_end}
		unit_navigation[unit.id] = nav
	if cached_path.is_empty():
		return

	if path_index < cached_path.size():
		var next_center := Vector2(cached_path[path_index]) * 16.0 + Vector2(8.0, 8.0)
		var step_delta: Vector2 = next_center - unit.position
		var max_step: float = def.speed * delta
		if step_delta.length() <= max_step:
			unit.position = next_center
			path_index += 1
			nav["index"] = path_index
			unit_navigation[unit.id] = nav
		else:
			unit.position += step_delta.normalized() * max_step
		return

	if bool(nav.get("stop_at_end", false)):
		if unit.order_type == MilitaryUnitState.OrderType.MOVE or unit.order_type == MilitaryUnitState.OrderType.ATTACK_MOVE:
			unit.target_pos = unit.position
		return
	var final_distance: float = unit.position.distance_to(target_pos)
	if final_distance > 1.5:
		unit.position += (target_pos - unit.position).normalized() * minf(def.speed * delta, final_distance)

func _perform_attack(attacker: MilitaryUnitState, def: UnitDef, target: MilitaryUnitState) -> void:
	if attacker.attack_timer > 0.0:
		return
		
	attacker.attack_timer = def.attack_cooldown
	
	# Damage calculation
	var dmg: int = def.damage
	if attacker.is_starving:
		# 50% damage penalty for starving soldiers lacking bread upkeep!
		dmg = maxi(1, int(float(dmg) * 0.5))
		
	target.health -= dmg
	unit_attacked.emit(attacker, target, dmg)
	
	if target.health <= 0:
		target.health = 0
		target.is_dead = true
		unit_died.emit(target)

func _find_nearest_enemy_in_range(unit: MilitaryUnitState, all_units: Array[MilitaryUnitState], max_dist: float) -> MilitaryUnitState:
	var best_target: MilitaryUnitState = null
	var best_dist: float = max_dist
	
	for other in all_units:
		if other.is_dead or other.faction_id == unit.faction_id:
			continue
		var dist: float = unit.position.distance_to(other.position)
		if dist <= best_dist:
			best_dist = dist
			best_target = other
			
	return best_target

func _find_nearest_player_unit(unit: MilitaryUnitState, all_units: Array[MilitaryUnitState]) -> MilitaryUnitState:
	var best_target: MilitaryUnitState = null
	var best_dist: float = 999999.0
	
	for other in all_units:
		if other.is_dead or other.faction_id != 0:
			continue
		var dist: float = unit.position.distance_to(other.position)
		if dist < best_dist:
			best_dist = dist
			best_target = other
			
	return best_target

func _find_unit_by_id(all_units: Array[MilitaryUnitState], id: int) -> MilitaryUnitState:
	for u in all_units:
		if u.id == id:
			return u
	return null

func tick_raid_timer(delta: float, raider_camp_pos: Vector2i, units: Array[MilitaryUnitState]) -> void:
	if raid_spawned:
		return
		
	raid_countdown -= delta
	
	if not raid_warning_sent and raid_countdown <= raid_warning_threshold:
		raid_warning_sent = true
		raid_announced.emit(raid_countdown)
		
	if raid_countdown <= 0.0:
		raid_spawned = true
		raid_started.emit()
		# Spawn small raid force (e.g. 4 raiders)
		var camp_center: Vector2 = Vector2(raider_camp_pos.x * 16.0, raider_camp_pos.y * 16.0)
		for i in range(4):
			var spawn_pos: Vector2 = camp_center + Vector2((i % 2) * 16.0, (i / 2) * 16.0)
			var raider: MilitaryUnitState = spawn_raider_unit(spawn_pos)
			units.append(raider)

func apply_military_upkeep(units: Array[MilitaryUnitState], food_inventories: Array[Inventory]) -> void:
	for u in units:
		if u.is_dead or u.faction_id != 0:
			continue
		var fed: bool = false
		for inv in food_inventories:
			if inv.get_available_outgoing(&"bread") >= 1:
				inv.remove_resource(&"bread", 1, "MILITARY_UPKEEP", false)
				fed = true
				break
		u.is_starving = not fed
