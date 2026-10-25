extends SceneTree

func _init() -> void:
	print("==================================================")
	print("--- Running Phase 0 Simulation Proof Integration Test ---")
	print("==================================================")
	test_end_to_end_production_and_hauling()
	test_route_blocked_recovery()
	test_destination_capacity_limit_recovery()
	print("\n==================================================")
	print(">>> PHASE 0 EXIT GATE PASSED! <<<")
	print("==================================================")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_end_to_end_production_and_hauling() -> void:
	print("\n[Test 1] Testing end-to-end Farm -> Hauler -> Bakery -> Hauler -> Storehouse...")
	
	# Systems
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var job_board: JobBoard = JobBoard.new()
	var log_sys: LogisticsSystem = LogisticsSystem.new(job_board)
	
	# Recipes
	var recipe_grain: RecipeDef = RecipeDef.new(&"grow_grain", {}, {&"grain": 4}, 1, 3) # 4 grain every 3 ticks
	var recipe_bread: RecipeDef = RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 2) # 2 grain -> 2 bread every 2 ticks
	
	# Buildings
	var farm: BuildingState = BuildingState.new(1, &"farm", 30, [&"grain"])
	farm.assigned_workers = 1
	
	var bakery: BuildingState = BuildingState.new(2, &"bakery", 20, [&"grain", &"bread"])
	bakery.assigned_workers = 1
	
	var storehouse: BuildingState = BuildingState.new(3, &"storehouse", 50, [&"bread"])
	
	var inventories: Dictionary = {
		farm.inventory.owner_id: farm.inventory,
		bakery.inventory.owner_id: bakery.inventory,
		storehouse.inventory.owner_id: storehouse.inventory
	}
	farm.tile_origin = Vector2i(2, 2)
	bakery.tile_origin = Vector2i(7, 2)
	storehouse.tile_origin = Vector2i(10, 7)
	var test_world := WorldState.new(16, 12, 123)
	for y in range(test_world.height):
		for x in range(test_world.width):
			var coord := Vector2i(x, y)
			test_world.set_tile(coord, WorldTile.new(coord, &"grass", 0.7))
	var pathfinding := PathfindingService.new(test_world.width, test_world.height)
	pathfinding.initialize_from_world(test_world)
	for building in [farm, bakery, storehouse]:
		var footprint: Vector2i = BuildingCatalog.get_all_defs().get(building.definition_id, {}).get("footprint", Vector2i.ONE)
		for dy in range(footprint.y):
			for dx in range(footprint.x):
				pathfinding.set_solid(building.tile_origin + Vector2i(dx, dy), true)
	var building_by_inventory: Dictionary = {
		farm.inventory.owner_id: farm,
		bakery.inventory.owner_id: bakery,
		storehouse.inventory.owner_id: storehouse
	}
	
	# 1 Hauler. It must walk to each building before a transfer can commit.
	var hauler = log_sys.register_hauler(100, Vector2i(2, 8))
	
	# Simulation runs for 30 ticks
	for tick in range(1, 101):
		# 1. Advance production
		prod_sys.tick_building(farm, recipe_grain)
		prod_sys.tick_building(bakery, recipe_bread)
		
		# 2. Logistics demand generation
		# Bakery wants grain if it has less than 6
		if bakery.inventory.get_quantity(&"grain") + bakery.inventory.get_reserved_in(&"grain") < 6:
			log_sys.check_and_create_demand(farm, bakery, &"grain", 4, tick, 2)
			
		# Storehouse wants bread from bakery
		if bakery.inventory.get_available_outgoing(&"bread") > 0:
			log_sys.check_and_create_demand(bakery, storehouse, &"bread", 4, tick, 1)
			
		# 3. Dispatch and advance haulers
		log_sys.dispatch_jobs()
		log_sys.tick_haulers(inventories, tick, pathfinding, building_by_inventory)
	
	print("Simulation after 100 ticks:")
	print(" - Farm Grain: ", farm.inventory.get_quantity(&"grain"))
	print(" - Bakery Grain: ", bakery.inventory.get_quantity(&"grain"))
	print(" - Bakery Bread: ", bakery.inventory.get_quantity(&"bread"))
	print(" - Storehouse Bread: ", storehouse.inventory.get_quantity(&"bread"))
	
	# Verify that bread was successfully hauled into the storehouse
	var storehouse_bread: int = storehouse.inventory.get_quantity(&"bread")
	assert_true(storehouse_bread > 0, "Storehouse must have received bread through hauling!")
	
	# Invariant checks: inventories cannot be negative or exceed capacities
	assert_true(farm.inventory.get_quantity(&"grain") >= 0 and farm.inventory.get_total_quantity() <= farm.inventory.capacity)
	assert_true(bakery.inventory.get_total_quantity() <= bakery.inventory.capacity)
	assert_true(storehouse.inventory.get_total_quantity() <= storehouse.inventory.capacity)
	print("✓ End-to-end production and hauling succeeded cleanly!")

func test_route_blocked_recovery() -> void:
	print("\n[Test 2] Testing route blocked recovery and safe reservation release...")
	
	var job_board: JobBoard = JobBoard.new()
	var log_sys: LogisticsSystem = LogisticsSystem.new(job_board)
	
	var farm: BuildingState = BuildingState.new(11, &"farm", 30, [&"grain"])
	farm.inventory.add_resource(&"grain", 10, "INITIAL_STOCK")
	
	var bakery: BuildingState = BuildingState.new(12, &"bakery", 20, [&"grain", &"bread"])
	
	var inventories: Dictionary = {
		farm.inventory.owner_id: farm.inventory,
		bakery.inventory.owner_id: bakery.inventory
	}
	
	var hauler = log_sys.register_hauler(200)
	
	# Create job for 6 grain
	var job: HaulJob = log_sys.check_and_create_demand(farm, bakery, &"grain", 6, 1, 1)
	assert_true(job != null)
	assert_eq(farm.inventory.get_reserved_out(&"grain"), 6)
	assert_eq(bakery.inventory.get_reserved_in(&"grain"), 6)
	
	# Assign hauler
	log_sys.dispatch_jobs()
	assert_eq(job.status, HaulJob.Status.ASSIGNED)
	
	# Simulate route blockage before pickup
	hauler.is_route_blocked = true
	log_sys.tick_haulers(inventories, 2)
	
	# Job should now be CANCELLED with reason ROUTE_BLOCKED
	assert_eq(job.status, HaulJob.Status.CANCELLED)
	assert_eq(job.blocked_reason, "ROUTE_BLOCKED")
	
	# CRITICAL INVARIANT: Reservations MUST be restored cleanly, no resources lost or duplicated!
	assert_eq(farm.inventory.get_reserved_out(&"grain"), 0, "Source reservation must be cleanly released")
	assert_eq(farm.inventory.get_available_outgoing(&"grain"), 10, "All 10 grain must remain accessible at source")
	assert_eq(bakery.inventory.get_reserved_in(&"grain"), 0, "Destination capacity reservation must be cleanly released")
	assert_eq(bakery.inventory.get_free_capacity(), 20, "Destination capacity restored to 20")
	print("✓ Route blocked recovery safely released reservations with zero resource loss!")

func test_destination_capacity_limit_recovery() -> void:
	print("\n[Test 3] Testing full destination capacity prevention...")
	
	var job_board: JobBoard = JobBoard.new()
	var log_sys: LogisticsSystem = LogisticsSystem.new(job_board)
	
	var src: BuildingState = BuildingState.new(31, &"warehouse_a", 50)
	src.inventory.add_resource(&"timber", 20, "INITIAL")
	
	# Small destination with only 5 capacity
	var dst: BuildingState = BuildingState.new(32, &"shed", 5)
	
	# Attempt to haul 10 timber (capacity only 5)
	var job: HaulJob = log_sys.check_and_create_demand(src, dst, &"timber", 10, 1)
	# Should clamp to destination free capacity (5)
	assert_true(job != null, "Job should clamp to available capacity 5")
	assert_eq(job.amount, 5, "Job amount should be clamped to 5")
	
	# Now dst is fully reserved (5 out of 5)
	assert_eq(dst.inventory.get_free_capacity(), 0)
	
	# Any subsequent demand request must be rejected until capacity opens up
	var job_rejected: HaulJob = log_sys.check_and_create_demand(src, dst, &"timber", 5, 2)
	assert_true(job_rejected == null, "Must reject demand when destination is full")
	print("✓ Destination capacity limit correctly respected!")
