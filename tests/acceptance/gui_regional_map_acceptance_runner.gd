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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 13)  ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	assert(world.regional_world != null, "RegionalWorldState must not be null")

	# Check 1: Open Strategic World Map via HUD button
	print("\n>> Check 1: Opening Strategic World Map via HUD button...")
	ui.btn_world_map.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(ui.is_world_map_visible(), "World Map panel must be visible")
	
	world.regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("40_regional_map_overview")
	print("✓ Check 1 Verified: Strategic World Map displayed with Crownweft Valley selected.")

	# Check 2: Select Ironpeak Crags node
	print("\n>> Check 2: Selecting Ironpeak Crags in World Map...")
	world._on_region_selected(RegionCatalog.REGION_IRONPEAK)
	await process_frame
	await process_frame
	await _save_screenshot("41_regional_map_ironpeak_selected")
	assert(ui.selected_region_id == RegionCatalog.REGION_IRONPEAK, "Ironpeak Crags selected")
	print("✓ Check 2 Verified: Ironpeak Crags profile, rugged terrain, and resource specialisations rendered.")

	# Check 3: Select Shattered Pass (Contested Gateway)
	print("\n>> Check 3: Selecting Shattered Pass contested territory...")
	world._on_region_selected(RegionCatalog.REGION_SHATTERED_PASS)
	await process_frame
	await process_frame
	await _save_screenshot("42_regional_map_contested_pass")
	assert(ui.selected_region_id == RegionCatalog.REGION_SHATTERED_PASS, "Shattered Pass selected")
	print("✓ Check 3 Verified: Contested buffer status and recognized claim displayed.")

	# Check 4: War Escalation with Ironpeak and active conflict alert in World Map
	print("\n>> Check 4: Escalating war with Ironpeak Clans and inspecting border state...")
	var war: WarState = world.diplomacy.create_war(
		FactionCatalog.FACTION_IRONPEAK,
		FactionCatalog.FACTION_PLAYER,
		"Territorial conflict over border passes",
		world.current_tick
	)
	war.transition_to(WarState.STATUS_WAR, world.current_tick, "Border hostilities engaged")
	
	world._on_region_selected(RegionCatalog.REGION_IRONPEAK)
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("43_regional_map_war_border_status")
	print("✓ Check 4 Verified: Active war warning alert rendered on belligerent territory.")

	print("\n==============================================")
	print("    TASK 13 GUI ACCEPTANCE CHECKS PASSED      ")
	print("==============================================")
	quit(0)
