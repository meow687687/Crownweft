class_name TradeContract
extends RefCounted

const STATUS_OFFERED: StringName = &"offered"
const STATUS_ACCEPTED: StringName = &"accepted"
const STATUS_RESERVED: StringName = &"reserved"
const STATUS_IN_TRANSIT: StringName = &"in_transit"
const STATUS_DELIVERED: StringName = &"delivered"
const STATUS_SETTLED: StringName = &"settled"
const STATUS_CANCELLED: StringName = &"cancelled"
const STATUS_FAILED: StringName = &"failed"
const STATUS_EXPIRED: StringName = &"expired"

const ALL_STATUSES: Array[StringName] = [
	STATUS_OFFERED,
	STATUS_ACCEPTED,
	STATUS_RESERVED,
	STATUS_IN_TRANSIT,
	STATUS_DELIVERED,
	STATUS_SETTLED,
	STATUS_CANCELLED,
	STATUS_FAILED,
	STATUS_EXPIRED
]

var id: int = 0
var buyer_faction_id: StringName = &""
var seller_faction_id: StringName = &""
var resource_id: StringName = &""
var resource_amount: int = 0
var unit_price: float = 1.0
var total_price: int = 0
var origin_region_id: StringName = &""
var destination_region_id: StringName = &""

var status: StringName = STATUS_OFFERED
var shipment_id: int = -1
var settlement_status: StringName = &"pending"
var failure_reason: String = ""

var created_tick: int = 0
var accepted_tick: int = -1
var settled_tick: int = -1

func _init(
	p_id: int = 0,
	p_buyer: StringName = &"",
	p_seller: StringName = &"",
	p_resource: StringName = &"",
	p_amount: int = 0,
	p_total_price: int = 0,
	p_origin: StringName = &"",
	p_dest: StringName = &"",
	p_tick: int = 0
) -> void:
	id = p_id
	buyer_faction_id = p_buyer
	seller_faction_id = p_seller
	resource_id = p_resource
	resource_amount = maxi(0, p_amount)
	total_price = maxi(0, p_total_price)
	unit_price = float(total_price) / maxf(1.0, float(resource_amount))
	origin_region_id = p_origin
	destination_region_id = p_dest
	created_tick = p_tick
	status = STATUS_OFFERED
	settlement_status = &"pending"

func is_active() -> bool:
	return status in [STATUS_OFFERED, STATUS_ACCEPTED, STATUS_RESERVED, STATUS_IN_TRANSIT, STATUS_DELIVERED]

func is_settled() -> bool:
	return status == STATUS_SETTLED

func transition_to(p_status: StringName, p_reason: String = "", p_tick: int = -1) -> bool:
	if status == p_status:
		return true
	if status in [STATUS_SETTLED, STATUS_CANCELLED, STATUS_FAILED, STATUS_EXPIRED]:
		return false # Terminal states cannot transition

	status = p_status
	if not p_reason.is_empty():
		failure_reason = p_reason

	match p_status:
		STATUS_ACCEPTED:
			accepted_tick = p_tick
		STATUS_SETTLED:
			settled_tick = p_tick
			settlement_status = &"settled"
		STATUS_CANCELLED:
			settled_tick = p_tick
			settlement_status = &"cancelled"
		STATUS_FAILED:
			settled_tick = p_tick
			settlement_status = &"failed"

	return true

func serialize() -> Dictionary:
	return {
		"id": id,
		"buyer_faction_id": str(buyer_faction_id),
		"seller_faction_id": str(seller_faction_id),
		"resource_id": str(resource_id),
		"resource_amount": resource_amount,
		"unit_price": unit_price,
		"total_price": total_price,
		"origin_region_id": str(origin_region_id),
		"destination_region_id": str(destination_region_id),
		"status": str(status),
		"shipment_id": shipment_id,
		"settlement_status": str(settlement_status),
		"failure_reason": failure_reason,
		"created_tick": created_tick,
		"accepted_tick": accepted_tick,
		"settled_tick": settled_tick
	}

static func deserialize(data: Dictionary) -> TradeContract:
	var c := TradeContract.new(
		int(data.get("id", 0)),
		StringName(data.get("buyer_faction_id", "")),
		StringName(data.get("seller_faction_id", "")),
		StringName(data.get("resource_id", "")),
		int(data.get("resource_amount", 0)),
		int(data.get("total_price", 0)),
		StringName(data.get("origin_region_id", "")),
		StringName(data.get("destination_region_id", "")),
		int(data.get("created_tick", 0))
	)
	c.unit_price = float(data.get("unit_price", c.unit_price))
	c.status = StringName(data.get("status", STATUS_OFFERED))
	c.shipment_id = int(data.get("shipment_id", -1))
	c.settlement_status = StringName(data.get("settlement_status", "pending"))
	c.failure_reason = str(data.get("failure_reason", ""))
	c.accepted_tick = int(data.get("accepted_tick", -1))
	c.settled_tick = int(data.get("settled_tick", -1))
	return c
