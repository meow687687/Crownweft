class_name Inventory
extends RefCounted

const MAX_LOG_SIZE: int = 128

@export var owner_id: int = 0
@export var capacity: int = 100
var quantities: Dictionary = {} # StringName -> int
var reserved_out: Dictionary = {} # StringName -> int
var reserved_in: Dictionary = {} # StringName -> int
var accepted_resources: Array[StringName] = [] # Empty means accepts any resource

var transaction_log: Array[Dictionary] = []

func _init(p_owner_id: int = 0, p_capacity: int = 100, p_accepted: Array = []) -> void:
	owner_id = p_owner_id
	capacity = p_capacity
	accepted_resources.assign(p_accepted)

func accepts(resource_id: StringName) -> bool:
	if accepted_resources.is_empty():
		return true
	return resource_id in accepted_resources

func get_quantity(resource_id: StringName) -> int:
	return quantities.get(resource_id, 0)

func get_reserved_out(resource_id: StringName) -> int:
	return reserved_out.get(resource_id, 0)

func get_reserved_in(resource_id: StringName) -> int:
	return reserved_in.get(resource_id, 0)

func get_available_outgoing(resource_id: StringName) -> int:
	var total_qty: int = get_quantity(resource_id)
	var reserved: int = get_reserved_out(resource_id)
	return maxi(0, total_qty - reserved)

func get_total_quantity() -> int:
	var total: int = 0
	for qty: int in quantities.values():
		total += qty
	return total

func get_total_reserved_in() -> int:
	var total: int = 0
	for r_in: int in reserved_in.values():
		total += r_in
	return total

func get_free_capacity() -> int:
	var used: int = get_total_quantity() + get_total_reserved_in()
	return maxi(0, capacity - used)

func can_accept(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if not accepts(resource_id):
		return false
	return get_free_capacity() >= amount

func reserve_out(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if get_available_outgoing(resource_id) < amount:
		return false
	var current: int = get_reserved_out(resource_id)
	reserved_out[resource_id] = current + amount
	return true

func release_reserved_out(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var current: int = get_reserved_out(resource_id)
	var new_val: int = maxi(0, current - amount)
	if new_val == 0:
		reserved_out.erase(resource_id)
	else:
		reserved_out[resource_id] = new_val

func reserve_in(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if not can_accept(resource_id, amount):
		return false
	var current: int = get_reserved_in(resource_id)
	reserved_in[resource_id] = current + amount
	return true

func release_reserved_in(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var current: int = get_reserved_in(resource_id)
	var new_val: int = maxi(0, current - amount)
	if new_val == 0:
		reserved_in.erase(resource_id)
	else:
		reserved_in[resource_id] = new_val

func add_resource(resource_id: StringName, amount: int, reason: String, has_reservation: bool = false) -> bool:
	if amount <= 0:
		return false
	if not accepts(resource_id):
		return false
	
	if has_reservation:
		# Already accounted for in reserved_in, but verify reserved_in is at least amount
		if get_reserved_in(resource_id) < amount:
			return false
		# Release the reservation portion since it is now becoming actual quantity
		release_reserved_in(resource_id, amount)
		# Ensure total quantity won't exceed physical capacity
		if get_total_quantity() + amount > capacity:
			# Roll back reservation release if overflow
			reserve_in(resource_id, amount)
			return false
	else:
		if get_free_capacity() < amount:
			return false
	
	var current_qty: int = get_quantity(resource_id)
	quantities[resource_id] = current_qty + amount
	_log_transaction("ADD", resource_id, amount, reason)
	return true

func remove_resource(resource_id: StringName, amount: int, reason: String, has_reservation: bool = false) -> bool:
	if amount <= 0:
		return false
	var current_qty: int = get_quantity(resource_id)
	if current_qty < amount:
		return false
	
	if has_reservation:
		if get_reserved_out(resource_id) < amount:
			return false
		release_reserved_out(resource_id, amount)
	else:
		if get_available_outgoing(resource_id) < amount:
			return false
	
	var new_qty: int = current_qty - amount
	if new_qty == 0:
		quantities.erase(resource_id)
	else:
		quantities[resource_id] = new_qty
		
	_log_transaction("REMOVE", resource_id, amount, reason)
	return true

static func transfer_atomic(from_inv: Inventory, to_inv: Inventory, resource_id: StringName, amount: int, reason: String, had_reservations: bool = false) -> bool:
	if from_inv == null or to_inv == null or amount <= 0:
		return false
	
	# Pre-validation: atomic check before mutating either inventory
	if had_reservations:
		if from_inv.get_quantity(resource_id) < amount or from_inv.get_reserved_out(resource_id) < amount:
			return false
		if not to_inv.accepts(resource_id) or to_inv.get_reserved_in(resource_id) < amount:
			return false
		if to_inv.get_total_quantity() + amount > to_inv.capacity:
			return false
	else:
		if from_inv.get_available_outgoing(resource_id) < amount:
			return false
		if not to_inv.can_accept(resource_id, amount):
			return false
	
	# Mutation phase: both passed checks
	var removed: bool = from_inv.remove_resource(resource_id, amount, reason, had_reservations)
	if not removed:
		return false
	
	var added: bool = to_inv.add_resource(resource_id, amount, reason, had_reservations)
	if not added:
		# Strict rollback in case of unexpected failure
		from_inv.add_resource(resource_id, amount, "ROLLBACK_" + reason, had_reservations)
		return false
		
	return true

func _log_transaction(type: String, resource_id: StringName, amount: int, reason: String) -> void:
	if transaction_log.size() >= MAX_LOG_SIZE:
		transaction_log.pop_front()
	transaction_log.append({
		"type": type,
		"resource_id": resource_id,
		"amount": amount,
		"reason": reason,
		"total_after": get_total_quantity()
	})
