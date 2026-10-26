class_name DiplomaticProposal
extends RefCounted

const TYPE_TRADE: StringName = &"trade"
const TYPE_AID: StringName = &"aid"
const TYPE_ALLIANCE: StringName = &"alliance"

const STATUS_PENDING: StringName = &"pending"
const STATUS_ACCEPTED: StringName = &"accepted"
const STATUS_REFUSED: StringName = &"refused"
const STATUS_EXPIRED: StringName = &"expired"

var id: int = 0
var from_faction: StringName = &""
var to_faction: StringName = &""
var type: StringName = &""
var terms: Dictionary = {}
var status: StringName = STATUS_PENDING
var created_tick: int = 0
var expires_tick: int = 0
var reason: String = ""
var forecast: String = ""

func _init(
	p_id: int = 0,
	p_from: StringName = &"",
	p_to: StringName = &"",
	p_type: StringName = &"",
	p_terms: Dictionary = {},
	p_created: int = 0,
	p_expires: int = 0,
	p_reason: String = "",
	p_forecast: String = ""
) -> void:
	id = p_id
	from_faction = p_from
	to_faction = p_to
	type = p_type
	terms = p_terms.duplicate(true)
	status = STATUS_PENDING
	created_tick = p_created
	expires_tick = p_expires
	reason = p_reason
	forecast = p_forecast

func serialize() -> Dictionary:
	return {
		"id": id,
		"from_faction": from_faction,
		"to_faction": to_faction,
		"type": type,
		"terms": terms.duplicate(true),
		"status": status,
		"created_tick": created_tick,
		"expires_tick": expires_tick,
		"reason": reason,
		"forecast": forecast
	}

static func deserialize(dict: Dictionary) -> DiplomaticProposal:
	var p := DiplomaticProposal.new(
		int(dict.get("id", 0)),
		dict.get("from_faction", &""),
		dict.get("to_faction", &""),
		dict.get("type", &""),
		dict.get("terms", {}),
		int(dict.get("created_tick", 0)),
		int(dict.get("expires_tick", 0)),
		dict.get("reason", ""),
		dict.get("forecast", "")
	)
	p.status = dict.get("status", STATUS_PENDING)
	return p

func get_title() -> String:
	match type:
		TYPE_TRADE:
			var act: String = terms.get("action", "trade")
			var res: String = str(terms.get("resource_id", "goods")).capitalize()
			var amt: int = int(terms.get("resource_amount", 0))
			var coins: int = int(terms.get("coin_amount", 0))
			if act == "buy":
				return "Trade Offer: Buying %d %s for %d Coins" % [amt, res, coins]
			else:
				return "Trade Offer: Selling %d %s for %d Coins" % [amt, res, coins]
		TYPE_AID:
			var res: String = str(terms.get("resource_id", "supplies")).capitalize()
			var amt: int = int(terms.get("resource_amount", 0))
			return "Urgent Aid Appeal: Requesting %d %s" % [amt, res]
		TYPE_ALLIANCE:
			return "Treaty Proposal: Mutual Defensive Alliance"
		_:
			return "Diplomatic Proposal"
