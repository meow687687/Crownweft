extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("--- Running TestProduction ---")
	test_farm_production()
	test_production_waits_for_worker_arrival()
	test_bakery_production_and_blocks()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestProduction PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_farm_production() -> void:
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var farm: BuildingState = BuildingState.new(1, &"farm", 20, [&"grain"])
	var recipe_grain: RecipeDef = RecipeDef.new(&"grow_grain", {}, {&"grain": 2}, 1, 3) # 3 ticks duration
	
	# Blocked by no workers
	farm.assigned_workers = 0
	prod_sys.tick_building(farm, recipe_grain)
	assert_eq(farm.current_block_reason, &"NO_WORKERS")
	assert_eq(farm.inventory.get_quantity(&"grain"), 0)
	
	# Assign worker
	farm.assigned_workers = 1
	
	# Tick 1 (cycle started, inputs verified, outputs reserved)
	prod_sys.tick_building(farm, recipe_grain)
	assert_eq(farm.current_block_reason, &"")
	assert_eq(farm.production_progress, 1)
	assert_eq(farm.inventory.get_quantity(&"grain"), 0)
	assert_eq(farm.inventory.get_reserved_in(&"grain"), 2)
	
	# Tick 2
	prod_sys.tick_building(farm, recipe_grain)
	assert_eq(farm.production_progress, 2)
	
	# Tick 3 (completion)
	prod_sys.tick_building(farm, recipe_grain)
	assert_eq(farm.production_progress, 0)
	assert_eq(farm.inventory.get_quantity(&"grain"), 2)
	assert_eq(farm.inventory.get_reserved_in(&"grain"), 0)


func test_production_waits_for_worker_arrival() -> void:
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var farm: BuildingState = BuildingState.new(4, &"farm", 20, [&"grain"])
	var recipe_grain: RecipeDef = RecipeDef.new(&"grow_grain", {}, {&"grain": 2}, 1, 2)
	farm.assigned_workers = 1

	# A worker assigned on paper must not make production advance until physically present.
	prod_sys.tick_building(farm, recipe_grain, null, 0)
	assert_eq(farm.current_block_reason, &"NO_WORKERS", "No worker has reached the worksite")
	assert_eq(farm.production_progress, 0, "Production must not advance before worker arrival")
	assert_eq(farm.inventory.get_reserved_in(&"grain"), 0, "No output capacity should be reserved before arrival")

	prod_sys.tick_building(farm, recipe_grain, null, 1)
	assert_eq(farm.current_block_reason, &"", "Production should start once a worker is present")
	assert_eq(farm.production_progress, 1, "Production should advance once worker is present")

func test_bakery_production_and_blocks() -> void:
	var prod_sys: ProductionSystem = ProductionSystem.new()
	var bakery: BuildingState = BuildingState.new(2, &"bakery", 10, [&"grain", &"bread"])
	var recipe_bread: RecipeDef = RecipeDef.new(&"bake_bread", {&"grain": 2}, {&"bread": 2}, 1, 2)
	
	bakery.assigned_workers = 1
	
	# Missing inputs check
	prod_sys.tick_building(bakery, recipe_bread)
	assert_eq(bakery.current_block_reason, &"MISSING_INPUTS")
	
	# Provide 2 grain
	bakery.inventory.add_resource(&"grain", 2, "SUPPLY")
	assert_eq(bakery.inventory.get_quantity(&"grain"), 2)
	
	# Tick 1: Consumes 2 grain at cycle start, reserves 2 bread space
	prod_sys.tick_building(bakery, recipe_bread)
	assert_eq(bakery.current_block_reason, &"")
	assert_eq(bakery.production_progress, 1)
	assert_eq(bakery.inventory.get_quantity(&"grain"), 0, "Grain consumed into production")
	
	# Tick 2: Completes, yields 2 bread
	prod_sys.tick_building(bakery, recipe_bread)
	assert_eq(bakery.production_progress, 0)
	assert_eq(bakery.inventory.get_quantity(&"bread"), 2)
	
	# Test OUTPUT_FULL block
	# Fill bakery inventory to capacity
	bakery.inventory.add_resource(&"bread", 8, "FILL")
	assert_eq(bakery.inventory.get_free_capacity(), 0)
	bakery.inventory.add_resource(&"grain", 2, "EXTRA", false) # won't fit anyway
	
	# Even if it had grain, with 0 free capacity it must be blocked by OUTPUT_FULL
	var small_bakery: BuildingState = BuildingState.new(3, &"bakery", 2, [&"grain", &"bread"])
	small_bakery.assigned_workers = 1
	small_bakery.inventory.add_resource(&"grain", 2, "SUPPLY")
	# free capacity is now 0 (capacity 2, grain 2)
	prod_sys.tick_building(small_bakery, recipe_bread)
	assert_eq(small_bakery.current_block_reason, &"OUTPUT_FULL")
