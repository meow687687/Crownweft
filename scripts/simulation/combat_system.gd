class_name CombatSystem
extends RefCounted

signal unit_attacked(attacker: MilitaryUnitState, target: MilitaryUnitState, damage: int)
signal unit_died(unit: MilitaryUnitState)
signal raid_announced(seconds_until_attack: float)
signal raid_started()

var raid_countdown: float = 90.0 # Time until raid begins
var raid_warning_threshold: float = 20.0
var raid_warning_sent: bool = false
var raid_spawned: bool = false

var next_unit_id: int = 1000

func spawn_player_unit(unit_def_id: StringName, pos: Vector2) -> MilitaryUnitState:
	var unit: MilitaryUnitState = MilitaryUnitState.new(next_unit_id, unit_def_id, 0, pos)
	next_unit_id += 1
	return unit

func spawn_raider_unit(pos: Vector2) -> MilitaryUnitState:
	var unit: MilitaryUnitState = MilitaryUnitState.new(next_unit_id, &"raider", 1, pos)
	next_unit_id += 1
	return unit

func tick_combat(units: Array[MilitaryUnitState], delta: float) -> void:
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
			_execute_player_unit_order(unit, def, units, delta)
		else:
			# Raider AI
			_execute_raider_ai(unit, def, units, delta)

func _execute_player_unit_order(unit: MilitaryUnitState, def: UnitDef, all_units: Array[MilitaryUnitState], delta: float) -> void:
	match unit.order_type:
		MilitaryUnitState.OrderType.HOLD:
			var target: MilitaryUnitState = _find_nearest_enemy_in_range(unit, all_units, def.attack_range)
			if target != null:
				_perform_attack(unit, def, target)
				
		MilitaryUnitState.OrderType.MOVE:
			var dist: float = unit.position.distance_to(unit.target_pos)
			if dist > 2.0:
				var move_dir: Vector2 = (unit.target_pos - unit.position).normalized()
				unit.position += move_dir * def.speed * delta
			else:
				unit.set_hold_order()
				
		MilitaryUnitState.OrderType.ATTACK_MOVE:
			# Scan for enemy in awareness radius (120 px)
			var enemy: MilitaryUnitState = _find_nearest_enemy_in_range(unit, all_units, 120.0)
			if enemy != null:
				_engage_target(unit, def, enemy, delta)
			else:
				var dist: float = unit.position.distance_to(unit.target_pos)
				if dist > 2.0:
					var move_dir: Vector2 = (unit.target_pos - unit.position).normalized()
					unit.position += move_dir * def.speed * delta
				else:
					unit.set_hold_order()
					
		MilitaryUnitState.OrderType.ATTACK_TARGET:
			var target: MilitaryUnitState = _find_unit_by_id(all_units, unit.target_unit_id)
			if target != null and not target.is_dead:
				_engage_target(unit, def, target, delta)
			else:
				unit.set_hold_order()

func _execute_raider_ai(unit: MilitaryUnitState, def: UnitDef, all_units: Array[MilitaryUnitState], delta: float) -> void:
	# Raiders target nearest player unit
	var target: MilitaryUnitState = _find_nearest_player_unit(unit, all_units)
	if target != null:
		_engage_target(unit, def, target, delta)

func _engage_target(unit: MilitaryUnitState, def: UnitDef, target: MilitaryUnitState, delta: float) -> void:
	var dist: float = unit.position.distance_to(target.position)
	if dist <= def.attack_range:
		# In range, attack
		_perform_attack(unit, def, target)
	else:
		# Move toward target
		var dir: Vector2 = (target.position - unit.position).normalized()
		unit.position += dir * def.speed * delta

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
