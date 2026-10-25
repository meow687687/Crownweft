# 03 — Simulation Architecture

## Technical direction
- **Engine:** Godot 4.7.2 stable.
- **Language:** GDScript initially; add C# only if a measured bottleneck or specific tooling requirement justifies it.
- **World rendering:** TileMapLayer and sprite/scene layers for terrain, overlays, buildings, citizens and military.
- **Data definitions:** custom Godot `Resource` types (`BuildingDef`, `RecipeDef`, `ResourceDef`, `UnitDef`) so balance can change without rewriting systems.
- **Simulation:** plain data models and service classes, separate from the visual scene tree.
- **Testing:** Godot headless tests or a small test framework; pure calculation helpers independently testable.

## Architecture rules
1. **Simulation state is authoritative.** Rendering displays state; visuals do not own resource truth.
2. **No resource teleportation.** Inventory changes happen only through explicit production, consumption, construction, hauling, tax, recruitment or upkeep transactions.
3. **Avoid one Godot Node per resource stack.** Scenes may represent visuals and interactions; inventories belong to data models.
4. **Avoid building a custom ECS framework too early.** Use typed data objects and focused systems; refactor only after profiling.
5. **Make game rules inspectable.** Emit reason codes/events for shortages, blocked paths, failed jobs, tax changes and combat outcomes.
6. **Keep systems testable without rendering.** Economy and logistics tests must run headlessly.
7. **Use stable IDs and explicit ordering** for debugability and save/load safety.

## Suggested layout
```text
crownweft/
├── project.godot
├── assets/{sprites,tilesets,ui,fonts,audio}/
├── data/{buildings,recipes,resources,units,balance}/
├── scenes/{boot,world,buildings,citizens,military,ui}/
├── scripts/
│   ├── domain/{world_state,entity_registry,inventory,citizen_state,building_state,haul_job,unit_state}.gd
│   ├── simulation/{simulation_clock,production_system,needs_system,logistics_system,job_board,economy_system,stability_system,pathfinding_service,combat_system,world_generation_service}.gd
│   ├── presentation/{world_renderer,selection_controller,build_controller,overlay_controller}.gd
│   └── persistence/{save_service,save_schema}.gd
├── tests/{unit,integration,fixtures}/
└── docs/
```
This is a responsibility map, not a demand to create every file on day one.

## Runtime layers
### Presentation
Camera, sprite animation, selection, building placement, UI, overlays. Reads simulation state/events; never becomes the source of truth for inventories or rules.

### Domain state
Plain records for world tiles, entities, inventories, buildings, citizens, jobs and military units.

### Simulation services
Production, consumption/needs, logistics, pathfinding, economy, stability and combat. Each service owns its calculations, not the UI.

### Persistence
Serialize data-only state with stable IDs and a versioned schema. Do not serialize scene nodes or object references directly.

## Time model
- Render/physics frames are independent from economic simulation.
- Economic/logistics simulation uses an initial fixed-step accumulator target of 4 ticks per real second at 1×.
- Unit motion may use Godot physics frames with speed scaled by game speed; orders and combat events must use an explicit, predictable update sequence.
- Pause stops simulation and combat but leaves UI inspection available.
- 1×/2×/3× speed scales simulation time without changing system order within a tick.
- Use stable entity ordering. Do not promise cross-platform lockstep determinism in v0.1.
- Day length and recipe rates are balance parameters, not constants duplicated across scripts.

## Simulation update order
1. Read queued player commands and apply legal state changes.
2. Refresh navigation if terrain/building occupancy changed.
3. Update citizen assignments and work availability.
4. Advance production recipes if workers, inputs and output capacity are available.
5. Generate hauling demand from inventory thresholds.
6. Assign/reconcile jobs, reservations and blocked paths.
7. Execute pickup/delivery transaction completions.
8. Apply household and military food consumption.
9. Apply tax, wages and upkeep at configured economic intervals.
10. Update approval and shortage state.
11. Resolve combat intents, damage and unit loss.
12. Emit diagnostics, update UI snapshots and autosave timers.

Exact ordering can change after tests but must stay explicit and documented.

## Logistics service
### Inventory model
Each inventory records quantities, capacity, resource acceptance rules, reserved inbound/outbound quantities and owner ID. Debug builds keep a bounded transaction history.

### Haul job lifecycle
`REQUESTED → RESERVED → ASSIGNED → PICKUP → IN_TRANSIT → DELIVERED`

Failure outcomes: `CANCELLED`, `BLOCKED`, `SOURCE_EMPTY`, `DESTINATION_FULL`, `NO_PATH`, `WORKER_UNAVAILABLE`.

The Job Board creates a job when destination demand and source surplus both exist. It reserves outbound stock and inbound capacity atomically before dispatch. On cancellation, reservations must be released exactly once.

### Initial priority order
1. Emergency food supply.
2. Inputs preventing a production chain from stalling.
3. Construction materials.
4. General stock balancing.

### Assignment
Each idle hauler evaluates a bounded candidate set, filtered by resource compatibility and valid path. Choose by weighted cost: path length + terrain/road penalty + job urgency. Schedule job assignment on simulation ticks; do not let every hauler scan every job every frame.

## Pathfinding
- Grid-based A* for MVP.
- Separate passability from movement cost: roads reduce cost, rough terrain increases it, water/walls block it.
- Buildings and construction sites have explicit footprint/passability data.
- Cache paths where safe; invalidate after road/building changes.
- Replan when a path becomes invalid, not every frame.
- Add a UI/debug explanation for “no valid path.”
- Hierarchical pathfinding is deferred until profiling proves it necessary.

## Production and consumption
Recipes define inputs, outputs, worker requirements, duration and terrain requirements. A cycle advances only if inputs and output capacity are feasible. Production changes local inventory, not a global stock counter. Food/upkeep use explicit consumption transactions from reachable stores; missing access marks a household/unit at risk rather than silently subtracting global food.

## Combat
Player input becomes orders: `MOVE`, `ATTACK_MOVE`, `ATTACK_TARGET`, `HOLD`. Combat validates target, range, cooldown and damage. Enemy raiders use a small finite-state machine, not a planner or machine-learning agent. Economy sees recruitment and upkeep demand but does not depend on combat internals.

## Events and observability
Emit structured events such as `inventory_changed`, `production_blocked(reason)`, `haul_job_blocked(reason)`, `food_shortage_started`, `tax_policy_changed`, `approval_changed`, `unit_order_changed`, `raid_detected`, and `combat_unit_lost`.

A debug overlay should expose current tick, inventory, job status, entity ID, path outcome and production blocker.

## Persistence
Save schema stores schema version, seed and generator version, simulation time/speed, world tiles/edits, entity IDs/state, inventories, citizen assignments, active jobs/orders or safe reconstruction inputs, units/factions, treasury/tax/stability and settings. Test saving during a haul, production, combat and near-capacity destination inventory.
