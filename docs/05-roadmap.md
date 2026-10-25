# 05 — Phased Roadmap

Roadmap uses exit gates rather than calendar promises. Do not advance to the next phase merely because a date arrived.

## Phase 0 — Simulation proof
**Goal:** prove a production chain without polished town visuals.

Build: fixed test map, data definitions, local inventories, farm→grain, bakery→bread, storehouse, one hauler, reservation/job lifecycle and debug trace.

**Exit gate:** inventory cannot go negative or exceed capacity; blocked route/source/destination cases recover safely; the chain works without manual resource injection after starting stock is set; tests cover transfer atomicity, reservations and cancellation.

Do not start pixel-art production, procedural generation or combat before this gate passes.

## Phase 1 — Playable settlement loop
**Goal:** a town can grow and sustain a small population.

Build: seeded 96×96 map, generator validation, camera, selection/build placement, roads, construction costs, 30–60 citizens, MVP buildings, production/hauling, food access/consumption, shortage UI, debug overlays, pause/speed control.

**Exit gate:** a new player builds a working food chain; a forced shortage is explainable; seeded maps provide valid starting resources and connectivity; a 20-minute playtest has no repeated blocking failure or resource duplication.

## Phase 2 — Military vertical slice
**Goal:** make logistics matter under immediate pressure.

Build: barracks, recruitment/upkeep, spearmen and archers, unit selection/move/attack-move/target attack, simple raid AI, raid warning, target selection and post-battle recovery.

**Exit gate:** player trains a force, responds to a raid, commands units and recovers; ignoring food/logistics is measurably worse than planning; combat uses the same world and pause/speed model.

## Phase 3 — Stability, policy and presentation
**Goal:** make the slice understandable and robust.

Build: three-level tax policy, treasury report, approval indicator, reason-coded tooltips, coherent pixel-art set, save/load and schema versioning, tutorial prompts, basic audio/UI feedback, seed/reproduction metadata in bug reports.

**Exit gate:** save/load passes mid-production, mid-haul and mid-combat tests; new players understand resource flow without external documentation; UI remains readable during raids.

## Phase 4 — Politics and regional economy
**Goal:** extend the realm identity after the core loop is fun.

Candidates: social groups with explicit competing interests, legitimacy/unrest, one neighboring lord, limited diplomacy/trade, import/export contracts and caravan deliveries, more policies with visible economic/political trade-offs, a regional map with 2–3 settlements.

**Exit gate:** decisions have trade-offs rather than one obviously optimal slider; politics emerges from state and player choices, not arbitrary popups; trade has consistent accounting and a clear logistics model.

## Phase 5 — Campaign and war expansion

Potential systems: multiple settlements/regions, strategic armies and supply lines, siege tools, fortifications, battlefield objectives, rival lords with goals/treasury, diplomacy/treaties and longer campaign progression. Re-plan this phase after playtesting; it is not a promise to ship all of it.

## Permanent scope guardrails
- No multiplayer until single-player simulation is stable and fun.
- No huge map before a small map has working logistics/pathfinding.
- No thousands of autonomous citizens before profiling proves the need.
- No deep politics/dynasty model before basic approval/taxes create meaningful trade-offs.
- No dozens of resources until every existing resource has a clear role.
- No major content production before placeholder systems pass integration tests.
