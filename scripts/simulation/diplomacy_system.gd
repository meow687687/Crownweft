class_name DiplomacySystem
extends RefCounted

const DECISION_INTERVAL_TICKS: int = 24
const PROPOSAL_LIFESPAN_TICKS: int = 120
const ACTION_COOLDOWN_TICKS: int = 72

# Candidate Action IDs
const ACTION_NONE: StringName = &"none"
const ACTION_TRADE_SELL: StringName = &"trade_sell"
const ACTION_TRADE_BUY: StringName = &"trade_buy"
const ACTION_REQUEST_AID: StringName = &"request_aid"
const ACTION_PROPOSE_ALLIANCE: StringName = &"propose_alliance"

func tick_diplomacy(
	diplomacy: DiplomacyState,
	current_tick: int,
	player_inventory: Inventory = null,
	economy: EconomyState = null,
	government: GovernmentState = null
) -> void:
	if diplomacy == null:
		return

	# 1. Decay memories and cleanup expired treaties / proposals
	for f_id in diplomacy.factions:
		var faction: FactionState = diplomacy.factions[f_id]
		faction.decay_memories(current_tick)
		faction.clean_expired_treaties(current_tick)

	# Clean expired proposals
	var valid_props: Array[DiplomaticProposal] = []
	for p in diplomacy.pending_proposals:
		if p.expires_tick > 0 and current_tick >= p.expires_tick:
			p.status = DiplomaticProposal.STATUS_EXPIRED
			diplomacy.add_chronicle(current_tick, "Proposal from %s expired without formal resolution." % [
				diplomacy.factions.get(p.from_faction, FactionState.new()).display_name
			], &"expiration")
		else:
			valid_props.append(p)
	diplomacy.pending_proposals = valid_props

	# 2. Schedule AI decisions
	if current_tick % DECISION_INTERVAL_TICKS != 0:
		return

	for f_id in FactionCatalog.NEIGHBOUR_FACTION_IDS:
		var faction: FactionState = diplomacy.factions.get(f_id, null)
		if faction == null:
			continue
		
		# Skip if faction already has an outstanding proposal pending
		if _has_pending_proposal_from(diplomacy, f_id):
			continue

		# Evaluate candidates
		_evaluate_and_execute_agent_decision(diplomacy, faction, current_tick, government)

func _has_pending_proposal_from(diplomacy: DiplomacyState, f_id: StringName) -> bool:
	for p in diplomacy.pending_proposals:
		if p.from_faction == f_id and p.status == DiplomaticProposal.STATUS_PENDING:
			return true
	return false

func _evaluate_and_execute_agent_decision(
	diplomacy: DiplomacyState,
	faction: FactionState,
	current_tick: int,
	government: GovernmentState
) -> void:
	var target_id: StringName = FactionCatalog.FACTION_PLAYER
	var rel: DiplomaticRelationship = diplomacy.get_relationship(faction.id, target_id)
	
	var candidates: Array[Dictionary] = _generate_candidate_actions(diplomacy, faction, rel, current_tick, government)
	if candidates.is_empty():
		return

	var best_candidate: Dictionary = {}
	var highest_utility: float = -999.0

	for cand in candidates:
		var score_dict: Dictionary = _calculate_utility(diplomacy, faction, rel, cand, government)
		cand["score_breakdown"] = score_dict
		var total_score: float = score_dict["total"]
		if total_score > highest_utility:
			highest_utility = total_score
			best_candidate = cand

	faction.last_decision_tick = current_tick
	faction.last_utility_breakdown = {
		"tick": current_tick,
		"target": target_id,
		"candidates_evaluated": candidates.size(),
		"chosen_action": best_candidate.get("action_id", ACTION_NONE),
		"utility": highest_utility,
		"breakdown": best_candidate.get("score_breakdown", {})
	}

	# Execute if score exceeds viability threshold
	if highest_utility >= 20.0 and best_candidate.get("action_id", ACTION_NONE) != ACTION_NONE:
		_dispatch_candidate_action(diplomacy, faction, target_id, best_candidate, current_tick)

func _generate_candidate_actions(
	diplomacy: DiplomacyState,
	faction: FactionState,
	rel: DiplomaticRelationship,
	current_tick: int,
	government: GovernmentState
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	# Default baseline candidate
	candidates.append({
		"action_id": ACTION_NONE,
		"description": "Maintain status quo and monitor borders."
	})

	# 1. Aid Request candidate: if food is scarce and trust is not hostile
	var food_amt: int = int(faction.resources.get(&"grain", 0))
	if food_amt <= 20 and not faction.is_on_cooldown(&"aid", current_tick) and rel.resentment < 50.0:
		candidates.append({
			"action_id": ACTION_REQUEST_AID,
			"resource_id": &"grain",
			"resource_amount": 10,
			"is_critical": food_amt <= 10,
			"description": "Appeal for 10 grain to replenish critically depleted granaries."
		})

	# 2. Trade Sell candidate: if faction has surplus resources
	var surplus_res: StringName = &""
	var surplus_amt: int = 0
	for r_id in [&"timber", &"stone", &"grain"]:
		var amt: int = int(faction.resources.get(r_id, 0))
		if amt >= 40:
			surplus_res = r_id
			surplus_amt = 15
			break
	if surplus_res != &"" and not faction.is_on_cooldown(&"trade", current_tick):
		var price: int = 15 if surplus_res != &"grain" else 20
		candidates.append({
			"action_id": ACTION_TRADE_SELL,
			"resource_id": surplus_res,
			"resource_amount": surplus_amt,
			"coin_amount": price,
			"description": "Sell %d surplus %s for %d coins." % [surplus_amt, str(surplus_res).capitalize(), price]
		})

	# 3. Trade Buy candidate: if faction has treasury and wants mineral/timber/grain goods
	if faction.treasury >= 30 and not faction.is_on_cooldown(&"trade", current_tick):
		var deficit_res: StringName = &""
		for r_id in [&"stone", &"timber", &"grain"]:
			var amt: int = int(faction.resources.get(r_id, 0))
			if amt < 25:
				deficit_res = r_id
				break
		if deficit_res != &"":
			candidates.append({
				"action_id": ACTION_TRADE_BUY,
				"resource_id": deficit_res,
				"resource_amount": 10,
				"coin_amount": 18,
				"description": "Purchase 10 %s for 18 coins." % str(deficit_res).capitalize()
			})

	# 4. Alliance Proposal candidate: if mutual trust and respect are high
	if rel.trust >= 25.0 and rel.resentment <= 15.0 and not faction.has_active_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER):
		if not faction.is_on_cooldown(&"alliance", current_tick):
			candidates.append({
				"action_id": ACTION_PROPOSE_ALLIANCE,
				"duration_ticks": 600,
				"description": "Propose a formal mutual defensive alliance pact."
			})

	return candidates

func _calculate_utility(
	diplomacy: DiplomacyState,
	faction: FactionState,
	rel: DiplomaticRelationship,
	candidate: Dictionary,
	government: GovernmentState
) -> Dictionary:
	var action_id: StringName = candidate.get("action_id", ACTION_NONE)
	if action_id == ACTION_NONE:
		return {
			"goal_fit": 0.0,
			"expected_benefit": 0.0,
			"relationship_effect": 0.0,
			"doctrine_fit": 0.0,
			"resource_cost": 0.0,
			"risk": 0.0,
			"opportunity_cost": 0.0,
			"total": 0.0
		}

	var goal_fit: float = 0.0
	var benefit: float = 0.0
	var rel_effect: float = 0.0
	var doctrine_fit: float = 0.0
	var cost: float = 0.0
	var risk: float = 0.0
	var opp_cost: float = 0.0

	match action_id:
		ACTION_REQUEST_AID:
			if faction.active_goals.has(FactionCatalog.GOAL_SECURE_FOOD):
				goal_fit += 40.0
			benefit += 30.0 # Food relief
			rel_effect += (rel.trust * 0.15) # High trust makes asking easier
			if faction.doctrine == &"sylvan_harmony":
				doctrine_fit += 15.0 # Values community sustenance
			elif faction.doctrine == &"martial_tradition":
				doctrine_fit -= 10.0 # Proud highland warriors dislike begging
			cost += 0.0
			risk += (rel.resentment * 0.3) # Risk of humiliating refusal
			opp_cost += 5.0

		ACTION_TRADE_SELL:
			if faction.active_goals.has(FactionCatalog.GOAL_ECONOMIC_STABILITY):
				goal_fit += 25.0
			if faction.active_goals.has(FactionCatalog.GOAL_ESTABLISH_TRADE):
				goal_fit += 20.0
			benefit += float(candidate.get("coin_amount", 15))
			rel_effect += 10.0 + (rel.economic_cooperation * 0.1)
			if faction.doctrine == &"communal_labor":
				doctrine_fit += 10.0
			cost += 5.0 # Value of exported surplus
			risk += 0.0
			opp_cost += 5.0

		ACTION_TRADE_BUY:
			if faction.active_goals.has(FactionCatalog.GOAL_SECURE_FOOD) and candidate.get("resource_id", &"") == &"grain":
				goal_fit += 35.0
			elif faction.active_goals.has(FactionCatalog.GOAL_ESTABLISH_TRADE):
				goal_fit += 20.0
			benefit += 25.0
			rel_effect += 10.0 + (rel.economic_cooperation * 0.1)
			if faction.doctrine == &"communal_labor":
				doctrine_fit += 10.0
			cost += float(candidate.get("coin_amount", 18)) * 0.8
			risk += 0.0
			opp_cost += 5.0

		ACTION_PROPOSE_ALLIANCE:
			if faction.active_goals.has(FactionCatalog.GOAL_STRENGTHEN_RELATIONS):
				goal_fit += 35.0
			if faction.active_goals.has(FactionCatalog.GOAL_PROTECT_BORDERS):
				goal_fit += 30.0
			benefit += 30.0 # Mutual defense deterrence
			rel_effect += (rel.trust * 0.3) + (rel.respect * 0.2)
			if faction.doctrine == &"martial_tradition":
				doctrine_fit += 25.0
			elif faction.doctrine == &"sylvan_harmony":
				doctrine_fit += 10.0
			cost += 0.0
			risk += (rel.threat * 0.2)
			opp_cost += 10.0

	var total: float = goal_fit + benefit + rel_effect + doctrine_fit - cost - risk - opp_cost
	return {
		"goal_fit": goal_fit,
		"expected_benefit": benefit,
		"relationship_effect": rel_effect,
		"doctrine_fit": doctrine_fit,
		"resource_cost": cost,
		"risk": risk,
		"opportunity_cost": opp_cost,
		"total": total
	}

func _dispatch_candidate_action(
	diplomacy: DiplomacyState,
	faction: FactionState,
	target_id: StringName,
	candidate: Dictionary,
	current_tick: int
) -> void:
	var action_id: StringName = candidate.get("action_id", ACTION_NONE)
	var prop := DiplomaticProposal.new()
	prop.from_faction = faction.id
	prop.to_faction = target_id
	prop.created_tick = current_tick
	prop.expires_tick = current_tick + PROPOSAL_LIFESPAN_TICKS

	match action_id:
		ACTION_REQUEST_AID:
			prop.type = DiplomaticProposal.TYPE_AID
			prop.terms = {
				"resource_id": candidate.get("resource_id", &"grain"),
				"resource_amount": candidate.get("resource_amount", 10),
				"is_critical": candidate.get("is_critical", false)
			}
			prop.reason = "%s appeals for %d %s aid to overcome local supply shortages." % [
				faction.display_name,
				prop.terms["resource_amount"],
				str(prop.terms["resource_id"]).capitalize()
			]
			prop.forecast = "Accepting provides food relief (+20 Trust, +10 Respect). Refusing deepens hardship (+20 Resentment, -15 Trust)."
			faction.set_cooldown(&"aid", current_tick + ACTION_COOLDOWN_TICKS)

		ACTION_TRADE_SELL:
			prop.type = DiplomaticProposal.TYPE_TRADE
			prop.terms = {
				"action": "sell",
				"resource_id": candidate.get("resource_id", &"timber"),
				"resource_amount": candidate.get("resource_amount", 15),
				"coin_amount": candidate.get("coin_amount", 15)
			}
			prop.reason = "%s offers to deliver %d %s in exchange for %d Crown coins." % [
				faction.display_name,
				prop.terms["resource_amount"],
				str(prop.terms["resource_id"]).capitalize(),
				prop.terms["coin_amount"]
			]
			prop.forecast = "Accepting transfers resources to Crown storehouses (+10 Trust, +15 Cooperation). Refusing maintains coin reserves (+5 Resentment)."
			faction.set_cooldown(&"trade", current_tick + ACTION_COOLDOWN_TICKS)

		ACTION_TRADE_BUY:
			prop.type = DiplomaticProposal.TYPE_TRADE
			prop.terms = {
				"action": "buy",
				"resource_id": candidate.get("resource_id", &"stone"),
				"resource_amount": candidate.get("resource_amount", 10),
				"coin_amount": candidate.get("coin_amount", 18)
			}
			prop.reason = "%s seeks to purchase %d %s, offering %d coins from their regional treasury." % [
				faction.display_name,
				prop.terms["resource_amount"],
				str(prop.terms["resource_id"]).capitalize(),
				prop.terms["coin_amount"]
			]
			prop.forecast = "Accepting exports goods for treasury coin (+10 Trust, +15 Cooperation). Refusing preserves goods locally."
			faction.set_cooldown(&"trade", current_tick + ACTION_COOLDOWN_TICKS)

		ACTION_PROPOSE_ALLIANCE:
			prop.type = DiplomaticProposal.TYPE_ALLIANCE
			prop.terms = {
				"treaty_type": &"defensive_pact",
				"duration_ticks": candidate.get("duration_ticks", 600)
			}
			prop.reason = "%s proposes ratifying a mutual defensive alliance to deter regional aggressors." % [
				faction.display_name
			]
			prop.forecast = "Accepting seals a 600-tick alliance (+25 Trust, +15 Respect, +4 Settlement Approval). Refusing rebuffs overture (+5 Resentment)."
			faction.set_cooldown(&"alliance", current_tick + ACTION_COOLDOWN_TICKS * 2)

	diplomacy.add_proposal(prop)
	diplomacy.add_chronicle(current_tick, "Received %s from %s." % [
		prop.get_title(),
		faction.display_name
	], &"proposal")

func resolve_player_response(
	diplomacy: DiplomacyState,
	proposal_id: int,
	accept: bool,
	player_inventory: Inventory,
	economy: EconomyState,
	current_tick: int
) -> Dictionary:
	var prop: DiplomaticProposal = diplomacy.find_proposal(proposal_id)
	if prop == null:
		return {"ok": false, "reason": "Proposal not found or expired"}
	if prop.status != DiplomaticProposal.STATUS_PENDING:
		return {"ok": false, "reason": "Proposal already resolved"}

	var from_fac: FactionState = diplomacy.factions.get(prop.from_faction, null)
	if from_fac == null:
		return {"ok": false, "reason": "Invalid originating faction"}

	var rel: DiplomaticRelationship = diplomacy.get_relationship(prop.from_faction, FactionCatalog.FACTION_PLAYER)

	if accept:
		match prop.type:
			DiplomaticProposal.TYPE_AID:
				var res_id: StringName = prop.terms.get("resource_id", &"grain")
				var amt: int = int(prop.terms.get("resource_amount", 10))
				if player_inventory == null or player_inventory.get_available_outgoing(res_id) < amt:
					return {"ok": false, "reason": "Insufficient supplies in Town storage to provide aid"}
				
				# Transfer physical resource
				player_inventory.remove_resource(res_id, amt, "DIPLOMACY: AID PROVIDED")
				from_fac.resources[res_id] = int(from_fac.resources.get(res_id, 0)) + amt

				rel.modify_trust(20.0)
				rel.modify_respect(10.0)
				rel.modify_threat(-5.0)
				rel.modify_resentment(-10.0)

				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"aid_received",
					float(amt),
					"The Crown graciously supplied emergency %s aid during our deficit." % str(res_id),
					600
				)
				diplomacy.add_chronicle(current_tick, "The Crown delivered %d %s aid to %s, securing lasting gratitude." % [
					amt, str(res_id).capitalize(), from_fac.display_name
				], &"aid_accepted")

			DiplomaticProposal.TYPE_TRADE:
				var act: String = prop.terms.get("action", "sell")
				var res_id: StringName = prop.terms.get("resource_id", &"timber")
				var amt: int = int(prop.terms.get("resource_amount", 10))
				var coins: int = int(prop.terms.get("coin_amount", 15))

				if act == "sell":
					# AI is selling to Player: Player pays coins, receives goods
					if player_inventory == null or player_inventory.get_available_outgoing(&"coin") < coins:
						return {"ok": false, "reason": "Insufficient coins in Town storage to purchase trade goods"}
					if player_inventory.get_free_capacity() < amt:
						return {"ok": false, "reason": "Insufficient storage capacity to receive trade goods"}

					player_inventory.remove_resource(&"coin", coins, "DIPLOMACY: TRADE COIN PAYMENT")
					from_fac.treasury += coins
					from_fac.resources[res_id] = maxi(0, int(from_fac.resources.get(res_id, 0)) - amt)
					player_inventory.add_resource(res_id, amt, "DIPLOMACY: TRADE IMPORT")

				else:
					# AI is buying from Player: Player provides goods, receives coins
					if player_inventory == null or player_inventory.get_available_outgoing(res_id) < amt:
						return {"ok": false, "reason": "Insufficient goods in storage to fulfill trade sale"}
					if player_inventory.get_free_capacity() < coins:
						return {"ok": false, "reason": "Insufficient storage capacity to receive coin payment"}

					player_inventory.remove_resource(res_id, amt, "DIPLOMACY: TRADE EXPORT")
					from_fac.resources[res_id] = int(from_fac.resources.get(res_id, 0)) + amt
					from_fac.treasury = maxi(0, from_fac.treasury - coins)
					player_inventory.add_resource(&"coin", coins, "DIPLOMACY: TRADE COIN EARNED")

				rel.modify_trust(10.0)
				rel.modify_cooperation(15.0)

				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"trade_completed",
					float(coins),
					"Honoured trade agreement and exchanged valuable commodities.",
					600
				)
				diplomacy.add_chronicle(current_tick, "Trade concluded with %s for %d %s (%d coins)." % [
					from_fac.display_name, amt, str(res_id).capitalize(), coins
				], &"trade_accepted")

			DiplomaticProposal.TYPE_ALLIANCE:
				var duration: int = int(prop.terms.get("duration_ticks", 600))
				from_fac.add_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER, current_tick, duration)
				var player_fac: FactionState = diplomacy.factions.get(FactionCatalog.FACTION_PLAYER, null)
				if player_fac != null:
					player_fac.add_treaty(&"defensive_pact", from_fac.id, current_tick, duration)

				rel.modify_trust(25.0)
				rel.modify_respect(15.0)
				rel.modify_threat(-15.0)
				rel.modify_resentment(-5.0)

				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"alliance_formed",
					40.0,
					"Formed a binding mutual defensive alliance.",
					duration
				)
				diplomacy.add_chronicle(current_tick, "The Crown and %s ratified a mutual defensive alliance treaty." % [
					from_fac.display_name
				], &"alliance_accepted")

		prop.status = DiplomaticProposal.STATUS_ACCEPTED

	else:
		# Player Refused
		match prop.type:
			DiplomaticProposal.TYPE_AID:
				rel.modify_resentment(20.0)
				rel.modify_trust(-15.0)
				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"aid_refused",
					25.0,
					"The Crown refused emergency relief, leaving our people to endure famine.",
					600
				)
				diplomacy.add_chronicle(current_tick, "The Crown refused emergency aid to %s, sparking bitter resentment." % [
					from_fac.display_name
				], &"aid_refused")

			DiplomaticProposal.TYPE_TRADE:
				rel.modify_resentment(5.0)
				rel.modify_trust(-2.0)
				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"trade_refused",
					10.0,
					"The Crown turned away our trade caravan.",
					400
				)
				diplomacy.add_chronicle(current_tick, "The Crown turned away a trade proposal from %s." % [
					from_fac.display_name
				], &"trade_refused")

			DiplomaticProposal.TYPE_ALLIANCE:
				rel.modify_resentment(5.0)
				rel.modify_respect(-5.0)
				from_fac.add_memory(
					current_tick,
					FactionCatalog.FACTION_PLAYER,
					from_fac.id,
					&"alliance_refused",
					20.0,
					"The Crown rejected our proposed defensive alliance.",
					500
				)
				diplomacy.add_chronicle(current_tick, "The Crown declined an alliance treaty proposed by %s." % [
					from_fac.display_name
				], &"alliance_refused")

		prop.status = DiplomaticProposal.STATUS_REFUSED

	diplomacy.remove_proposal(prop.id)
	return {"ok": true, "status": prop.status}
