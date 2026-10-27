extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GameUI = preload("res://scripts/presentation/game_ui.gd")
const IncidentCatalog = preload("res://scripts/domain/incident_catalog.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")

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
	print(" CROWNWEFT GUI CIVIC INCIDENTS RUNNER (TASK 22) ")
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
	# Screenshot 80: Incident Alert on HUD
	# --------------------------------------------------------------------------
	print("\n>> Check 1: Capturing Incident Alert on HUD (INCIDENTS badge)...")
	world.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, world, 24)
	# Close dialog so alert badge on HUD is prominently visible
	ui.panel_incident.visible = false
	ui.update_incident_button(world.incidents.get_all_active_incidents())
	world._update_ui_state({"fed": 8, "hungry": 2, "at_risk": 1})

	await process_frame
	await process_frame
	await _save_screenshot("80_incident_alert_hud")

	# --------------------------------------------------------------------------
	# Screenshot 81: Hungry Settlement Incident Dialog
	# --------------------------------------------------------------------------
	print("\n>> Check 2: Capturing Hungry Settlement Incident Dialog...")
	var active_data = world.incidents.get_active_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT)
	ui.show_incident_dialog(active_data, world)

	await process_frame
	await process_frame
	await _save_screenshot("81_hungry_settlement_dialog")

	# --------------------------------------------------------------------------
	# Screenshot 82: Strict Rationing Choice Enacted & Laws Integration
	# --------------------------------------------------------------------------
	print("\n>> Check 3: Capturing Strict Rationing Choice Enacted...")
	world.apply_incident_decision(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, &"strict_rationing")
	active_data = world.incidents.get_active_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT)
	ui.show_incident_dialog(active_data, world)

	await process_frame
	await process_frame
	await _save_screenshot("82_strict_rationing_enacted")

	# --------------------------------------------------------------------------
	# Screenshot 83: Prerequisite Blocked Choice
	# --------------------------------------------------------------------------
	print("\n>> Check 4: Capturing Prerequisite Blocked Choice...")
	# Trigger Frontier Trouble with 0 coin in Town Hall
	world.buildings[0].inventory.remove_resource(&"coin", world.buildings[0].inventory.get_quantity(&"coin"), "TEST")
	world.incidents.trigger_incident(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE, world, 36)
	var frontier_data = world.incidents.get_active_incident(IncidentCatalog.INCIDENT_FRONTIER_TROUBLE)
	ui.show_incident_dialog(frontier_data, world)

	await process_frame
	await process_frame
	await _save_screenshot("83_prerequisite_blocked_choice")

	# --------------------------------------------------------------------------
	# Screenshot 84: Chronicle & Incident Resolution
	# --------------------------------------------------------------------------
	print("\n>> Check 5: Capturing Chronicle & Incident Resolution...")
	# Resolve Hungry Settlement and Frontier Trouble
	world.incidents.resolve_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, world, 60)
	ui.panel_incident.visible = false
	ui.toggle_event_log_panel()
	ui.update_event_log(world.event_log.events)

	await process_frame
	await process_frame
	await _save_screenshot("84_incident_chronicle_resolution")

	print("\n==============================================")
	print(" ALL CIVIC INCIDENTS SCREENSHOTS CAPTURED ")
	print("==============================================")
	quit(0)
