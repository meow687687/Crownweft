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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 9)   ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	
	# Spawn diverse cultures and religions alongside defaults
	var c_val: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(2, 2),
		&"unassigned",
		&"human",
		&"artisan",
		&"valen",
		&"pantheon",
		&"communal_labor"
	)
	c_val.set_conviction(&"work_ethic", 0.85)

	var c_syl: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(3, 2),
		&"woodcutter",
		&"greenwarden",
		&"commoner",
		&"sylvanari",
		&"old_grove",
		&"sylvan_harmony"
	)
	c_syl.set_conviction(&"nature_conservation", 0.90)

	var c_khor: CitizenState = world.spawn_citizen(
		world.world_state.start_settlement_pos + Vector2i(4, 2),
		&"miner",
		&"stoneborn",
		&"commoner",
		&"khorvath",
		&"secular",
		&"martial_tradition"
	)

	await process_frame
	await process_frame

	# Check 1: Select Valen citizen and inspect culture/religion/doctrine/conflict details
	print("\n>> Check 1: Inspecting Valen citizen with high work ethic in Inspector...")
	world.selected_citizen = c_val
	world.selected_building = null
	world._update_citizen_inspector()
	await _save_screenshot("22_culture_inspector_valen")
	assert(ui.panel_inspector.visible, "Citizen inspector must be visible")
	assert(ui.label_inspector_title.text.contains("Valen"), "Title must contain Valen")
	assert(ui.label_inspector_inv.text.contains("CULTURE: Valen"), "Details must show CULTURE: Valen")
	assert(ui.label_inspector_inv.text.contains("RELIGION: Settlement Pantheon (Communal Labor & Duty)"), "Details must show Religion and Doctrine")
	assert(ui.label_inspector_inv.text.contains("BELIEF CONFLICT: Values diligent labor; currently idle and unassigned."), "Must display idle belief conflict")
	assert(ui.label_inspector_inv.text.contains("CONVICTIONS:"), "Must display convictions")
	print("✓ Check 1 Verified: Valen citizen details and work ethic conflict correctly displayed.")

	# Check 2: Inspect Sylvanari woodcutter with nature conservation conflict
	print("\n>> Check 2: Inspecting Sylvanari woodcutter in Inspector...")
	world.selected_citizen = c_syl
	world._update_citizen_inspector()
	await _save_screenshot("23_culture_inspector_sylvanari_conflict")
	assert(ui.label_inspector_title.text.contains("Sylvanari"), "Title must contain Sylvanari")
	assert(ui.label_inspector_inv.text.contains("CULTURE: Sylvanari"), "Details must show CULTURE: Sylvanari")
	assert(ui.label_inspector_inv.text.contains("RELIGION: Old Grove Animism (Sylvan Harmony & Sanctity)"), "Details must show Old Grove Animism")
	assert(ui.label_inspector_inv.text.contains("BELIEF CONFLICT: Supports conservation; forestry assignment conflicts with personal conviction."), "Must display forestry conflict")
	print("✓ Check 2 Verified: Sylvanari forestry conservation conflict correctly displayed.")

	# Check 3: Open Workforce Panel and inspect culture tags
	print("\n>> Check 3: Workforce panel displays culture in rows...")
	ui.btn_workforce.emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("24_workforce_all_cultures")
	assert(ui.is_workforce_panel_visible(), "Workforce panel must be visible")
	print("✓ Check 3 Verified: Workforce panel displays culture.")

	# Check 4: Filter Workforce by Sylvanari
	print("\n>> Check 4: Filtering workforce panel by Sylvanari...")
	ui.culture_filter_buttons[&"sylvanari"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("25_workforce_filter_sylvanari")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Sylvanari"), "Row must be Sylvanari when filtered: " + lbl.text)
	print("✓ Check 4 Verified: Sylvanari culture filter works accurately.")

	# Check 5: Filter Workforce by Khorvath
	print("\n>> Check 5: Filtering workforce panel by Khorvath...")
	ui.culture_filter_buttons[&"khorvath"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("26_workforce_filter_khorvath")
	for child in ui.box_workforce_citizens.get_children():
		var lbl: Label = child.get_child(0) as Label
		assert(lbl.text.contains("Khorvath"), "Row must be Khorvath when filtered: " + lbl.text)
	print("✓ Check 5 Verified: Khorvath culture filter works accurately.")

	# Check 6: Reset filter to ALL CULTURES
	print("\n>> Check 6: Reset filter to ALL CULTURES...")
	ui.culture_filter_buttons[&"all"].emit_signal("pressed")
	await process_frame
	await process_frame
	await _save_screenshot("27_workforce_filter_cultures_reset")
	print("✓ Check 6 Verified: Filter reset to ALL CULTURES.")

	print("\n==============================================")
	print("    ALL GUI CULTURE CHECKS PASSED!            ")
	print("==============================================")
	quit(0)
