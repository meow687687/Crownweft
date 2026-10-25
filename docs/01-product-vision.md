# 01 — Product Vision

## Working title
**Crownweft: A Realm in Motion**

“Crownweft” is a working title. “Weft” is the thread woven through a fabric; the game’s identity is the way production, logistics, social order, political power, and war depend on one another. Name availability and trademark status have not been cleared.

## Vision
Crownweft is a top-down medieval realm simulation where the player grows a frontier settlement into a self-sustaining town, designs how goods move through it, manages the trade-offs between prosperity and authority, and commands troops in real-time conflicts.

## Player promise
**Every expansion creates opportunity—and another dependency to manage.**

A farm produces grain but needs labor, land and a route to storage. A bakery transforms grain into more useful food but can stall if its inputs are not delivered. A larger population creates more workers and tax income while increasing consumption. Soldiers protect the town but need recruitment funds and food. A distant quarry may be rich in stone but costly to supply.

## Genre and format
- Single-player, desktop-first.
- Top-down 2D with detailed, readable pixel art.
- Real-time settlement simulation with pause and speed controls.
- Direct real-time commands for a small number of military units.
- Procedural, seeded maps for replayability.
- Offline-first; no account, online service, or external AI dependency.

## Four pillars

### 1. Logistics is gameplay
Resources exist in physical inventories. They do not teleport between buildings or appear in a global pool. Workplaces produce into local inventory; haulers move goods along reachable paths; destination capacity, route cost, and job priority affect whether production succeeds.

### 2. The economy is interconnected
Labor, food, construction materials, treasury, household consumption, and military upkeep compete for capacity. The player should diagnose bottlenecks rather than merely watch a set of counters.

### 3. Power has consequences
Taxes and policies change treasury income and public approval. Later, social factions and rival lords will respond to player decisions through measurable interests and relationships—not a simplistic good/evil meter.

### 4. War tests the realm
The player directly selects and commands troops. Recruitment, equipment, food supply and travel time constrain military action. A battle is not an isolated minigame detached from the town’s economy.

## Intended player
Players who enjoy settlement growth, resource-chain planning, logistics puzzles, simulation-driven stories, and tactical medieval battles. The game should reward observation and planning more than click speed.

## Design principles
- **Show causality:** when bread production stops, show missing grain, blocked route, idle worker or full output inventory.
- **Favor readable systems:** a few meaningful resources are better than dozens of decorative resources.
- **Keep simulation rules inspectable:** provide overlays for inventory, paths, jobs, shortages and unit orders.
- **Let stories emerge:** shortages, delayed supplies and political pressure should arise from simulation systems.
- **Keep the first map small enough to understand:** extend the simulation only after a complete settlement loop is enjoyable.
- **Build a vertical slice, not a list of promises:** all pillars belong in the vision, but not all need full depth in v0.1.

## Differentiation hypothesis
Crownweft's strongest identity is not “a medieval game with many systems.” It is **a logistics-first realm simulator where the supply network visibly connects town prosperity to military capability and political stability**. This is a hypothesis to validate with a playable build, not a market-proven claim.

## Experience loop
1. Survey terrain, fertility, forests, stone deposits and routes.
2. Place buildings and roads within labor and material capacity.
3. Assign workers and watch production start.
4. Solve delivery bottlenecks by improving storage, routes, work priorities or staffing.
5. Feed households and accumulate surplus.
6. Set tax policy and make trade-offs between revenue and approval.
7. Recruit a small force and respond to a raid.
8. Review what failed, repair the network, and expand with better information.

## Platform and engine
Desktop first, keyboard/mouse controls. Recommended engine: Godot 4.7.2 stable, GDScript, TileMapLayer/tile-based world representation, Resources for data definitions, and custom lightweight simulation services. Avoid committing to the latest beta as the production baseline.

## Explicit non-goals
- Multiplayer, persistent online realms or server-authoritative networking.
- Huge populations or simulation of every citizen’s private psychology.
- Deep dynasty/character drama in the style of grand-strategy games.
- Full diplomacy, vassalage, succession, religion and espionage in the first playable release.
- Naval warfare, magic, skill trees, dozens of resources, or mod marketplace.
- Fully simulated trade prices across a continent in v0.1.
- Procedural generation of every asset or reliance on AI-generated art as core game content.
