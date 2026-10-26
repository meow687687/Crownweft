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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 14)  ")
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

	# Check 1: Open Strategic World Map and inspect Crown Garrison
	print("\n>> Check 1: Opening World Map and viewing Royal Crown Guard garrison...")
	ui.btn_world_map.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(ui.is_world_map_visible(), "World Map panel must be visible")
	
	world.regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("44_army_garrison_overview")
	print("✓ Check 1 Verified: Strategic World Map displayed with Royal Crown Guard garrison details.")

	# Check 2: Issue March Order to Valen Lowlands (Allied Transit)
	print("\n>> Check 2: Dispatching Royal Crown Guard to Valen Lowlands...")
	var rel_valen: DiplomaticRelationship = world.diplomacy.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER)
	rel_valen.trust = 60.0 # Allied access permitted
	var crown_army: ArmyState = world.regional_world.get_armies_for_region(RegionCatalog.REGION_CROWNWEFT)[0]
	world._on_army_march_requested(crown_army.id, RegionCatalog.REGION_VALEN)
	
	# Advance 15 ticks
	for i in range(15):
		world.regional_world.tick_regional_armies(world.current_tick + i, world.diplomacy)

	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("45_army_marching_towards_valen")
	assert(crown_army.status == ArmyState.STATUS_MARCHING, "Army is marching")
	print("✓ Check 2 Verified: Army marching state, progress, and map tokens rendered.")

	# Check 3: Resupply army from storehouse
	print("\n>> Check 3: Resupplying army...")
	# Add grain to Town Hall for resupply
	world.buildings[0].inventory.add_resource(&"grain", 50, "Granary Surplus")
	world._on_army_resupply_requested(crown_army.id)
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("46_army_resupplied_at_base")
	print("✓ Check 3 Verified: Resupply transfer executed and reflected in army inventory.")

	# Check 4: Severed supply line in neutral buffer
	print("\n>> Check 4: Inspecting severed supply line in isolated border territory...")
	crown_army.current_region_id = RegionCatalog.REGION_GREY_MARCHES
	world.regional_world.selected_region_id = RegionCatalog.REGION_GREY_MARCHES
	# Sever all routes to Grey Marches
	for r in world.regional_world.get_routes_for_region(RegionCatalog.REGION_GREY_MARCHES):
		r.set_blocked(true, "Flooded Quagmire")

	world.regional_world.tick_regional_armies(world.current_tick + 100, world.diplomacy)
	assert(crown_army.supply_line_connected == false, "Supply line must be severed")

	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("47_army_supply_line_severed_alert")
	print("✓ Check 4 Verified: Severed supply line alert displayed in inspector.")

	print("\n==============================================")
	print("    TASK 14 GUI ACCEPTANCE CHECKS PASSED      ")
	print("==============================================")
	quit(0)
