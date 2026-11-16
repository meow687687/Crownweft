extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAILED: " + message)

func _check_panel(panel: Control, viewport: Rect2, description: String) -> void:
	var bounds: Rect2 = panel.get_global_rect()
	_check(bounds.position.x >= viewport.position.x and bounds.position.y >= viewport.position.y and bounds.end.x <= viewport.end.x and bounds.end.y <= viewport.end.y, "%s fits in the viewport: %s" % [description, bounds])

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world: WorldScene = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var ui: GameUI = world.ui
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		var viewport: Rect2 = root.get_visible_rect()
		ui.update_population(1123, 1100, 23, 5)
		ui.update_housing(800, 900, 323, "blocked", "No vacant homes")
		await process_frame
		_check_panel(ui.btn_overlay, viewport, "Routes control at %s" % size)
		for pair: Array in [[ui.btn_workforce, ui.panel_workforce], [ui.btn_government, ui.panel_government], [ui.btn_diplomacy, ui.panel_diplomacy], [ui.btn_world_map, ui.panel_world_map], [ui.btn_scenarios, ui.panel_scenario]]:
			var button: Button = pair[0]
			var panel: PanelContainer = pair[1]
			button.pressed.emit()
			await process_frame
			await process_frame
			_check_panel(panel, viewport, "%s panel at %s" % [button.text, size])
			ui.close_all_modals()
	world.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, world, 24)
	await process_frame
	_check_panel(ui.panel_incident, root.get_visible_rect(), "Incident panel")
	world.queue_free()
	await process_frame
	print("UI layout: %s" % ("passed" if failures == 0 else "%d failures" % failures))
	quit(failures)
