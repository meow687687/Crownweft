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
	
	# Hardening Review Tests
	test_hardening_cargo_recovery_all_phases()
	test_hardening_refund_overflow_to_ground_pile()
	test_hardening_concurrent_reservations_same_tick()
	test_hardening_cleanup_integrity_and_isolation()
	
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

# Hardening Gap 1: Cargo recovery in all three hauler phases
func test_hardening_cargo_recovery_all_phases() -> void:
	var const_sys := ConstructionSystem.new()
	var pathfinding := PathfindingService.new(96, 96)
	var town_hall := BuildingState.new(1, &"town_hall", 150)
	town_hall.tile_origin = Vector2i(10, 10)
	town_hall.inventory.add_resource(&"timber", 30, "INITIAL")
	
	# --- Subcase 1A: Travelling to source (pre-pickup) ---
	var site_a := const_sys.create_construction_site(10, &"farm", Vector2i(20, 20), {&"timber": 4}, 8, 11)
	var jb_a := JobBoard.new()
	var log_a := LogisticsSystem.new(jb_a)
	var h_a := log_a.register_hauler(1, Vector2i(5, 5))
	var job_a := jb_a.create_job(&"timber", 4, town_hall.inventory, site_a.construction_inventory, 5, 1)
	log_a.dispatch_jobs()
	assert_eq(h_a.active_job, job_a)
	assert_eq(h_a.carried_amount, 0, "Pre-pickup hauler carries no cargo")
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 4)
	
	# Cancel Site A before pickup
	var inv_map_a := {town_hall.inventory.owner_id: town_hall.inventory, site_a.construction_inventory.owner_id: site_a.construction_inventory}
	const_sys.cancel_construction_site(site_a, jb_a, town_hall.inventory, inv_map_a)
	log_a.tick_haulers(inv_map_a, 2, pathfinding, {town_hall.inventory.owner_id: town_hall})
	
	assert_eq(job_a.status, HaulJob.Status.CANCELLED)
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 0, "Outgoing reservation cleanly released")
	assert_true(h_a.active_job == null, "Hauler freed from cancelled pre-pickup job")
	assert_eq(h_a.carried_amount, 0)
	
	# --- Subcase 1B: Carrying cargo to destination (in-transit) ---
	var site_b := const_sys.create_construction_site(20, &"bakery", Vector2i(25, 25), {&"timber": 4}, 8, 21)
	var jb_b := JobBoard.new()
	var log_b := LogisticsSystem.new(jb_b)
	var h_b := log_b.register_hauler(2, Vector2i(10, 11))
	var job_b := jb_b.create_job(&"timber", 4, town_hall.inventory, site_b.construction_inventory, 5, 1)
	log_b.dispatch_jobs()
	jb_b.execute_pickup(job_b, town_hall.inventory)
	h_b.carried_resource = &"timber"
	h_b.carried_amount = 4
	assert_eq(job_b.status, HaulJob.Status.IN_TRANSIT)
	
	# Cancel Site B while hauler is carrying cargo
	var inv_map_b := {town_hall.inventory.owner_id: town_hall.inventory, site_b.construction_inventory.owner_id: site_b.construction_inventory}
	var b_map_b := {town_hall.inventory.owner_id: town_hall}
	const_sys.cancel_construction_site(site_b, jb_b, town_hall.inventory, inv_map_b)
	
	# Verify cargo was NOT deleted or dropped
	assert_eq(h_b.carried_amount, 4, "Physical cargo must be retained by hauler")
	
	# Tick haulers: logistics detects destination missing, finds alternate destination (Town Hall), reserves in, and reroutes
	for t in range(3, 8):
		log_b.tick_haulers(inv_map_b, t, pathfinding, b_map_b)
		if h_b.carried_amount == 0:
			break
	assert_eq(job_b.status, HaulJob.Status.DELIVERED, "Job delivered to active Town Hall storage")
	assert_eq(h_b.carried_amount, 0, "Hauler delivered cargo and is free")
	assert_true(h_b.active_job == null, "Hauler has no stuck job")
	assert_eq(town_hall.inventory.get_quantity(&"timber"), 30, "All 30 timber preserved back in storage")
	
	# --- Subcase 1C: Attempting delivery at destination ---
	var site_c := const_sys.create_construction_site(30, &"quarry", Vector2i(35, 35), {&"timber": 4}, 8, 31)
	var jb_c := JobBoard.new()
	var log_c := LogisticsSystem.new(jb_c)
	var h_c := log_c.register_hauler(3, Vector2i(35, 36)) # Arrived right next to site
	var job_c := jb_c.create_job(&"timber", 4, town_hall.inventory, site_c.construction_inventory, 5, 1)
	log_c.dispatch_jobs()
	jb_c.execute_pickup(job_c, town_hall.inventory)
	h_c.carried_resource = &"timber"
	h_c.carried_amount = 4
	
	# Site C destroyed right as hauler attempts delivery
	var inv_map_c := {town_hall.inventory.owner_id: town_hall.inventory, site_c.construction_inventory.owner_id: site_c.construction_inventory}
	var b_map_c := {town_hall.inventory.owner_id: town_hall}
	const_sys.cancel_construction_site(site_c, jb_c, town_hall.inventory, inv_map_c)
	
	# Reroutes safely to Town Hall without double-counting or loss
	log_c.tick_haulers(inv_map_c, 5, pathfinding, b_map_c)
	assert_eq(job_c.destination_inventory_id, town_hall.inventory.owner_id)
	h_c.current_tile = Vector2i(10, 11)
	h_c.clear_path()
	for t in range(6, 12):
		log_c.tick_haulers(inv_map_c, t, pathfinding, b_map_c)
		if h_c.carried_amount == 0:
			break
			
	assert_eq(h_c.carried_amount, 0, "Hauler delivered cargo to Town Hall")
	assert_true(h_c.active_job == null, "Hauler freed")
	assert_eq(town_hall.inventory.get_quantity(&"timber"), 30, "All 30 timber preserved in Town Hall")
	print("✓ Hardening 1: Cargo recovery in all three hauler phases PASSED")

# Hardening Gap 2: Refund overflow preservation into fallback or explicit ground pile
func test_hardening_refund_overflow_to_ground_pile() -> void:
	var const_sys := ConstructionSystem.new()
	var town_hall := BuildingState.new(1, &"town_hall", 20)
	town_hall.inventory.add_resource(&"coin", 15, "EXISTING") # 15/20 used, free capacity = 5
	
	var storehouse := BuildingState.new(2, &"storehouse", 20)
	storehouse.inventory.add_resource(&"bread", 15, "EXISTING") # 15/20 used, free capacity = 5
	
	# Site has 12 timber and 8 stone delivered (total 20 items to refund, but TH+Storehouse only have 10 free capacity)
	var site := const_sys.create_construction_site(10, &"barracks", Vector2i(15, 15), {&"timber": 12, &"stone": 8}, 10, 11)
	site.construction_inventory.add_resource(&"timber", 12, "DELIVERY")
	site.construction_inventory.add_resource(&"stone", 8, "DELIVERY")
	assert_eq(site.construction_inventory.get_total_quantity(), 20)
	
	var jb := JobBoard.new()
	var inv_map := {
		town_hall.inventory.owner_id: town_hall.inventory,
		storehouse.inventory.owner_id: storehouse.inventory,
		site.construction_inventory.owner_id: site.construction_inventory
	}
	
	var refund := const_sys.cancel_construction_site(site, jb, town_hall.inventory, inv_map, [storehouse.inventory])
	
	# Verify Town Hall received up to capacity
	assert_eq(town_hall.inventory.get_total_quantity(), 20, "Town Hall must be full (20/20)")
	# Verify Storehouse received up to capacity
	assert_eq(storehouse.inventory.get_total_quantity(), 20, "Storehouse must be full (20/20)")
	# Verify Ground Pile was created and received the overflow
	assert_true(refund.has("ground_pile"), "Explicit ground pile must be created for overflow")
	var pile: Inventory = refund["ground_pile"]
	assert_true(pile != null)
	
	# Verify total resources preserved equals exact initial delivered quantity
	var th_timber: int = town_hall.inventory.get_quantity(&"timber")
	var sh_timber: int = storehouse.inventory.get_quantity(&"timber")
	var pile_timber: int = pile.get_quantity(&"timber")
	assert_eq(th_timber + sh_timber + pile_timber, 12, "All 12 timber must be preserved across storages and ground pile")
	
	var th_stone: int = town_hall.inventory.get_quantity(&"stone")
	var sh_stone: int = storehouse.inventory.get_quantity(&"stone")
	var pile_stone: int = pile.get_quantity(&"stone")
	assert_eq(th_stone + sh_stone + pile_stone, 8, "All 8 stone must be preserved across storages and ground pile")
	
	# Verify transaction was recorded
	var found_overflow_log := false
	for entry: Dictionary in pile.transaction_log:
		if entry.get("reason", "") == "CONSTRUCTION_SALVAGE_OVERFLOW_GROUND_PILE":
			found_overflow_log = true
			break
	assert_true(found_overflow_log, "Overflow transaction must be explicitly recorded in inventory log")
	print("✓ Hardening 2: Refund overflow preservation into ground pile PASSED")

# Hardening Gap 3: Concurrent reservations during same tick
func test_hardening_concurrent_reservations_same_tick() -> void:
	var const_sys := ConstructionSystem.new()
	var town_hall := BuildingState.new(1, &"town_hall", 150)
	town_hall.inventory.add_resource(&"timber", 6, "LIMITED_STOCK") # Only 6 timber available
	
	var site_a := const_sys.create_construction_site(10, &"farm", Vector2i(20, 20), {&"timber": 5}, 8, 11)
	var site_b := const_sys.create_construction_site(20, &"woodcutter", Vector2i(25, 25), {&"timber": 5}, 6, 21)
	var site_c := const_sys.create_construction_site(30, &"house", Vector2i(30, 30), {&"timber": 5}, 6, 31)
	
	var jb := JobBoard.new()
	
	# Site A requests 5 timber
	var avail_for_a: int = town_hall.inventory.get_available_outgoing(&"timber")
	assert_eq(avail_for_a, 6)
	var job_a := jb.create_job(&"timber", 5, town_hall.inventory, site_a.construction_inventory, 5, 1)
	assert_true(job_a != null)
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 5)
	assert_eq(town_hall.inventory.get_available_outgoing(&"timber"), 1)
	
	# Site B requests 5 timber in the same tick: only 1 is available unreserved
	var avail_for_b: int = town_hall.inventory.get_available_outgoing(&"timber")
	var transfer_b: int = mini(5, avail_for_b)
	assert_eq(transfer_b, 1)
	var job_b := jb.create_job(&"timber", transfer_b, town_hall.inventory, site_b.construction_inventory, 5, 1)
	assert_true(job_b != null)
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 6)
	assert_eq(town_hall.inventory.get_available_outgoing(&"timber"), 0)
	
	# Site C requests in the same tick: available is 0 -> cannot reserve!
	var avail_for_c: int = town_hall.inventory.get_available_outgoing(&"timber")
	assert_eq(avail_for_c, 0)
	var job_c := jb.create_job(&"timber", 1, town_hall.inventory, site_c.construction_inventory, 5, 1)
	assert_true(job_c == null, "Cannot create job when available outgoing stock is zero")
	
	# Total reserved out cannot exceed 6
	assert_eq(town_hall.inventory.get_reserved_out(&"timber"), 6)
	assert_eq(site_a.construction_inventory.get_reserved_in(&"timber"), 5)
	assert_eq(site_b.construction_inventory.get_reserved_in(&"timber"), 1)
	assert_eq(site_c.construction_inventory.get_reserved_in(&"timber"), 0)
	print("✓ Hardening 3: Concurrent reservations during same tick PASSED")

# Hardening Gap 4: Cleanup integrity and isolation from unrelated buildings
func test_hardening_cleanup_integrity_and_isolation() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	var origin: Vector2i = world.world_state.start_settlement_pos
	
	# Unrelated Building 1: Farm (ACTIVE with worker and stock)
	var farm := world.place_building(&"farm", origin + Vector2i(4, 0), true)
	assert_true(farm != null, "Farm should be placed")
	farm.status = BuildingState.Status.ACTIVE
	farm.inventory.add_resource(&"grain", 10, "HARVEST")
	var farmer := CitizenState.new(201, farm.tile_origin + Vector2i(0, -1), &"farmer")
	farmer.workplace_id = farm.entity_id
	world.citizens.append(farmer)
	farm.assigned_workers = 1
	
	# Unrelated Building 2: Bakery (ACTIVE with worker)
	var bakery := world.place_building(&"bakery", origin + Vector2i(4, 4), true)
	assert_true(bakery != null, "Bakery should be placed")
	bakery.status = BuildingState.Status.ACTIVE
	var baker := CitizenState.new(202, bakery.tile_origin + Vector2i(0, -1), &"baker")
	baker.workplace_id = bakery.entity_id
	world.citizens.append(baker)
	bakery.assigned_workers = 1
	
	# Target Building: Construction Site
	var site_coord := Vector2i(-1, -1)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var test_pos := origin + Vector2i(dx, dy)
			if world.can_place_building_at(&"storehouse", test_pos).get("ok", false):
				site_coord = test_pos
				break
		if site_coord != Vector2i(-1, -1):
			break
			
	assert_true(site_coord != Vector2i(-1, -1), "Must find a valid location to place storehouse site")
	var site := world.place_building(&"storehouse", site_coord, false)
	assert_true(site != null, "Storehouse construction site should be placed")
	assert_true(site.is_under_construction())
	var builder := CitizenState.new(203, site.tile_origin + Vector2i(0, -1), &"builder")
	builder.workplace_id = site.entity_id
	world.citizens.append(builder)
	site.assigned_workers = 1
	
	var initial_building_count: int = world.buildings.size()
	
	# Cancel the construction site
	world.cancel_construction_site(site)
	
	# Verify site is cleaned up completely
	assert_eq(world.buildings.size(), initial_building_count - 1)
	assert_true(not world.buildings.has(site))
	assert_true(world._find_inventory_by_id(site.construction_inventory.owner_id) == null, "Construction inventory removed from lookup")
	assert_eq(builder.workplace_id, 0, "Builder must be released from workplace")
	assert_eq(builder.role_id, &"unassigned", "Builder must be reset to unassigned")
	
	# Verify footprint tiles are completely freed in pathfinder and world
	for dy in range(2):
		for dx in range(3):
			var c: Vector2i = site.tile_origin + Vector2i(dx, dy)
			var tile: WorldTile = world.world_state.get_tile(c)
			assert_eq(tile.building_id, 0, "Tile building_id cleared")
			assert_true(tile.is_walkable, "Tile must be walkable")
			assert_true(not world.pathfinding.astar_grid.is_point_solid(c), "Tile in AStar must not be solid")
	
	# Verify unrelated buildings are 100% UNTOUCHED and fully functional
	assert_true(world.buildings.has(farm), "Farm must remain in buildings list")
	assert_eq(farm.status, BuildingState.Status.ACTIVE)
	assert_eq(farm.assigned_workers, 1)
	assert_eq(farmer.workplace_id, farm.entity_id)
	assert_eq(farmer.role_id, &"farmer")
	assert_eq(farm.inventory.get_quantity(&"grain"), 10)
	assert_true(world.pathfinding.astar_grid.is_point_solid(farm.tile_origin), "Farm footprint must remain solid")
	
	assert_true(world.buildings.has(bakery), "Bakery must remain in buildings list")
	assert_eq(bakery.status, BuildingState.Status.ACTIVE)
	assert_eq(bakery.assigned_workers, 1)
	assert_eq(baker.workplace_id, bakery.entity_id)
	assert_eq(baker.role_id, &"baker")
	print("✓ Hardening 4: Cleanup integrity and isolation from unrelated buildings PASSED")

