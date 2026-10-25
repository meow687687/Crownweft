# Crownweft Repair Notes

## Status
**Code repair pass packaged; runtime verification pending.** This is not a claim that all gameplay is now correct. The Godot engine was unavailable in the editing environment, so no claim of a passing parser, scene launch, or test suite is made.

## Fixes made

### Simulation correctness
- Hauling now uses grid paths to reach a building footprint. Source stock is removed only after arrival; destination stock is added only after delivery.
- Haul reservations and job states are reconciled on route/building failure. Carried cargo is not treated like a pre-pickup job when a building is destroyed.
- Recovery prefers the existing destination when still reachable and avoids accumulating duplicate inbound capacity reservations.
- Worker production eligibility now uses workers physically at the worksite, not only `assigned_workers`.
- Resource production uses finite nearby timber/stone deposits.
- Resource demand is generated between producer, processor, Town Hall and storage inventories so building materials and food must move through logistics.
- Household food is taken only from reachable Town Hall/storehouse inventory, not directly from bakery inventory.
- Town Hall starting capacity increased so its initial stock is not silently rejected.
- Raiders can attack buildings when no defenders are close by, and movement/attacks use grid-based routing where a pathfinding service is provided.

### Save/load
- Save schema now records terrain, roads, resource deposits, building occupancy and generator version.
- Load restores world tiles before rebuilding pathfinding and renderer caches.
- Worker assignments, hauler cargo, and active job linkage are restored in the scene load path.

### UI and presentation
- Rebuilt the HUD around readable text, two-tier resource/status display, construction palette, inspector and explicit production blocker labels.
- Added small pixel-art sprites for terrain, buildings and unit roles; these are prototype assets, not final commercial art.
- Cached rasterized terrain and road layers and throttled redraw calls to reduce repeated per-tile work.

### Tests added/updated
- Physical hauling asserts that pickup/delivery wait for path traversal and temporary recovery does not leak destination reservations.
- Production test covers worker-arrival gating.
- Combat tests cover raiders attacking buildings with no defenders and movement around blocked tiles.
- Save/load test checks world dimensions and restoration of saved terrain/resource deposit state.

## Static checks observed
- `git diff --check`: passed.
- Local `res://` preload/load and scene-resource path audit: zero missing references.
- 21 PNG pixel assets: dimension check passed (all within 128×128).

## Not verified here
- Godot parser/type checker, scene launch, visual layout at different resolutions, live input handling, and all test suites. No Godot executable was available in the environment.
- Runtime balance, production throughput, combat feel, save/load during all possible job states, and generated-map edge cases.
- Visual quality as rendered in-engine. Assets are intentionally small prototypes; a runtime screenshot review is still necessary.

## Required verification on a machine with Godot 4.x
1. Import/open `project.godot` and fix any parser or type errors first.
2. Run `godot --headless --path . --script res://tests/test_runner.gd` and inspect each suite result.
3. Launch the game and test a farm → bakery → storehouse chain, then block a route and verify inventories/reservations.
4. Assign workers and confirm a building does not produce until a worker reaches it.
5. Build a woodcutter/quarry; verify deposits deplete and materials are delivered to Town Hall.
6. Save/load during an active haul, during production, and after a building is destroyed.
7. Trigger a raid with and without defenders; confirm raiders choose targets, navigate around blockers, and can be repelled.
8. Check UI at 1280×853 and at smaller supported window sizes. Verify panels do not overlap essential map controls.

## Remaining known scope limits
- This is not a complete kingdom simulator. Deep faction politics, regional trade, sieges, campaign diplomacy and large populations remain deferred.
- Hauling and citizen movement are grid/tick based, not animation-perfect path simulations.
- Art is a consistent prototype direction, not production-quality art.
- The working title “Crownweft” has not received trademark/store-name clearance.
