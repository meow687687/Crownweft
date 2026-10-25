# 04 — Core Data Model

Implement only the records needed for the current milestone; this is the initial contract, not a demand to create every class immediately.

## Identity
Use stable integer IDs for runtime entities and string IDs for resource/building/unit definitions. Do not use display names or NodePaths as identity.

## WorldTile
- `coord: Vector2i`
- `terrain_id: StringName`
- `fertility: float` (0–1)
- `resource_deposit_id: StringName` (optional)
- `building_id: int` (optional)
- `road_level: int`
- `movement_flags`
- `is_buildable: bool`

## ResourceDef
`id`, `display_name`, `icon`, optional `stack_limit`, `is_food`, `build_cost_allowed`, `debug_color`. No market-price system unless an actual MVP rule needs it.

## Inventory
- `owner_id`, `capacity`
- `quantities: Dictionary<ResourceId, int>`
- `reserved_out` and `reserved_in` per resource
- accepted/rejected resource IDs

Invariants:
- Quantities never go negative.
- Available outgoing = quantity − reserved_out.
- Free capacity accounts for reserved_in.
- Transfers validate both inventories before mutating either; success is atomic.
- Cancellation releases reservations exactly once.

## BuildingDef / BuildingState
**Definition:** ID, footprint, build cost, worker slots, recipe IDs, inventory capacity, passability, terrain/resource requirements, service radius, construction time, upkeep, render asset key.

**State:** entity ID, definition ID, tile origin, construction progress, assigned workers, inventory ID, enabled flag, priority profile, current block reason, production progress.

## RecipeDef
ID, input quantities, output quantities, required workers, duration ticks, optional fertility/terrain/resource constraints.

Rules: a cycle cannot start unless inputs and output capacity are feasible; inputs are consumed under a single documented rule; output enters the producing building's inventory; missing inputs/workers/full outputs have distinct block reasons.

## CitizenState
ID, home building ID, workplace ID, role ID, position tile, movement state, food state, carried resource/amount, active job ID, status flags.

MVP deliberately excludes personality, family relations, beliefs and long-term memory.

## HaulJob
ID, resource ID, amount, source inventory ID, destination inventory ID, priority, status, assigned citizen ID, reserved amount, created tick, retry tick, blocked reason.

Invariant: each reservation has one authoritative owner and a job transition releases/transfers it atomically.

## MilitaryUnitState
ID, unit definition ID, faction ID, position, health, current order, optional target ID, cooldown, food upkeep, status flags. Unit definitions carry speed, damage, range, cooldown, recruitment cost and asset key.

## FactionState
MVP: player settlement and one raider faction; each has a faction ID, hostility state, home/camp position, raid cooldown and target-selection rule. Diplomacy and faction interests come later.

## EconomyState
Treasury, tax level (`LOW`, `NORMAL`, `HIGH`), approval (0–100), periodic tax counter, last income breakdown. Tax/approval formulas live in one tested balance rule, never separately in UI and simulation.

## Resource transaction reasons
`PRODUCTION_OUTPUT`, `PRODUCTION_INPUT`, `HAUL_TRANSFER`, `CONSUMPTION`, `CONSTRUCTION`, `TAX_INCOME`, `WAGE_OR_UPKEEP`, `RECRUITMENT`, and `COMBAT_LOSS` only if dropped goods are modeled.

Debug builds should keep a bounded transaction log to detect duplication/disappearance. This is a developer diagnostic, not a user-facing blockchain/ledger feature.

## Save contract
Do not serialize live Node references. Serialize IDs and data-only records; re-link references after load. Include `schema_version` and `generator_version`.
