# Crownweft — Medieval Realm Simulation

**Project status:** active prototype; repair pass in progress.  
**Engine:** Godot 4.x, GDScript.  
**Current focus:** make the simulation rules coherent before expanding the game.

Crownweft is a top-down medieval realm simulator focused on physical logistics, production chains, a growing settlement, political stability, and real-time tactical combat.

## Open the project

1. Install a compatible Godot 4.x stable build.
2. Extract the archive.
3. Open `project.godot` through Godot Project Manager.
4. Run the project with **F6** for the active scene or **F5** for the project.

## Repair pass in this package

- Haulers follow grid paths to the source before pickup, then carry goods along paths to the destination before delivery.
- Inventory reservations remain explicit, and blocked/cancelled jobs are intended to preserve goods and release reservations safely.
- Production now requires a worker to physically reach the worksite; assigned headcount alone is not enough.
- Farm-to-bakery, bakery-to-storage, and wood/stone-to-Town-Hall demand is generated from local inventories.
- Household food consumption uses reachable Town Hall/storehouse inventories rather than consuming bread directly from a bakery.
- Construction costs are supplied from Town Hall stock, with local timber/stone delivery required.
- Raiders can attack settlement buildings when no defenders are close by; unit orders use grid pathfinding around obstacles.
- Save schema stores terrain and resource deposit state and reconstructs the world on load.
- HUD reorganized into separate resource/status and construction rows; building inspectors expose worker arrival, production blockers, inventory and health.
- Added hand-authored pixel sprites for terrain, buildings and units; renderer caches terrain/road layers for cheaper redraws.
- Added regression tests for physical hauling, worker arrival, save/load world restoration, building attacks and movement around obstacles.

## Run tests

From the project root, with Godot available on `PATH`:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

The test runner launches each suite in headless mode. Individual suites can be run by substituting their `res://tests/...` path.

## Important verification status

This repair package was statically checked for whitespace errors and missing `res://` references. Pixel-art asset dimensions were checked. **The Godot runtime and test suites have not been executed in this environment because a Godot binary was unavailable.** Treat the changes as a repair candidate pending an engine run; do not interpret the included tests as passing until the command above succeeds.

See `REPAIR_NOTES.md` for the concrete fixes, remaining limitations, and verification boundary.
