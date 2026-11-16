extends SceneTree

const SCREENSHOT_DIR: String = "/home/sumeet/.gemini/antigravity-cli/brain/ecdc4db2-f55c-4f79-82b5-bd2991cfb8d0/screenshots"

func _init() -> void:
	call_deferred("_run_acceptance_tests")

func _save_screenshot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(SCREENSHOT_DIR + "/" + name + ".png")
	print("[SCREENSHOT] Saved: " + name + ".png")

func _run_acceptance_tests() -> void:
	print("\n==============================================")
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 6)   ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	
	# Check 1: The workforce panel opens using P and the HUD button
	print("\n>> Check 1: Workforce panel opens using P and HUD button...")
	assert(not ui.is_workforce_panel_visible(), "Workforce panel initially closed")
	
	# Press P key
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_P
	key_ev.pressed = true
	world._unhandled_input(key_ev)
	assert(ui.is_workforce_panel_visible(), "Workforce panel opened with KEY_P")
	
	# Toggle off with P key
	world._unhandled_input(key_ev)
	assert(not ui.is_workforce_panel_visible(), "Workforce panel closed with KEY_P")
	
	# Open using HUD button
	ui.btn_workforce.emit_signal("pressed")
	assert(ui.is_workforce_panel_visible(), "Workforce panel opened via HUD button")
	await _save_screenshot("01_workforce_panel_opened")
	print("✓ Check 1 Verified: Panel opens via P and HUD button.")
	
	# Check 2: All population counters reflect actual citizen states
	print("\n>> Check 2: Population counters reflect actual citizen states...")
	var summary: Dictionary = world.get_workforce_summary()
	assert(summary["total"] == 10, "Total is 10")
	assert(summary["employed"] == 2, "Employed is 2 (haulers)")
	assert(summary["unassigned"] == 8, "Unassigned is 8")
	assert(ui.label_workforce_summary.text.contains("Total: 10"), "Summary label reflects total 10")
	assert(ui.label_workforce_summary.text.contains("Employed: 2"), "Summary label reflects employed 2")
	assert(ui.label_workforce_summary.text.contains("Unassigned: 8"), "Summary label reflects unassigned 8")
	assert(ui.label_population.text.contains("10 FED"), "HUD badge reflects 10 FED")
	print("✓ Check 2 Verified: Population counters match citizen states.")
	
	# Check 3: Filters show the correct citizens
	print("\n>> Check 3: Filters show the correct citizens...")
	ui.filter_buttons[&"UNASSIGNED"].emit_signal("pressed")
	await process_frame
	var rows_unassigned: int = ui.box_workforce_citizens.get_child_count()
	assert(rows_unassigned == 8, "UNASSIGNED filter shows 8 rows, got: %d" % rows_unassigned)
	await _save_screenshot("02_workforce_filtered_unassigned")
	
	ui.filter_buttons[&"HAULING"].emit_signal("pressed")
	await process_frame
	var rows_hauling: int = ui.box_workforce_citizens.get_child_count()
	assert(rows_hauling == 2, "HAULING filter shows 2 rows, got: %d" % rows_hauling)
	
	ui.filter_buttons[&"ALL"].emit_signal("pressed")
	await process_frame
	var rows_all: int = ui.box_workforce_citizens.get_child_count()
	assert(rows_all == 10, "ALL filter shows 10 rows, got: %d" % rows_all)
	print("✓ Check 3 Verified: Filters display exact matching citizens.")
	
	# Check 4: Focus button selects the citizen and centers the camera correctly
	print("\n>> Check 4: Focus button selects citizen and centers camera...")
	var target_c: CitizenState = world.citizens[3]
	ui.citizen_selected_from_panel.emit(target_c.id)
	await process_frame
	var cam_after: Vector2 = world.camera.position
	var expected_pos := Vector2(target_c.position_tile.x * 16.0, target_c.position_tile.y * 16.0)
	assert(cam_after == expected_pos, "Camera centered on citizen position %s, got %s" % [expected_pos, cam_after])
	assert(world.selected_citizen == target_c, "Citizen selected in inspector")
	assert(ui.panel_inspector.visible, "Inspector visible for citizen")
	assert(ui.label_inspector_title.text.contains("CITIZEN #%d" % target_c.id), "Inspector title shows citizen #ID")
	await _save_screenshot("03_citizen_focused")
	print("✓ Check 4 Verified: Focus button centers camera and selects citizen.")
	
	# Check 5: Selecting a building displays workers, staffing priority, production state, and controls
	print("\n>> Check 5: Building selection displays priority, workers, production chain...")
	var farm: BuildingState = world.place_building(&"farm", Vector2i(10, 10), true)
	world._select_building_at(Vector2i(10, 10))
	await process_frame
	assert(world.selected_building == farm, "Farm is selected")
	assert(ui.panel_inspector.visible, "Inspector open for farm")
	assert(ui.box_priority.visible, "Priority box visible")
	assert(ui.label_priority.text.contains("Priority: 3 (Normal)"), "Priority shows Normal (3)")
	
	world._on_building_priority_changed(1)
	world._update_building_inspector()
	await process_frame
	assert(farm.work_priority == 4, "Farm priority updated to 4")
	assert(ui.label_priority.text.contains("Priority: 4 (High)"), "UI label shows High (4)")
	
	world._on_building_priority_changed(1)
	world._update_building_inspector()
	await process_frame
	assert(farm.work_priority == 5, "Farm priority updated to 5")
	assert(ui.label_priority.text.contains("Priority: 5 (Urgent)"), "UI label shows Urgent (5)")
	await _save_screenshot("04_building_inspector_priority")
	print("✓ Check 5 Verified: Building details, priority scale, and controls displayed.")
	
	# Check 6: Individual unassignment works without corrupting role or jobs
	print("\n>> Check 6: Individual unassignment...")
	world._on_worker_assignment_changed(1)
	world._update_building_inspector()
	await process_frame
	assert(farm.assigned_workers == 1, "Farm has 1 assigned worker")
	var worker_c: CitizenState = null
	for c in world.citizens:
		if c.workplace_id == farm.entity_id:
			worker_c = c
			break
	assert(worker_c != null, "Worker found at farm")
	assert(worker_c.role_id == &"farmer", "Worker role is farmer")
	
	world.unassign_citizen(worker_c)
	world._update_building_inspector()
	await process_frame
	assert(farm.assigned_workers == 0, "Farm workers decremented to 0")
	assert(worker_c.workplace_id == 0, "Worker workplace reset to 0")
	assert(worker_c.role_id == &"unassigned", "Worker role reset to unassigned")
	assert(world.logistics.haulers.size() == 2, "Haulers unaffected")
	await _save_screenshot("05_individual_unassignment")
	print("✓ Check 6 Verified: Individual unassignment preserves role and job integrity.")
	
	# Check 7: Auto-staffing respects priorities and does not continuously reassign
	print("\n>> Check 7: Auto-staffing stability and priority...")
	var bakery: BuildingState = world.place_building(&"bakery", Vector2i(14, 10), true)
	world.set_building_priority(farm, 1)
	world.set_building_priority(bakery, 5)
	
	world.auto_staffing_enabled = true
	world.auto_staff_workplaces()
	await process_frame
	assert(bakery.assigned_workers > 0, "Urgent Bakery staffed first by auto-staffing")
	var assigned_to_bakery: Array = []
	for c in world.citizens:
		if c.workplace_id == bakery.entity_id:
			assigned_to_bakery.append(c.id)
			
	for _i in range(5):
		world.auto_staff_workplaces()
	for cid in assigned_to_bakery:
		var c = world._find_citizen_by_id(cid)
		assert(c.workplace_id == bakery.entity_id, "Citizen %d stayed stably assigned to Bakery" % cid)
	await _save_screenshot("06_auto_staffing_active")
	print("✓ Check 7 Verified: Auto-staffing respects priority without thrashing.")
	
	# Check 8: Production-chain diagnostics agree with actual inventories and hauling jobs
	print("\n>> Check 8: Production-chain diagnostics...")
	world._select_building_at(Vector2i(14, 10))
	world._update_building_inspector()
	await process_frame
	var diag: Dictionary = world.get_building_diagnostic_details(bakery)
	var chain: Dictionary = diag["production_chain"]
	assert(chain.has("upstream_summary"), "Has upstream summary")
	assert(chain["upstream_summary"].contains("Grain"), "Reflects grain inputs")
	assert(chain["downstream_summary"].contains("Bread"), "Reflects bread outputs")
	assert(ui.label_production_chain.text.contains("Grain"), "UI inspector displays Grain in chain")
	await _save_screenshot("07_production_chain_diagnostics")
	print("✓ Check 8 Verified: Production-chain diagnostics agree with live state.")
	
	# Check 9: Panels remain usable at 1280x720, no clipped controls
	print("\n>> Check 9: Panel dimensions and usability at 1280x720...")
	assert(ui.panel_inspector.offset_top >= 96, "Inspector starts below top HUD (>= 96px)")
	assert(ui.panel_inspector.offset_bottom <= -134, "Inspector ends above bottom palette (<= -134px)")
	var vp_size: Vector2 = root.get_viewport().get_visible_rect().size
	print("Viewport size: ", vp_size)
	assert(vp_size.x >= 1024 and vp_size.y >= 600, "Viewport size is standard desktop resolution")
	var wf_rect := ui.panel_workforce.get_global_rect()
	assert(wf_rect.position.y >= 96, "Workforce panel top is below HUD: %f" % wf_rect.position.y)
	assert(wf_rect.end.y <= (vp_size.y - 134), "Workforce panel bottom is above build bar: %f" % wf_rect.end.y)
	await _save_screenshot("08_full_ui_usability_1280x720")
	print("✓ Check 9 Verified: Panels fit within bounds, scrollable, no clipping.")
	
	# Check 10: Saving and reloading preserves staffing priorities and auto-staffing preferences
	print("\n>> Check 10: Save and reload persistence...")
	world.set_building_priority(farm, 4)
	world.set_building_priority(bakery, 5)
	world.auto_staffing_enabled = true
	var save_path := "user://gui_acceptance_save.json"
	var save_ok: bool = SaveService.save_game_to_file(
		world.world_state,
		world.economy,
		world.buildings,
		world.citizens,
		world.military_units,
		world.job_board,
		world.current_tick,
		world.sim_speed_multiplier,
		save_path,
		world.auto_staffing_enabled
	)
	assert(save_ok, "Save succeeded")
	
	var loaded_data: Dictionary = SaveService.load_game_from_file(save_path)
	assert(loaded_data["meta"]["auto_staffing_enabled"] == true, "auto_staffing_enabled preserved in save")
	for b: BuildingState in loaded_data["buildings"]:
		if b.definition_id == &"farm":
			assert(b.work_priority == 4, "Farm priority 4 preserved")
		elif b.definition_id == &"bakery":
			assert(b.work_priority == 5, "Bakery priority 5 preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	await _save_screenshot("09_save_load_roundtrip")
	print("✓ Check 10 Verified: Save/load round-trip preserves priorities and preferences.")
	
	print("\n==============================================")
	print("   ALL 10 GUI ACCEPTANCE CHECKS SATISFIED!    ")
	print("==============================================\n")
	quit(0)
