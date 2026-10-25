extends SceneTree

func _initialize() -> void:
	var world := WorldState.new(16, 12, 941)
	for y in range(world.height):
		for x in range(world.width):
			var coord := Vector2i(x, y)
			world.set_tile(coord, WorldTile.new(coord, &"grass", 0.6))

	var farm := BuildingState.new(1, &"farm", 40, [&"grain"])
	farm.tile_origin = Vector2i(2, 2)
	farm.inventory.add_resource(&"grain", 8, "TEST_STOCK")
	var bakery := BuildingState.new(2, &"bakery", 30, [&"grain", &"bread"])
	bakery.tile_origin = Vector2i(8, 2)
	var pathfinding := PathfindingService.new(world.width, world.height)
	pathfinding.initialize_from_world(world)
	for building in [farm, bakery]:
		var footprint: Vector2i = BuildingCatalog.get_all_defs().get(building.definition_id, {}).get("footprint", Vector2i.ONE)
		for dy in range(footprint.y):
			for dx in range(footprint.x):
				pathfinding.set_solid(building.tile_origin + Vector2i(dx, dy), true)

	var inventory_map := {farm.inventory.owner_id: farm.inventory, bakery.inventory.owner_id: bakery.inventory}
	var building_map := {farm.inventory.owner_id: farm, bakery.inventory.owner_id: bakery}
	var logistics := LogisticsSystem.new()
	var hauler = logistics.register_hauler(100, Vector2i(2, 8))
	var job: HaulJob = logistics.check_and_create_demand(farm, bakery, &"grain", 4, 1, 1)
	assert(job != null)
	logistics.dispatch_jobs()

	var source_before: int = farm.inventory.get_quantity(&"grain")
	logistics.tick_haulers(inventory_map, 1, pathfinding, building_map)
	assert(farm.inventory.get_quantity(&"grain") == source_before, "Goods must not be picked up before the hauler reaches the source")
	assert(job.status == HaulJob.Status.ASSIGNED, "Job should remain assigned while the hauler is moving to the source")

	var source_arrival_tick := 1
	while job.status == HaulJob.Status.ASSIGNED and source_arrival_tick < 30:
		source_arrival_tick += 1
		logistics.tick_haulers(inventory_map, source_arrival_tick, pathfinding, building_map)
	assert(job.status == HaulJob.Status.IN_TRANSIT, "Job should enter transit only after reaching the source")
	assert(hauler.carried_amount == 4, "Hauler should carry the reserved amount")
	assert(bakery.inventory.get_quantity(&"grain") == 0, "Destination should not receive goods before arrival")

	# Simulate a temporary interruption after pickup. Recovery should reuse the
	# existing destination reservation, not reserve more capacity on each retry.
	var reservation_before: int = bakery.inventory.get_reserved_in(&"grain")
	job.status = HaulJob.Status.BLOCKED
	job.blocked_reason = "TEST_TEMPORARY_BLOCK"
	logistics.tick_haulers(inventory_map, source_arrival_tick + 1, pathfinding, building_map)
	assert(job.status == HaulJob.Status.IN_TRANSIT, "A reachable destination should resume after a temporary block")
	assert(bakery.inventory.get_reserved_in(&"grain") == reservation_before, "Resume must not leak duplicate destination reservations")

	var delivery_tick := source_arrival_tick + 1
	while job.status == HaulJob.Status.IN_TRANSIT and delivery_tick < 60:
		delivery_tick += 1
		logistics.tick_haulers(inventory_map, delivery_tick, pathfinding, building_map)
	assert(job.status == HaulJob.Status.DELIVERED, "Job should complete after walking to the destination")
	assert(bakery.inventory.get_quantity(&"grain") == 4, "Destination should receive the actual cargo")
	assert(hauler.carried_amount == 0, "Cargo should clear only after delivery")
	print("PASS: physical hauling delays pickup and delivery until path traversal completes.")
	quit(0)
