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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 10)  ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	
	# Spawn test citizens
	var c_admin: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(2, 2),
		&"administrator",
		&"human",
		&"noble"
	)
	
	var c_woodcutter: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(3, 2),
		&"woodcutter",
		&"human",
		&"commoner"
	)
	
	var c_conservationist: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(4, 2),
		&"farmer",
		&"greenwarden",
		&"commoner",
		&"sylvanari",
		&"old_grove",
		&"sylvan_harmony"
	)
	c_conservationist.set_conviction(&"nature_conservation", 0.85)

	# Place a woodcutter hut and assign c_woodcutter
	var woodcutter_def: Dictionary = BuildingCatalog.get_all_defs().get(&"woodcutter", {})
	var wood_pos: Vector2i = world.world_state.start_settlement_pos + Vector2i(6, 6)
	var woodcutter_b: BuildingState = world.place_building(&"woodcutter", wood_pos, true)
	assert(woodcutter_b != null, "Woodcutter building must be placed")
	woodcutter_b.assigned_workers = 1
	c_woodcutter.workplace_id = woodcutter_b.entity_id

	await process_frame
	await process_frame

	# Check 1: Open Laws panel using HUD button
	print("\n>> Check 1: Opening Government & Laws Panel via HUD button...")
	ui.btn_government.emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("28_government_panel_default")
	assert(ui.is_government_panel_visible(), "Government panel must be visible")
	assert(world.government.get_policy(&"taxation") == &"standard", "Default taxation must be standard")
	assert(world.government.get_policy(&"labour") == &"standard", "Default labour must be standard")
	assert(world.government.get_policy(&"forestry") == &"managed", "Default forestry must be managed")
	print("✓ Check 1 Verified: Government overview panel opens with baseline ordinances.")

	# Check 2: Enact Extended labour shifts and High taxes
	print("\n>> Check 2: Enacting High taxation and Extended labour shifts...")
	world.enact_policy(&"taxation", &"high")
	world.enact_policy(&"labour", &"extended")
	await process_frame
	await process_frame
	await _save_screenshot("29_government_enact_extended_high")
	assert(world.government.get_policy(&"taxation") == &"high", "Taxation policy should be high")
	assert(world.economy.tax_level == EconomyState.TaxLevel.HIGH, "Economy tax level must synchronize to HIGH")
	assert(world.government.get_policy(&"labour") == &"extended", "Labour policy should be extended")
	assert(world.government.policy_history.size() >= 2, "Chronicle must contain enactment entries")
	print("✓ Check 2 Verified: Enacted high tax and extended labour shifts successfully logged.")

	# Check 3: Enact Protected Forests and inspect woodcutter building
	print("\n>> Check 3: Enacting Protected Forests and checking Woodcutter blockage...")
	world.enact_policy(&"forestry", &"protected_forests")
	# Close government panel so inspector is cleanly visible
	ui.toggle_government_panel()
	# Tick production to evaluate law blockage
	var recipe: RecipeDef = woodcutter_def.get("recipe", null)
	world.production.tick_building(woodcutter_b, recipe, world.world_state, 1, [c_woodcutter], world.government)
	assert(woodcutter_b.current_block_reason == &"LAW_BLOCKED: PROTECTED_FORESTS", "Woodcutter must be blocked by decree")
	
	world._select_building_at(wood_pos)
	await process_frame
	await process_frame
	await _save_screenshot("30_government_protected_forests_blocked")
	assert(ui.panel_inspector.visible, "Building inspector must be visible")
	assert(ui.label_inspector_status.text.contains("BLOCKED BY LAW"), "Inspector must show BLOCKED BY LAW")
	print("✓ Check 3 Verified: Protected Forests decree blocks woodcutter and displays warning.")

	# Check 4: Enact Open Extraction and inspect conservationist citizen
	print("\n>> Check 4: Enacting Open Extraction and checking conservationist belief conflict...")
	world.enact_policy(&"forestry", &"open_extraction")
	world.selected_building = null
	world.selected_citizen = c_conservationist
	world._update_citizen_inspector()
	await process_frame
	await process_frame
	await _save_screenshot("31_government_open_extraction_conflict")
	assert(ui.panel_inspector.visible, "Citizen inspector must be visible")
	assert(ui.label_inspector_inv.text.contains("Disapproves of open extraction"), "Citizen must express conflict with open extraction")
	print("✓ Check 4 Verified: Conservationist reports belief conflict under open extraction decree.")

	print("\n==============================================")
	print("    TASK 10 GUI ACCEPTANCE CHECKS PASSED      ")
	print("==============================================")
	quit(0)
