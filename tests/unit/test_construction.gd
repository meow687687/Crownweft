extends SceneTree

func _init() -> void:
	print("--- Running TestConstruction ---")
	test_placement_creates_planned_site_zero_progress()
	test_materials_reserved_hauled_delivered_correctly()
	test_insufficient_supplies_leaves_site_pending_with_clear_reason()
	test_construction_cannot_progress_without_required_materials()
	test_construction_completes_and_activates_building()
	test_cancellation_and_destruction_safety()
	test_save_load_preserves_unfinished_construction_site()
	print("--- TestConstruction PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

# Acceptance Test 1: Placement creates a PLANNED site with zero progress
func test_placement_creates_planned_site_zero_progress() -> void:
	var const_sys := ConstructionSystem.new()
	var cost := {&"timber": 5, &"stone": 2}
	var site := const_sys.create_construction_site(10, &"farm", Vector2i(20, 20), cost, 8, 11, 30, [&"grain"])
	
	assert_eq(site.status, BuildingState.Status.PLANNED, "Site must be in PLANNED status")
	assert_eq(site.construction_progress, 0.0, "Progress must start at 0.0")
	assert_eq(site.construction_ticks, 0, "Construction ticks must start at 0")
	assert_eq(site.construction_required_ticks, 8, "Required ticks must match parameter")
	assert_true(site.is_under_construction(), "Site must be reported as under construction")
	assert_true(not site.is_active(), "Site must not be reported as active")
	assert_true(site.construction_inventory != null, "Site must have dedicated construction inventory")
	assert_eq(site.construction_inventory.owner_id, 11, "Construction inventory must have dedicated owner id")
	assert_true(site.construction_inventory.accepts(&"timber"), "Must accept timber")
	assert_true(site.construction_inventory.accepts(&"stone"), "Must accept stone")
	assert_true(not site.has_all_construction_materials(), "Must not have all materials initially")
	
	var state := site.get_construction_state()
	assert_eq(state["status_name"], "PLANNED")
	assert_eq(state["ticks_completed"], 0)
	assert_eq(state["required_materials"][&"timber"], 5)
	assert_eq(state["outstanding_materials"][&"timber"], 5)
	assert_eq(state["delivered_materials"][&"timber"], 0)
	print("✓ Test 1: Placement creates a PLANNED site with zero progress PASSED")

# Acceptance Test 2: Materials are reserved, physically hauled, and delivered correctly
func test_materials_reserved_hauled_delivered_correctly() -> void:
	var const_sys := ConstructionSystem.new()
	var town_hall := BuildingState.new(1, &"town_hall", 150)
	town_hall.inventory.add_resource(&"timber", 20, "INITIAL")
	town_hall.inventory.add_resource(&"stone", 10, "INITIAL")
	
	var cost := {&"timber": 4, &"stone": 2}
	var site := const_sys.create_construction_site(2, &"bakery", Vector2i(15, 15), cost, 6, 3, 20)
	
	var job_board := JobBoard.new()
	var logistics := LogisticsSystem.new(job_board)
	var hauler := logistics.register_hauler(100, Vector2i(10, 10))
	
	# Create haul jobs for construction materials
	var needed_map := site.get_unreserved_materials_needed()
	for res in needed_map:
		var needed_qty: int = needed_map[res]
		var job := job_board.create_job(res, needed_qty, town_hall.inventory, site.construction_inventory, 5, 1)
		assert_true(job != null, "Haul job should be created")
		
	# Verify atomic reservations: Town Hall has reserved_out, site has reserved_in
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 4)
	assert_eq(town_hall.inventory.get_reserved_out(&"stone"), 2)
	assert_eq(site.construction_inventory.get_reserved_in(&"timber"), 4)
	assert_eq(site.construction_inventory.get_reserved_in(&"stone"), 2)
	assert_eq(site.get_unreserved_materials_needed().size(), 0, "No duplicate demand should be needed once reserved")
	
	# Dispatch job to hauler
	logistics.dispatch_jobs()
	assert_true(hauler.active_job != null, "Hauler should take the highest priority construction haul job")
	var active_job: HaulJob = hauler.active_job
	
	# Execute pickup
	var pickup_ok := job_board.execute_pickup(active_job, town_hall.inventory)
	assert_true(pickup_ok, "Pickup should succeed")
	assert_eq(town_hall.inventory.get_reserved_out(active_job.resource_id), 0, "Reservation cleared on physical pickup")
	assert_eq(town_hall.inventory.get_quantity(active_job.resource_id), 20 - active_job.amount if active_job.resource_id == &"timber" else 10 - active_job.amount)
	
	# Execute delivery
	var delivery_ok := job_board.execute_delivery(active_job, site.construction_inventory)
	assert_true(delivery_ok, "Delivery should succeed")
	assert_eq(site.construction_inventory.get_quantity(active_job.resource_id), active_job.amount)
	assert_eq(site.construction_inventory.get_reserved_in(active_job.resource_id), 0)
	print("✓ Test 2: Materials are reserved, physically hauled, and delivered correctly PASSED")

# Acceptance Test 3: Insufficient supplies leave a site pending with a clear reason
func test_insufficient_supplies_leaves_site_pending_with_clear_reason() -> void:
	var const_sys := ConstructionSystem.new()
	var town_hall := BuildingState.new(1, &"town_hall", 150)
	town_hall.inventory.add_resource(&"timber", 2, "LIMITED_STOCK") # Only 2 available, need 6
	
	var cost := {&"timber": 6}
	var site := const_sys.create_construction_site(2, &"quarry", Vector2i(5, 5), cost, 8, 3)
	
	# Deliver partial materials
	site.construction_inventory.add_resource(&"timber", 2, "PARTIAL_DELIVERY")
	assert_eq(site.get_delivered_materials()[&"timber"], 2)
	assert_eq(site.get_outstanding_materials()[&"timber"], 4)
	assert_true(not site.has_all_construction_materials())
	
	# Tick construction: should remain in PLANNED with clear block reason
	const_sys.tick_building(site, 2, 1)
	assert_eq(site.status, BuildingState.Status.PLANNED)
	assert_eq(site.construction_block_reason, &"WAITING_FOR_MATERIALS")
	assert_eq(site.construction_progress, 0.0)
	print("✓ Test 3: Insufficient supplies leave a site pending with a clear reason PASSED")

# Acceptance Test 4: Construction cannot progress without the required materials
func test_construction_cannot_progress_without_required_materials() -> void:
	var const_sys := ConstructionSystem.new()
	var cost := {&"timber": 8, &"stone": 4}
	var site := const_sys.create_construction_site(5, &"storehouse", Vector2i(10, 10), cost, 10, 6)
	
	# 4 builders present at site, but no materials delivered
	for tick in range(1, 20):
		const_sys.tick_building(site, 4, tick)
		assert_eq(site.construction_ticks, 0, "Construction ticks must not advance without materials")
		assert_eq(site.construction_progress, 0.0, "Progress must remain 0.0")
		assert_eq(site.status, BuildingState.Status.PLANNED)
	print("✓ Test 4: Construction cannot progress without required materials PASSED")

# Acceptance Test 5: Construction completes and activates the building correctly
func test_construction_completes_and_activates_building() -> void:
	var const_sys := ConstructionSystem.new()
	var cost := {&"timber": 4, &"stone": 4}
	var site := const_sys.create_construction_site(8, &"bakery", Vector2i(12, 12), cost, 6, 9)
	
	# Deliver 100% of required materials
	site.construction_inventory.add_resource(&"timber", 4, "DELIVERY")
	site.construction_inventory.add_resource(&"stone", 4, "DELIVERY")
	assert_true(site.has_all_construction_materials(), "Must have all materials")
	
	# Tick with no builders: blocks on NO_BUILDERS
	const_sys.tick_building(site, 0, 1)
	assert_eq(site.status, BuildingState.Status.UNDER_CONSTRUCTION)
	assert_eq(site.construction_block_reason, &"NO_BUILDERS")
	assert_eq(site.construction_ticks, 0)
	
	# Tick 1 with 2 builders: advances 2 ticks
	const_sys.tick_building(site, 2, 2)
	assert_eq(site.construction_ticks, 2)
	assert_eq(site.construction_progress, 2.0 / 6.0)
	assert_eq(site.construction_block_reason, &"")
	
	# Tick 2 with 2 builders: advances 2 ticks (total 4)
	const_sys.tick_building(site, 2, 3)
	assert_eq(site.construction_ticks, 4)
	assert_eq(site.status, BuildingState.Status.UNDER_CONSTRUCTION)
	
	# Tick 3 with 2 builders: reaches 6 ticks -> triggers completion!
	var completed := [false]
	const_sys.building_completed.connect(func(b): completed[0] = true)
	const_sys.tick_building(site, 2, 4)
	
	assert_true(completed[0], "building_completed signal must be emitted")
	assert_eq(site.status, BuildingState.Status.ACTIVE, "Status must transition to ACTIVE")
	assert_eq(site.construction_progress, 1.0, "Progress must be 1.0")
	assert_true(site.is_active(), "is_active() must return true")
	assert_true(not site.is_under_construction(), "is_under_construction() must return false")
	
	# Verify materials spent
	assert_eq(site.construction_inventory.get_quantity(&"timber"), 0, "Timber must be consumed upon completion")
	assert_eq(site.construction_inventory.get_quantity(&"stone"), 0, "Stone must be consumed upon completion")
	print("✓ Test 5: Construction completes and activates building correctly PASSED")

# Acceptance Test 6: Cancelling or destroying a site does not leak reservations or duplicate resources
func test_cancellation_and_destruction_safety() -> void:
	var const_sys := ConstructionSystem.new()
	var town_hall := BuildingState.new(1, &"town_hall", 150)
	town_hall.inventory.add_resource(&"timber", 20, "INITIAL")
	
	var cost := {&"timber": 10}
	var site := const_sys.create_construction_site(2, &"barracks", Vector2i(30, 30), cost, 10, 3)
	
	var job_board := JobBoard.new()
	var job := job_board.create_job(&"timber", 6, town_hall.inventory, site.construction_inventory, 5, 1)
	assert_true(job != null)
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 6)
	assert_eq(site.construction_inventory.get_reserved_in(&"timber"), 6)
	
	# Deliver 4 timber directly into site inventory
	site.construction_inventory.add_resource(&"timber", 4, "PARTIAL_DELIVERY")
	
	var inv_map := {
		town_hall.inventory.owner_id: town_hall.inventory,
		site.construction_inventory.owner_id: site.construction_inventory
	}
	
	# Cancel the construction site
	var refund_summary := const_sys.cancel_construction_site(site, job_board, town_hall.inventory, inv_map)
	
	# 1. Verify job cancellation & reservation release
	assert_eq(job.status, HaulJob.Status.CANCELLED)
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 0, "Outgoing reservation must be cleanly released")
	assert_eq(site.construction_inventory.get_reserved_in(&"timber"), 0, "Inbound reservation must be cleanly released")
	
	# 2. Verify delivered materials refunded
	assert_eq(refund_summary[&"timber"], 4, "Must refund 4 delivered timber")
	assert_eq(town_hall.inventory.get_quantity(&"timber"), 24, "Town Hall must have 20 initial + 4 refunded = 24")
	assert_eq(town_hall.inventory.get_available_outgoing(&"timber"), 24, "All 24 timber must be available unreserved")
	assert_eq(site.status, BuildingState.Status.DESTROYED)
	print("✓ Test 6: Cancelling site does not leak reservations or duplicate resources PASSED")

# Acceptance Test 7: Save/load preserves an unfinished construction site
func test_save_load_preserves_unfinished_construction_site() -> void:
	var world := WorldState.new(96, 96, 1234)
	var economy := EconomyState.new()
	
	var site := BuildingState.new(50, &"farm", 30, [&"grain"])
	site.tile_origin = Vector2i(40, 40)
	site.status = BuildingState.Status.UNDER_CONSTRUCTION
	site.construction_ticks = 4
	site.construction_required_ticks = 8
	site.construction_progress = 0.5
	site.construction_cost = {&"timber": 5, &"stone": 2}
	site.construction_block_reason = &"WAITING_FOR_BUILDERS"
	site.construction_inventory = Inventory.new(51, 30, [&"timber", &"stone"])
	site.construction_inventory.add_resource(&"timber", 5, "TEST")
	site.construction_inventory.add_resource(&"stone", 1, "TEST")
	site.construction_inventory.reserve_in(&"stone", 1)
	
	var job_board := JobBoard.new()
	var buildings: Array[BuildingState] = [site]
	var citizens: Array[CitizenState] = []
	var military_units: Array[MilitaryUnitState] = []
	
	var save_path := "user://saves/test_construction_saveload.json"
	var save_ok := SaveService.save_game_to_file(world, economy, buildings, citizens, military_units, job_board, 50, 1.0, save_path)
	assert_true(save_ok, "Save should succeed")
	
	var loaded := SaveService.load_game_from_file(save_path)
	assert_true(not loaded.is_empty(), "Load should succeed")
	
	var loaded_buildings: Array = loaded["buildings"]
	assert_eq(loaded_buildings.size(), 1)
	var lb: BuildingState = loaded_buildings[0]
	assert_eq(lb.entity_id, 50)
	assert_eq(lb.status, BuildingState.Status.UNDER_CONSTRUCTION)
	assert_eq(lb.construction_ticks, 4)
	assert_eq(lb.construction_required_ticks, 8)
	assert_eq(lb.construction_progress, 0.5)
	assert_eq(lb.construction_block_reason, &"WAITING_FOR_BUILDERS")
	assert_eq(lb.construction_cost[&"timber"], 5)
	assert_eq(lb.construction_cost[&"stone"], 2)
	assert_true(lb.construction_inventory != null, "Construction inventory must be restored")
	assert_eq(lb.construction_inventory.owner_id, 51)
	assert_eq(lb.construction_inventory.get_quantity(&"timber"), 5)
	assert_eq(lb.construction_inventory.get_quantity(&"stone"), 1)
	assert_eq(lb.construction_inventory.get_reserved_in(&"stone"), 1)
	print("✓ Test 7: Save/load preserves unfinished construction site PASSED")
