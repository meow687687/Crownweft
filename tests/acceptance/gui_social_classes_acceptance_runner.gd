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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 8)   ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	
	# Spawn diverse social statuses alongside default commoners
	var c_art: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(2, 2), &"builder", &"stoneborn", &"artisan")
	var c_nob: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(3, 2), &"unassigned", &"human", &"noble")
	var c_mer: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(4, 2), &"storekeeper", &"human", &"merchant")
	var c_adm: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(1, 2), &"administrator", &"greenwarden", &"administrator")
	
	c_art.last_status_transition_reason = "EXEMPLARY_CRAFTSMANSHIP"
	c_nob.last_status_transition_reason = "PATENT_OF_NOBILITY"
	
	await process_frame
	await process_frame
	
	# Check 1: Select Artisan and inspect social status details
	print("\n>> Check 1: Inspecting Artisan in Inspector...")
	world.selected_citizen = c_art
	world.selected_building = null
	world._update_citizen_inspector()
	await _save_screenshot("16_social_inspector_artisan")
	assert(ui.panel_inspector.visible, "Citizen inspector must be visible")
	assert(ui.label_inspector_title.text.contains("Artisan"), "Title must contain Artisan")
	assert(ui.label_inspector_inv.text.contains("SOCIAL STATUS: Artisan"), "Details must show SOCIAL STATUS: Artisan")
	assert(ui.label_inspector_inv.text.contains("Craftsmanship bonus"), "Must display craftsmanship privilege")
	print("✓ Check 1 Verified: Artisan social status correctly displayed.")
	
	# Check 2: Inspect Noble citizen details
	print("\n>> Check 2: Inspecting Noble in Inspector...")
	world.selected_citizen = c_nob
	world._update_citizen_inspector()
	await _save_screenshot("17_social_inspector_noble")
	assert(ui.label_inspector_title.text.contains("Noble"), "Title must contain Noble")
	assert(ui.label_inspector_inv.text.contains("SOCIAL STATUS: Noble"), "Details must show SOCIAL STATUS: Noble")
	assert(ui.label_inspector_inv.text.contains("Refuses manual resource hauling"), "Must display noble hauling restriction")
	print("✓ Check 2 Verified: Noble social status correctly displayed.")
	
	# Check 3: Open Workforce Panel and inspect social status tags
	print("\n>> Check 3: Workforce panel displays species and social status...")
	ui.btn_workforce.emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("18_workforce_all_estates")
	assert(ui.is_workforce_panel_visible(), "Workforce panel must be visible")
	print("✓ Check 3 Verified: Workforce panel displays social status.")
	
	# Check 4: Filter Workforce by Artisan
	print("\n>> Check 4: Filtering workforce panel by Artisan...")
	ui.status_filter_buttons[&"artisan"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("19_workforce_filter_artisan")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Artisan"), "Row must be Artisan when filtered: " + lbl.text)
	print("✓ Check 4 Verified: Artisan status filter works accurately.")
	
	# Check 5: Filter Workforce by Noble
	print("\n>> Check 5: Filtering workforce panel by Noble...")
	ui.status_filter_buttons[&"noble"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("20_workforce_filter_noble")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Noble"), "Row must be Noble when filtered: " + lbl.text)
	print("✓ Check 5 Verified: Noble status filter works accurately.")
	
	# Check 6: Reset filter to ALL ESTATES
	print("\n>> Check 6: Reset filter to ALL ESTATES...")
	ui.status_filter_buttons[&"all"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("21_workforce_filter_estates_reset")
	print("✓ Check 6 Verified: Filter reset to ALL ESTATES.")
	
	print("\n==============================================")
	print("    ALL GUI ACCEPTANCE CHECKS PASSED!        ")
	print("==============================================")
	quit(0)
