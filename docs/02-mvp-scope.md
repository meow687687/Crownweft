# 02 — MVP Scope and Acceptance Criteria

## MVP goal
Prove that a small town becomes interesting because production and storage are connected by actual hauling, then prove that poor logistics have consequences during a real-time raid.

**MVP is a playable vertical slice, not a feature-complete kingdom simulator.**

## Core scenario
The player starts with a Town Hall, a small workforce, modest supplies and a seeded valley. They must establish food and construction-material production, keep households supplied, grow the settlement, set a tax level, recruit a small force and survive one enemy raid.

## Target boundaries
- One seeded procedural map per run, approximately 96×96 tiles for the first balance target.
- 30–60 simulated residents, not thousands.
- One player settlement and one nearby raider camp/outpost.
- One biome palette initially: temperate valley with grass, forest, rock and water.
- Pause and 1× / 2× / 3× speed.
- Target 60 FPS on reasonable desktop hardware; profile rather than promise a fixed spec prematurely.

## Buildings
1. **Town Hall** — civic center, tax setting, treasury/approval display.
2. **House** — increases resident capacity.
3. **Farm** — produces grain when staffed and fertile.
4. **Woodcutter Camp** — harvests timber from nearby forest.
5. **Quarry** — extracts stone from a valid deposit.
6. **Bakery** — consumes grain and produces bread.
7. **Storehouse / Granary** — physical inventory; food-capable storehouses serve nearby households.
8. **Barracks** — recruits and maintains initial military units.
9. **Road** — improves movement cost and hauling efficiency.

Do not add more buildings until the food and construction-material loops work end to end.

## Resources
- **Grain:** farm output and bakery input.
- **Bread:** household food and military rations.
- **Timber:** construction input and early infrastructure.
- **Stone:** construction and fortification input.
- **Coin:** treasury, taxes and recruitment/upkeep accounting.

No iron, tools, luxury goods, horses, influence points, research points or resource subtypes in MVP. Add them only when they create a necessary decision.

## Citizens and work
- Citizens have a small explicit state: housed/homeless, assigned/unassigned, working/idle, fed/at-risk.
- Initial roles: farm worker, woodcutter, quarry worker, baker, hauler, soldier.
- Citizens walk between jobs and relevant locations using grid pathfinding.
- Residents consume bread through a local food-access rule, not a fully simulated dining/social schedule.
- Do not simulate detailed personalities, family trees or private inventories.

## Logistics — the MVP's most important system
- Every producer, consumer and storage building owns a local inventory with capacity.
- Producers add output to their own inventory, not a global resource counter.
- Consumer buildings request inputs when below a configured threshold.
- A central Job Board creates hauling jobs containing resource, source, destination, amount, priority and reservation state.
- Haulers claim jobs, reserve stock and destination capacity, walk to source, pick up a bounded amount, move to destination, deliver and release reservations.
- A job must fail or retry safely if its path becomes blocked or its source disappears.
- UI stock totals are derived from local inventories and distinguish accessible from blocked stock.
- Basic hauling overlay: source, destination, assigned hauler, job state and blocked reason.

**Not in MVP:** dynamic road congestion, multi-stop optimization, rail/river networks, trade convoys, per-item weight/volume, spoilage, or market-clearing economics.

## Economy and stability
- Production recipes have inputs, outputs, worker requirement and production interval.
- Construction consumes physical timber/stone when construction begins; no fictional infinite global pool.
- Treasury receives simple periodic income derived from population and tax level, with a visible formula.
- Tax choice has three levels: low, normal, high. Higher tax increases income but lowers approval; effects are visible and explainable.
- Food shortages gradually raise an at-risk/unrest indicator. MVP does not include faction-driven revolts.
- Household provisioning uses local storehouse/market coverage to keep the simulation tractable.

## Military
- Two playable unit types: spearmen and archers.
- One small enemy raider force with simple behavior: approach, attack a target, retreat or be defeated.
- Select one or more units; right-click move; attack-move or target attack.
- Units have health, speed, range where appropriate, attack cooldown and target state.
- Barracks recruitment consumes coin; upkeep consumes bread/coin.
- A raid can target exposed buildings or stores. Give the player a visible warning and time to respond.
- Combat is real-time and commandable, but the first encounter is one compact raid, not a multi-front campaign.

**Not in MVP:** siege engines, naval warfare, complex formations, morale cascades, battlefield terrain beyond movement blockers, enemy diplomacy, multi-army campaigns or hundreds of units.

## Procedural map generation
- A seed produces consistent terrain and resource placement.
- Terrain types: grass, forest, rock and water; fertility is stored separately from tile type.
- Guarantee a valid starting area with buildable land, fertile tiles, trees, stone and water edge where possible.
- Place the enemy camp outside the immediate start area but reachable by a valid path.
- Validate connectivity and starting-resource constraints; regenerate if validation fails.
- Save the seed and generator version with each save.
- One biome and simple noise/cluster placement initially; no multi-continent generator.

## Required UI
- Main map with pan, zoom, tile/building selection and build palette.
- Resource stockpile totals plus accessible/blocked distinction.
- Selected building panel: workers, inventory, recipe, output, input shortage and priority.
- Construction cost shown before placement.
- Citizen/job counts and idle-worker signal.
- Logistics overlay.
- Treasury, tax level, public approval and food status.
- Military selection, health and order feedback.
- Pause/speed control, save/load and visible shortage/error messages.

## Definition of done
MVP is accepted only when all criteria pass:
1. A new seed creates a playable valley; the same seed produces the same layout for the same generator version.
2. The player can place all MVP buildings.
3. Farm grain is physically hauled to the bakery; bakery output is physically hauled to a food store.
4. If a route is blocked, the input shortage appears and production halts for an explainable reason.
5. A full destination cannot accept more goods; resources do not disappear or duplicate during interrupted/cancelled jobs.
6. Citizens consume accessible food; shortage changes visible settlement state.
7. Tax changes treasury income and public approval with a displayed, testable rule.
8. Player can select and command spearmen/archers in real time.
9. Raiders can damage a building or stockpile; player units can repel the raid.
10. Save/load preserves seed, buildings, inventories, assignments, units, treasury and time; jobs are restored or safely reconstructed.
11. Debug overlays show job queues, blocked paths, inventories and production blockers.
12. No blocker prevents a 20–30-minute end-to-end playtest.

## Deferred beyond MVP
Deep politics/factions, treaties, multiple settlements, regional trade, dynasties, advanced military, research trees, larger populations, seasons, disease, religion, modding, campaign story and multiplayer.

## Release slice
One coherent scenario: grow a village, solve a supply bottleneck, sustain a food surplus and survive one raid.
