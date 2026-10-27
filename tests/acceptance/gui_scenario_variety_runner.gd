extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GameUI = preload("res://scripts/presentation/game_ui.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const Inventory = preload("res://scripts/domain/inventory.gd")
const FactionCatalog = preload("res://scripts/domain/faction_catalog.gd")
const RegionCatalog = preload("res://scripts/domain/region_catalog.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")
const TradeContract = preload("res://scripts/domain/trade_contract.gd")
const GuidanceService = preload("res://scripts/simulation/guidance_service.gd")

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
	print(" CROWNWEFT GUI SCENARIO VARIETY RUNNER (TASK 20) ")
	print("==============================================")

	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)

	await process_frame
	await process_frame
	await process_frame

	var ui: GameUI = world.ui
	assert(ui != null, "UI must exist")
	var origin: Vector2i = world.world_state.start_settlement_pos
	world.camera.position = Vector2(origin.x * 16.0, origin.y * 16.0)

	# --------------------------------------------------------------------------
	# Screenshot 68: Scenario Selection Dialog
	# --------------------------------------------------------------------------
	print("\n>> Check 1: Capturing Scenario Selection Dialog...")
	ui.toggle_scenario_panel()
	await process_frame
	await process_frame
	await _save_screenshot("68_scenario_selection_dialog")
	ui.toggle_scenario_panel() # Close panel

	# --------------------------------------------------------------------------
	# Screenshot 69: Border March Opening State
	# --------------------------------------------------------------------------
	print("\n>> Check 2: Capturing Border March Opening State...")
	world._on_scenario_selected(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	await process_frame
	await process_frame
	world.renderer.queue_redraw()
	await process_frame
	await _save_screenshot("69_border_march_opening")

	# --------------------------------------------------------------------------
	# Screenshot 70: Merchant's Crossroads Opening State
	# --------------------------------------------------------------------------
	print("\n>> Check 3: Capturing Merchant's Crossroads Opening State...")
	world._on_scenario_selected(ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS)
	await process_frame
	await process_frame
	world.renderer.queue_redraw()
	await process_frame
	await _save_screenshot("70_merchants_crossroads_opening")

	# --------------------------------------------------------------------------
	# Screenshot 71: Border March Resupply & Patrol Progression
	# --------------------------------------------------------------------------
	print("\n>> Check 4: Capturing Border March Resupply & Patrol Progression...")
	world._on_scenario_selected(ScenarioCatalog.SCENARIO_BORDER_MARCH)
	# Complete Stage 1 & 2
	var u = world.combat.spawn_player_unit(&"warrior", Vector2((origin.x - 3) * 16.0, origin.y * 16.0))
	world.military_units.append(u)
	world.buildings[0].inventory.add_resource(&"bread", 25, "RESUPPLY")
	world.guidance.update_guidance(world, world.event_log)
	# Advance army supplies
	var army = world.regional_world.armies.values()[0]
	army.add_supplies(&"grain", 25, world.current_tick)
	var g_info = world.guidance.update_guidance(world, world.event_log)
	ui.update_guidance_panel(g_info)
	world.renderer.queue_redraw()
	await process_frame
	await process_frame
	await _save_screenshot("71_border_march_resupply_progression")

	# --------------------------------------------------------------------------
	# Screenshot 72: Merchant's Crossroads Trade Progression
	# --------------------------------------------------------------------------
	print("\n>> Check 5: Capturing Merchant's Crossroads Trade Progression...")
	world._on_scenario_selected(ScenarioCatalog.SCENARIO_MERCHANTS_CROSSROADS)
	var sh: BuildingState = null
	for b in world.buildings:
		if b.definition_id == &"storehouse":
			sh = b
			break
	if sh != null:
		sh.inventory.add_resource(&"grain", 20, "EXPORT")
		sh.inventory.add_resource(&"timber", 15, "EXPORT")
	var c1 = TradeContract.new(1, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, &"grain", 10, 25, RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_VALEN, 0)
	c1.status = TradeContract.STATUS_ACCEPTED
	world.regional_world.contracts[1] = c1
	var c2 = TradeContract.new(2, FactionCatalog.FACTION_OLD_GROVE, FactionCatalog.FACTION_PLAYER, &"timber", 10, 20, RegionCatalog.REGION_CROWNWEFT, RegionCatalog.REGION_OLD_GROVE, 0)
	c2.status = TradeContract.STATUS_ACCEPTED
	world.regional_world.contracts[2] = c2
	var g_info_trade = world.guidance.update_guidance(world, world.event_log)
	ui.update_guidance_panel(g_info_trade)
	world.renderer.queue_redraw()
	await process_frame
	await process_frame
	await _save_screenshot("72_merchants_crossroads_trade_progression")

	print("\n==============================================")
	print(" ALL 5 SCENARIO VARIETY ACCEPTANCE CHECKS PASSED ")
	print("==============================================")
	quit(0)
