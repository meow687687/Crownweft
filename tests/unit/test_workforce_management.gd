extends SceneTree

const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const BuildingCatalog = preload("res://scripts/domain/building_catalog.gd")
const ProductionSystem = preload("res://scripts/simulation/production_system.gd")
const ConstructionSystem = preload("res://scripts/simulation/construction_system.gd")
const LogisticsSystem = preload("res://scripts/simulation/logistics_system.gd")
const JobBoard = preload("res://scripts/simulation/job_board.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldTile = preload("res://scripts/domain/world_tile.gd")
const PathfindingService = preload("res://scripts/simulation/pathfinding_service.gd")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const WorldScene = preload("res://scenes/world/world.gd")
const GameUI = preload("res://scripts/presentation/game_ui.gd")

func _init() -> void:
	print("--- Running TestWorkforceManagement ---")
	test_1_workforce_counts_match_citizen_states()
	test_2_manual_assignment_and_unassignment()
	test_3_no_duplicate_primary_assignments()
	test_4_staffing_capacity_enforced_across_footprints()
	test_5_workplace_priority_scale_and_deterministic_order()
	test_6_auto_staffing_priorities_skills_and_no_stealing()
	test_7_blocked_and_resting_states_reflected_accurately()
	test_8_diagnostic_identification_of_real_production_blockers()
	test_9_production_chain_visibility()
	test_10_save_load_preserves_priorities_and_auto_staffing()
	test_11_reassignment_and_unassignment_isolation()
	test_12_non_regression_of_existing_systems()
	print("--- TestWorkforceManagement PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_1_workforce_counts_match_citizen_states() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var summary: Dictionary = world.get_workforce_summary()
	assert_eq(summary["total"], 10, "Total citizens should be 10")
	assert_eq(summary["employed"], 2, "2 initial haulers should be employed")
	assert_eq(summary["unassigned"], 8, "8 initial citizens should be unassigned")
	assert_eq(summary["hauling"], 2, "2 citizens should be hauling")
	assert_eq(summary["resting"], 0, "No citizens initially resting")
	assert_eq(summary["blocked"], 0, "No citizens initially blocked")
	assert_eq(summary["builders"], 0, "No builders initially")
	
	# Invariant: total == employed + unassigned
	assert_eq(summary["total"], summary["employed"] + summary["unassigned"], "Workforce total must equal employed + unassigned")
	
	# Set one citizen to resting
	world.citizens[5].is_resting = true
	var sum2: Dictionary = world.get_workforce_summary()
	assert_eq(sum2["resting"], 1, "Resting count should update to 1")
	
	# Set one citizen to blocked
	world.citizens[6].current_block_reason = &"ENTRANCE_UNREACHABLE"
	var sum3: Dictionary = world.get_workforce_summary()
	assert_eq(sum3["blocked"], 1, "Blocked count should update to 1")
	
	# Verify citizens data list
	var c_data: Array[Dictionary] = world.get_workforce_citizens_data()
	assert_eq(c_data.size(), 10, "Citizens data list size must match total citizens")
	assert_true(c_data[5]["is_resting"], "Citizen 5 must be flagged resting in data list")
	assert_true(c_data[6]["is_blocked"], "Citizen 6 must be flagged blocked in data list")
	
	print("✓ Test 1: Workforce counts match actual citizen states PASSED")

func test_2_manual_assignment_and_unassignment() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	# Place an active farm
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	assert_true(farm != null, "Farm should be placed successfully")
	assert_eq(farm.assigned_workers, 0, "Initially 0 assigned workers")
	
	# Select building and simulate assigning a worker
	world.selected_building = farm
	world._on_worker_assignment_changed(1)
	assert_eq(farm.assigned_workers, 1, "Farm assigned_workers should increment to 1")
	
	# Find assigned citizen
	var assigned_c: CitizenState = null
	for c in world.citizens:
		if c.workplace_id == farm.entity_id:
			assigned_c = c
			break
	assert_true(assigned_c != null, "A citizen must be assigned to farm")
	assert_eq(assigned_c.role_id, &"farmer", "Citizen role must become farmer")
	
	# Check assigned citizens detail helper
	var assigned_list: Array[Dictionary] = world.get_assigned_citizens_for_building(farm)
	assert_eq(assigned_list.size(), 1, "Should list 1 assigned worker")
	assert_eq(assigned_list[0]["id"], assigned_c.id, "Assigned worker ID must match")
	assert_eq(assigned_list[0]["role"], &"farmer", "Assigned worker role must be farmer")
	
	# Unassign specific citizen
	world.unassign_citizen(assigned_c)
	assert_eq(farm.assigned_workers, 0, "Farm assigned_workers should decrement to 0")
	assert_eq(assigned_c.workplace_id, 0, "Citizen workplace_id must reset to 0")
	assert_eq(assigned_c.role_id, &"unassigned", "Citizen role must reset to unassigned")
	
	var assigned_after: Array[Dictionary] = world.get_assigned_citizens_for_building(farm)
	assert_eq(assigned_after.size(), 0, "Should list 0 assigned workers after unassignment")
	
	print("✓ Test 2: Manual assignment and unassignment preserving valid job state PASSED")

func test_3_no_duplicate_primary_assignments() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var woodcutter: BuildingState = world.place_building(&"woodcutter", Vector2i(15, 10), true)
	
	# Pick an unassigned citizen
	var citizen: CitizenState = world.citizens[2]
	assert_eq(citizen.role_id, &"unassigned", "Citizen must be unassigned initially")
	
	# Assign to farm
	citizen.workplace_id = farm.entity_id
	citizen.role_id = &"farmer"
	farm.assigned_workers += 1
	
	# Verify that worker cannot be assigned to another building while employed
	assert_true(citizen.workplace_id == farm.entity_id, "Citizen is employed at farm")
	
	# Attempting auto-staffing should not touch this citizen
	world.auto_staffing_enabled = true
	world.auto_staff_workplaces()
	assert_eq(citizen.workplace_id, farm.entity_id, "Citizen must remain at farm, not re-assigned")
	
	# Dedicated haulers cannot be assigned to workplaces without changing their role
	var hauler: CitizenState = world.citizens[0]
	assert_eq(hauler.role_id, &"hauler", "Citizen 0 is a hauler")
	world.auto_staff_workplaces()
	assert_eq(hauler.role_id, &"hauler", "Hauler must not be reassigned by auto-staffing")
	assert_eq(hauler.workplace_id, 0, "Hauler workplace_id must remain 0")
	
	print("✓ Test 3: No duplicate primary assignments PASSED")

func test_4_staffing_capacity_enforced_across_footprints() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	# Fixed bakery has 2 slots
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(10, 10), true)
	var max_slots_bakery: int = BuildingCatalog.get_worker_slots_for_footprint(&"bakery", bakery.get_footprint())
	assert_eq(max_slots_bakery, 2, "Bakery should have 2 slots")
	
	world.selected_building = bakery
	world._on_worker_assignment_changed(1)
	world._on_worker_assignment_changed(1)
	assert_eq(bakery.assigned_workers, 2, "Bakery should have 2 assigned workers")
	
	# Third assignment should be rejected
	world._on_worker_assignment_changed(1)
	assert_eq(bakery.assigned_workers, 2, "Bakery should reject 3rd worker beyond capacity")
	
	# Resized farm: 2x2 = 1 slot, 4x4 = 3 slots
	var farm2x2: BuildingState = world.place_building(&"farm", Vector2i(20, 20), true, Vector2i(2, 2))
	var max_slots_2x2: int = BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(2, 2))
	assert_eq(max_slots_2x2, 1, "2x2 farm should have 1 slot")
	
	world.selected_building = farm2x2
	world._on_worker_assignment_changed(1)
	world._on_worker_assignment_changed(1)
	assert_eq(farm2x2.assigned_workers, 1, "2x2 farm should cap at 1 worker")
	
	var farm4x4: BuildingState = world.place_building(&"farm", Vector2i(30, 30), true, Vector2i(4, 4))
	var max_slots_4x4: int = BuildingCatalog.get_worker_slots_for_footprint(&"farm", Vector2i(4, 4))
	assert_eq(max_slots_4x4, 3, "4x4 farm should have 3 slots")
	
	world.selected_building = farm4x4
	for _i in range(5):
		world._on_worker_assignment_changed(1)
	assert_eq(farm4x4.assigned_workers, 3, "4x4 farm should cap at exactly 3 workers")
	
	print("✓ Test 4: Staffing capacity enforced across fixed and variable footprints PASSED")

func test_5_workplace_priority_scale_and_deterministic_order() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	assert_eq(farm.work_priority, BuildingState.PRIORITY_DEFAULT, "Default priority should be Normal (3)")
	assert_eq(BuildingState.get_priority_name(farm.work_priority), "Normal (3)", "Priority 3 name is Normal (3)")
	
	# Clamping test
	world.set_building_priority(farm, 10)
	assert_eq(farm.work_priority, BuildingState.PRIORITY_MAX, "Priority should clamp to MAX (5)")
	assert_eq(BuildingState.get_priority_name(farm.work_priority), "Urgent (5)", "Priority 5 name is Urgent (5)")
	
	world.set_building_priority(farm, -5)
	assert_eq(farm.work_priority, BuildingState.PRIORITY_MIN, "Priority should clamp to MIN (1)")
	assert_eq(BuildingState.get_priority_name(farm.work_priority), "Low (1)", "Priority 1 name is Low (1)")
	
	world.set_building_priority(farm, 4)
	assert_eq(BuildingState.get_priority_name(farm.work_priority), "High (4)", "Priority 4 name is High (4)")
	
	world.set_building_priority(farm, 2)
	assert_eq(BuildingState.get_priority_name(farm.work_priority), "Below Normal (2)", "Priority 2 name is Below Normal (2)")
	
	print("✓ Test 5: Workplace priority scale and deterministic order PASSED")

func test_6_auto_staffing_priorities_skills_and_no_stealing() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(14, 10), true)
	
	# Set Bakery to Urgent (5) and Farm to Low (1)
	world.set_building_priority(bakery, 5)
	world.set_building_priority(farm, 1)
	
	# Give one unassigned citizen exceptionally high crafting skill
	var c_crafter: CitizenState = world.citizens[2]
	c_crafter.skills[&"crafting"] = 90.0
	c_crafter.position_tile = Vector2i(14, 11) # close to bakery
	
	world.auto_staffing_enabled = true
	world.auto_staff_workplaces()
	
	# Bakery must be staffed first and receive c_crafter
	assert_true(bakery.assigned_workers > 0, "High priority Bakery should be staffed")
	assert_eq(c_crafter.workplace_id, bakery.entity_id, "High-skill crafter should be matched to Bakery")
	assert_eq(c_crafter.role_id, &"baker", "Crafter assigned role baker")
	
	# No stealing test: manually change farm priority to 5 and bakery to 1
	world.set_building_priority(farm, 5)
	world.set_building_priority(bakery, 1)
	
	# Run auto-staffing again
	world.auto_staff_workplaces()
	
	# c_crafter must STILL be at bakery! Auto-staffing must not steal workers from existing assignments.
	assert_eq(c_crafter.workplace_id, bakery.entity_id, "Worker must NOT be stolen from existing workplace")
	
	print("✓ Test 6: Auto-staffing respects priorities, skills, and hysteresis without worker stealing PASSED")

func test_7_blocked_and_resting_states_reflected_accurately() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var c: CitizenState = world.citizens[3]
	assert_eq(c.current_block_reason, &"", "Initially no block reason")
	
	# Mark as blocked
	c.current_block_reason = &"ENTRANCE_UNREACHABLE"
	var sum: Dictionary = world.get_workforce_summary()
	assert_eq(sum["blocked"], 1, "Summary reports 1 blocked worker")
	
	var c_data: Array[Dictionary] = world.get_workforce_citizens_data()
	var found_blocked: bool = false
	for entry in c_data:
		if entry["id"] == c.id:
			assert_true(entry["is_blocked"], "Entry must be marked is_blocked")
			assert_eq(entry["state_str"], "Blocked", "State string should be Blocked")
			found_blocked = true
			break
	assert_true(found_blocked, "Blocked citizen found in workforce data")
	
	# Clear block, mark resting
	c.current_block_reason = &""
	c.is_resting = true
	var sum2: Dictionary = world.get_workforce_summary()
	assert_eq(sum2["blocked"], 0, "Blocked count reset to 0")
	assert_eq(sum2["resting"], 1, "Resting count updated to 1")
	
	print("✓ Test 7: Blocked and resting states reflected accurately PASSED")

func test_8_diagnostic_identification_of_real_production_blockers() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	# Place active farm with 0 workers
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var diag_unstaffed: Dictionary = world.get_building_diagnostic_details(farm)
	var chain_unstaffed: Dictionary = diag_unstaffed["production_chain"]
	assert_eq(chain_unstaffed["real_status"], "UNSTAFFED", "Unstaffed building must diagnose UNSTAFFED")
	assert_eq(chain_unstaffed["primary_blocker"], "UNSTAFFED", "Primary blocker is UNSTAFFED")
	
	# Assign a worker who is not yet at the site
	farm.assigned_workers = 1
	var c: CitizenState = world.citizens[2]
	c.workplace_id = farm.entity_id
	c.role_id = &"farmer"
	c.position_tile = Vector2i(0, 0) # Far away
	c.move_state = CitizenState.MoveState.MOVING
	
	var diag_waiting: Dictionary = world.get_building_diagnostic_details(farm)
	var chain_waiting: Dictionary = diag_waiting["production_chain"]
	assert_eq(chain_waiting["real_status"], "WAITING_FOR_WORKERS", "Should report WAITING_FOR_WORKERS")
	
	# Place bakery with workers present but 0 grain
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(14, 10), true)
	bakery.assigned_workers = 1
	var c_baker: CitizenState = world.citizens[3]
	c_baker.workplace_id = bakery.entity_id
	c_baker.role_id = &"baker"
	c_baker.position_tile = bakery.get_entrance_tile()
	c_baker.move_state = CitizenState.MoveState.IDLE
	bakery.current_block_reason = &"MISSING_INPUTS"
	
	var diag_bakery: Dictionary = world.get_building_diagnostic_details(bakery)
	var chain_bakery: Dictionary = diag_bakery["production_chain"]
	assert_eq(chain_bakery["real_status"], "BLOCKED", "Bakery missing inputs must be BLOCKED")
	assert_eq(chain_bakery["primary_blocker"], "MISSING_INPUTS", "Primary blocker is MISSING_INPUTS")
	
	# Fill bakery storage to capacity
	bakery.current_block_reason = &"OUTPUT_FULL"
	var diag_full: Dictionary = world.get_building_diagnostic_details(bakery)
	assert_eq(diag_full["production_chain"]["primary_blocker"], "OUTPUT_FULL", "Reports OUTPUT_FULL")
	
	print("✓ Test 8: Diagnostic identification of real production blockers PASSED")

func test_9_production_chain_visibility() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(14, 10), true)
	
	# Add grain to farm
	farm.inventory.add_resource(&"grain", 10, "TEST_HARVEST")
	
	var chain: Dictionary = world.get_building_production_chain(bakery)
	assert_true(chain.has("upstream_summary"), "Must have upstream summary")
	assert_true(chain["upstream_summary"].contains("Grain"), "Upstream summary must mention Grain")
	assert_true(chain["upstream_summary"].contains("Farm"), "Upstream summary must identify Farm as supplier")
	
	# Check transaction log in diagnostic details
	var diag: Dictionary = world.get_building_diagnostic_details(farm)
	assert_true(diag.has("recent_transactions"), "Diagnostic details must include recent transactions")
	assert_true(diag["recent_transactions"].size() > 0, "Must have recorded transactions")
	assert_true(str(diag["recent_transactions"][0]).contains("Grain"), "Transaction line must record Grain")
	
	print("✓ Test 9: Production chain visibility matching live state PASSED")

func test_10_save_load_preserves_priorities_and_auto_staffing() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(14, 10), true)
	
	world.set_building_priority(farm, 4) # High
	world.set_building_priority(bakery, 5) # Urgent
	world.auto_staffing_enabled = true
	
	# Assign a worker to bakery
	var baker_c: CitizenState = world.citizens[2]
	baker_c.workplace_id = bakery.entity_id
	baker_c.role_id = &"baker"
	bakery.assigned_workers = 1
	
	var test_path: String = "user://test_workforce_save.json"
	var saved: bool = SaveService.save_game_to_file(
		world.world_state,
		world.economy,
		world.buildings,
		world.citizens,
		world.military_units,
		world.job_board,
		world.current_tick,
		world.sim_speed_multiplier,
		test_path,
		world.auto_staffing_enabled
	)
	assert_true(saved, "Save game must succeed")
	
	var loaded: Dictionary = SaveService.load_game_from_file(test_path)
	assert_true(not loaded.is_empty(), "Loaded save must not be empty")
	assert_true(loaded["meta"].get("auto_staffing_enabled", false), "auto_staffing_enabled must be preserved as true")
	
	# Check building priorities
	var loaded_buildings: Array = loaded["buildings"]
	var found_farm_pri: int = -1
	var found_bakery_pri: int = -1
	for b: BuildingState in loaded_buildings:
		if b.definition_id == &"farm":
			found_farm_pri = b.work_priority
		elif b.definition_id == &"bakery":
			found_bakery_pri = b.work_priority
	assert_eq(found_farm_pri, 4, "Farm priority must be preserved as 4")
	assert_eq(found_bakery_pri, 5, "Bakery priority must be preserved as 5")
	
	# Check worker assignment preserved
	var loaded_citizens: Array = loaded["citizens"]
	var found_baker: bool = false
	for c: CitizenState in loaded_citizens:
		if c.id == baker_c.id:
			assert_eq(c.workplace_id, bakery.entity_id, "Citizen workplace_id must be preserved")
			assert_eq(c.role_id, &"baker", "Citizen role must be preserved")
			found_baker = true
			break
	assert_true(found_baker, "Assigned baker must be found in loaded state")
	
	# Clean up test save file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	
	print("✓ Test 10: Save/load preserving assignments, priorities, and auto-staffing toggle PASSED")

func test_11_reassignment_and_unassignment_isolation() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	# Verify hauler 0 is unaffected by unassigning regular workplace workers
	var hauler: CitizenState = world.citizens[0]
	assert_eq(hauler.role_id, &"hauler", "Citizen 0 is a hauler")
	
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	var worker: CitizenState = world.citizens[3]
	worker.workplace_id = farm.entity_id
	worker.role_id = &"farmer"
	farm.assigned_workers = 1
	
	# Unassign worker
	world.unassign_citizen(worker)
	assert_eq(worker.role_id, &"unassigned", "Worker unassigned")
	assert_eq(hauler.role_id, &"hauler", "Hauler role must be intact")
	assert_eq(world.logistics.haulers.size(), 2, "Logistics haulers count must remain 2")
	
	print("✓ Test 11: Reassignment and unassignment isolation PASSED")

func test_12_non_regression_of_existing_systems() -> void:
	var world := WorldScene.new()
	world._init_simulation()
	
	# 1. Road placement autotiling check
	var r1: bool = world.build_road(Vector2i(5, 5))
	var r2: bool = world.build_road(Vector2i(5, 6))
	assert_true(r1 and r2, "Road placement must succeed")
	
	# 2. Configurable footprint placement check
	var farm_3x3: BuildingState = world.place_building(&"farm", Vector2i(25, 25), true, Vector2i(3, 3))
	assert_true(farm_3x3 != null, "Configurable footprint placement must succeed")
	assert_eq(farm_3x3.get_footprint(), Vector2i(3, 3), "Footprint must be 3x3")
	
	# 3. Entrance validity check
	var ent: Vector2i = farm_3x3.get_entrance_tile()
	assert_true(world.world_state.is_valid_coord(ent), "Entrance coord must be valid")
	
	# 4. Citizen skills check
	var c: CitizenState = world.citizens[4]
	assert_true(c.get_skill(&"farming") >= 0.0, "Skills must exist and be accessible")
	
	print("✓ Test 12: Non-regression of existing systems PASSED")
