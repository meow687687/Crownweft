class_name IncidentCatalog
extends RefCounted

const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")

const INCIDENT_HUNGRY_SETTLEMENT: StringName = &"hungry_settlement"
const INCIDENT_REALM_GRIEVANCE: StringName = &"realm_grievance"
const INCIDENT_FRONTIER_TROUBLE: StringName = &"frontier_trouble"

const INCIDENT_IDS: Array[StringName] = [
	INCIDENT_HUNGRY_SETTLEMENT,
	INCIDENT_REALM_GRIEVANCE,
	INCIDENT_FRONTIER_TROUBLE
]

const DEFAULT_COOLDOWN_TICKS: int = 120

static func get_all_defs() -> Dictionary:
	return {
		INCIDENT_HUNGRY_SETTLEMENT: {
			"id": INCIDENT_HUNGRY_SETTLEMENT,
			"title": "The Hungry Settlement",
			"urgency": &"high",
			"description": "Food stocks have fallen dangerously low, leaving citizens facing hunger. Without intervention, citizen stamina and public approval will suffer.",
			"cause_template": "Depleted food reserves in settlement storage. %d citizens are currently hungry or at risk.",
			"options": [
				{
					"id": &"strict_rationing",
					"title": "Enact Strict Rationing Decree",
					"description": "Impose strict rationing across the settlement to stretch remaining bread and meat reserves.",
					"consequence_preview": "Enacts Strict Rationing policy. Reduces food consumption, but causes immediate -5% public approval discontent.",
					"policy_change": {
						"law_id": LawCatalog.LAW_RATIONING,
						"option_id": &"strict"
					},
					"approval_delta": -5.0,
					"action_key": &"enact_policy"
				},
				{
					"id": &"prioritize_agriculture",
					"title": "Prioritize Agriculture & Bakery Logistics",
					"description": "Mobilize the settlement by maximizing work priority on all farms and bakeries.",
					"consequence_preview": "Sets work priority to Maximum (5) for all active Farms and Bakeries. Focuses workforce on food replenishment.",
					"approval_delta": 0.0,
					"action_key": &"prioritize_food"
				},
				{
					"id": &"emergency_relief",
					"title": "Purchase Emergency Relief Grain",
					"description": "Spend 25 Coin from the treasury to purchase emergency food shipments from realm traders.",
					"consequence_preview": "Deducts 25 Coin from Town Hall, immediately adds 15 Bread to food stocks.",
					"cost": {
						"coin": 25
					},
					"approval_delta": 2.0,
					"adds_resource": {
						"bread": 15
					},
					"action_key": &"relief_purchase"
				}
			]
		},
		INCIDENT_REALM_GRIEVANCE: {
			"id": INCIDENT_REALM_GRIEVANCE,
			"title": "A Grievance in the Realm",
			"urgency": &"medium",
			"description": "Public discontent has reached a boiling point. The populace is openly questioning royal decrees, threatening civil cooperation.",
			"cause_template": "Public approval has remained depressed (currently at %d%%) due to heavy taxation, unmet needs, or austere decrees.",
			"options": [
				{
					"id": &"lower_taxes",
					"title": "Lower Crown Taxes",
					"description": "Ease the crown tax burden on the common folk to restore public faith in sovereign leadership.",
					"consequence_preview": "Enacts Low Taxation decree (1C tax per cycle). Grants an immediate +15% boost to public approval.",
					"policy_change": {
						"law_id": LawCatalog.LAW_TAXATION,
						"option_id": &"low"
					},
					"approval_delta": 15.0,
					"action_key": &"enact_policy"
				},
				{
					"id": &"generous_rations",
					"title": "Proclaim Generous Rations",
					"description": "Declare a festival of generous food distribution from town stores to placate the disgruntled citizens.",
					"consequence_preview": "Enacts Generous Rationing decree. Grants +10% approval, but increases daily food consumption rates.",
					"policy_change": {
						"law_id": LawCatalog.LAW_RATIONING,
						"option_id": &"generous"
					},
					"approval_delta": 10.0,
					"action_key": &"enact_policy"
				},
				{
					"id": &"reaffirm_authority",
					"title": "Reaffirm Crown Sovereignty",
					"description": "Dismiss populist grievances and mandate strict obedience to existing crown statutes.",
					"consequence_preview": "Maintains current decrees firmly. Stifles open dissent but inflicts an immediate -5% approval penalty.",
					"approval_delta": -5.0,
					"action_key": &"reaffirm"
				}
			]
		},
		INCIDENT_FRONTIER_TROUBLE: {
			"id": INCIDENT_FRONTIER_TROUBLE,
			"title": "Trouble on the Frontier",
			"urgency": &"high",
			"description": "Strategic reports from the frontier indicate growing military tensions. Frontier forces face supply attrition or hostile maneuvers.",
			"cause_template": "Hostile forces or extended expeditions have strained regional armies. Army supplies are depleted.",
			"options": [
				{
					"id": &"resupply_army",
					"title": "Dispatch Emergency Army Supplies",
					"description": "Requisition 20 gold coin and 10 food from Town Hall to resupply the frontier expedition.",
					"consequence_preview": "Deducts 20 coin and 10 food from Town Hall inventory. Adds +20 supplies directly to the Royal Army.",
					"cost": {
						"coin": 20,
						"food": 10
					},
					"army_supplies_delta": 20.0,
					"action_key": &"resupply_army"
				},
				{
					"id": &"diplomatic_overture",
					"title": "Propose Economic Cooperation Overture",
					"description": "Send diplomatic emissaries to neighboring powers offering economic concessions to ease tensions.",
					"consequence_preview": "Improves diplomatic economic cooperation by +10 with non-hostile neighbors. Prevents immediate escalation.",
					"diplomacy_delta": 10.0,
					"action_key": &"diplomatic_overture"
				},
				{
					"id": &"conserve_resources",
					"title": "Consolidate Settlement Defenses",
					"description": "Conserve all local supplies for the town, leaving the frontier expedition to live off the land.",
					"consequence_preview": "Preserves settlement coin and food. Regional army incurs -10 supply attrition penalty.",
					"army_supplies_delta": -10.0,
					"action_key": &"conserve"
				}
			]
		}
	}

static func get_incident_def(id: StringName) -> Dictionary:
	var defs: Dictionary = get_all_defs()
	return defs.get(id, {})

static func get_option_def(incident_id: StringName, option_id: StringName) -> Dictionary:
	var inc_def: Dictionary = get_incident_def(incident_id)
	var options: Array = inc_def.get("options", [])
	for opt in options:
		if opt is Dictionary and opt.get("id", &"") == option_id:
			return opt
	return {}
