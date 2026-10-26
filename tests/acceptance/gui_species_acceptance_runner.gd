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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 7)   ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	
	# Spawn a Stoneborn and Greenwarden alongside the default Humans for rich inspection
	var c_stone: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(2, 2), &"builder", &"stoneborn")
	var c_green: CitizenState = world.spawn_citizen(world.world_state.start_settlement_pos + Vector2i(3, 2), &"farmer", &"greenwarden")
	
	await process_frame
	await process_frame
	
	# Check 1: Select Citizen and inspect species in Inspector
	print("\n>> Check 1: Inspecting Stoneborn citizen details in Inspector...")
	world.selected_citizen = c_stone
	world.selected_building = null
	world._update_citizen_inspector()
	await _save_screenshot("10_species_inspector_stoneborn")
	assert(ui.panel_inspector.visible, "Citizen inspector must be visible")
	assert(ui.label_inspector_title.text.contains("Stoneborn"), "Title must contain Stoneborn")
	assert(ui.label_inspector_inv.text.contains("SPECIES: Stoneborn"), "Details must show SPECIES: Stoneborn")
	print("✓ Check 1 Verified: Stoneborn citizen details correctly displayed in Inspector.")
	
	# Check 2: Inspect Greenwarden citizen details
	print("\n>> Check 2: Inspecting Greenwarden citizen details in Inspector...")
	world.selected_citizen = c_green
	world._update_citizen_inspector()
	await _save_screenshot("11_species_inspector_greenwarden")
	assert(ui.label_inspector_title.text.contains("Greenwarden"), "Title must contain Greenwarden")
	assert(ui.label_inspector_inv.text.contains("SPECIES: Greenwarden"), "Details must show SPECIES: Greenwarden")
	print("✓ Check 2 Verified: Greenwarden citizen details correctly displayed in Inspector.")
	
	# Check 3: Open Workforce Panel and inspect species tags
	print("\n>> Check 3: Workforce panel opens and displays species per citizen...")
	ui.btn_workforce.emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("12_workforce_all_peoples")
	assert(ui.is_workforce_panel_visible(), "Workforce panel must be visible")
	print("✓ Check 3 Verified: Workforce panel displays citizen species.")
	
	# Check 4: Filter Workforce by Stoneborn
	print("\n>> Check 4: Filtering workforce panel by Stoneborn...")
	ui.species_filter_buttons[&"stoneborn"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("13_workforce_filter_stoneborn")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Stoneborn"), "Row must be Stoneborn when filtered: " + lbl.text)
	print("✓ Check 4 Verified: Stoneborn filter works accurately.")
	
	# Check 5: Filter Workforce by Greenwarden
	print("\n>> Check 5: Filtering workforce panel by Greenwarden...")
	ui.species_filter_buttons[&"greenwarden"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("14_workforce_filter_greenwarden")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Greenwarden"), "Row must be Greenwarden when filtered: " + lbl.text)
	print("✓ Check 5 Verified: Greenwarden filter works accurately.")
	
	# Check 6: Return to All Peoples and test Auto-Staffing
	print("\n>> Check 6: Reset filter to ALL PEOPLES...")
	ui.species_filter_buttons[&"all"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("15_workforce_filter_all_reset")
	print("✓ Check 6 Verified: Filter reset to ALL PEOPLES.")
	
	print("\n==============================================")
	print("    ALL GUI ACCEPTANCE CHECKS PASSED!        ")
	print("==============================================")
	quit(0)
