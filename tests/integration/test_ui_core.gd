extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAILED: " + message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world: WorldScene = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var ui: GameUI = world.ui
	ui.update_population(1123, 1100, 23, 5)
	ui.update_housing(800, 900, 323, "blocked", "No vacant homes")
	await process_frame
	_check(ui.btn_overlay.get_global_rect().end.x <= root.get_visible_rect().end.x, "Realm controls remain visible with large status counts")
	_check(ui.label_housing.tooltip_text.contains("No vacant homes"), "Housing tooltip preserves the migration blocker")
	_check(ui.btn_workforce.focus_mode == Control.FOCUS_ALL and ui.build_buttons[&"farm"].focus_mode == Control.FOCUS_ALL, "HUD and build controls support keyboard focus")
	ui.build_buttons[&"farm"].grab_focus()
	await process_frame
	var camera_x: float = world.camera.position.x
	var right_down := InputEventKey.new()
	right_down.keycode = KEY_RIGHT
	right_down.pressed = true
	Input.parse_input_event(right_down)
	await process_frame
	world.camera._process(0.1)
	var right_up := InputEventKey.new()
	right_up.keycode = KEY_RIGHT
	Input.parse_input_event(right_up)
	_check(world.camera.position.x > camera_x and root.gui_get_focus_owner() == ui.build_buttons[&"farm"], "Arrow keys pan the camera without moving button focus (%.1f → %.1f, focus: %s)" % [camera_x, world.camera.position.x, root.gui_get_focus_owner()])
	var space_down := InputEventKey.new()
	space_down.keycode = KEY_SPACE
	space_down.pressed = true
	Input.parse_input_event(space_down)
	var space_up := InputEventKey.new()
	space_up.keycode = KEY_SPACE
	Input.parse_input_event(space_up)
	await process_frame
	_check(world.sim_speed_multiplier == 0.0 and world.active_build_id == &"", "Space pauses while a build button has focus without activating it")
	var enter_down := InputEventKey.new()
	enter_down.keycode = KEY_ENTER
	enter_down.pressed = true
	Input.parse_input_event(enter_down)
	var enter_up := InputEventKey.new()
	enter_up.keycode = KEY_ENTER
	Input.parse_input_event(enter_up)
	await process_frame
	_check(world.active_build_id == &"farm", "Enter activates the focused build button")
	world._cancel_build_mode()
	var tab_down := InputEventKey.new()
	tab_down.keycode = KEY_TAB
	tab_down.pressed = true
	Input.parse_input_event(tab_down)
	var tab_up := InputEventKey.new()
	tab_up.keycode = KEY_TAB
	Input.parse_input_event(tab_up)
	await process_frame
	_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner() != ui.build_buttons[&"farm"], "Tab moves keyboard focus between primary controls")

	ui.btn_speed_3x.pressed.emit()
	ui.btn_speed_pause.pressed.emit()
	_check(world.sim_speed_multiplier == 0.0, "Pause button pauses the simulation")
	_check(ui.btn_speed_pause.text == "RESUME", "Pause button offers resume while paused")
	ui.btn_speed_pause.pressed.emit()
	_check(world.sim_speed_multiplier == 3.0, "Pause button restores the previous speed")
	_check(ui.btn_speed_pause.text == "PAUSE", "Pause button offers pause while running")
	ui.btn_speed_pause.pressed.emit()
	_check(world.save_game("user://ui_core_speed_test.json"), "Paused game saves")
	ui.btn_speed_2x.pressed.emit()
	world._on_citizen_selected_from_panel(world.citizens[0].id)
	ui.build_buttons[&"house"].pressed.emit()
	_check(world.load_game("user://ui_core_speed_test.json"), "Paused game loads")
	_check(world.sim_speed_multiplier == 0.0 and ui.btn_speed_pause.text == "RESUME", "Loading restores speed and its UI state")
	_check(ui.label_population.text.contains("%d FED" % world._current_needs_report()["fed"]), "Loading immediately restores the real food-state counts")
	_check(world.selected_citizen == null and world.active_build_id == &"" and not ui.panel_inspector.visible, "Loading clears selection and placement from the previous realm")
	ui.btn_speed_pause.pressed.emit()
	_check(world.sim_speed_multiplier == 1.0, "A loaded paused game resumes at normal speed")
	var routes_before: bool = world.renderer.show_logistics_overlay
	ui.btn_overlay.pressed.emit()
	_check(world.renderer.show_logistics_overlay != routes_before, "Routes button toggles the real overlay")

	var farm_def: Dictionary = BuildingCatalog.get_all_defs()[&"farm"]
	_check(ui.build_buttons[&"farm"].text.contains(ui._format_cost(farm_def["cost"])), "Farm palette uses catalog cost")
	ui.build_buttons[&"farm"].pressed.emit()
	_check(world.active_build_id == &"farm", "Palette selects the real farm placement tool")
	world._cancel_build_mode()

	var building: BuildingState = world.buildings[0]
	world._select_building_at(building.tile_origin)
	_check(ui.panel_inspector.visible and world.selected_building == building, "Selecting a building opens its inspector")
	var close_button: Button = ui.panel_inspector.find_child("InspectorClose", true, false)
	_check(close_button != null, "Inspector has a close button")
	if close_button != null:
		close_button.pressed.emit()
	world._update_ui_state({"fed": world.citizens.size(), "hungry": 0, "at_risk": 0})
	_check(world.selected_building == null and not ui.panel_inspector.visible, "Closing inspector clears selection and remains closed after refresh")

	var farm: BuildingState = null
	for candidate: BuildingState in world.buildings:
		if candidate.definition_id == &"farm":
			farm = candidate
			break
	_check(farm != null, "Starting settlement has a farm")
	if farm != null:
		world._select_building_at(farm.tile_origin)
		_check(ui.label_inspector_status.text.contains("UNSTAFFED"), "Inspector summary matches the unstaffed production diagnosis")
		var assign: Button = ui.panel_inspector.find_child("WorkerIncrease", true, false)
		_check(assign.focus_mode == Control.FOCUS_ALL, "Inspector worker control supports keyboard focus")
		assign.grab_focus()
		ui.btn_workforce.pressed.emit()
		_check(assign.focus_mode == Control.FOCUS_NONE, "Inspector controls cannot receive focus behind a modal")
		ui.close_all_modals()
		_check(root.gui_get_focus_owner() == assign, "Closing a modal restores inspector focus")
		var original_workers: int = farm.assigned_workers
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(farm.assigned_workers == original_workers + 1, "Inspector keyboard control assigns a real worker")
		var unassign: Button = null
		for node in ui.box_assigned_workers.find_children("*", "Button", true, false):
			if not node.is_queued_for_deletion():
				unassign = node
				break
		_check(unassign != null, "Assigned worker has an inspector control")
		if unassign != null:
			unassign.grab_focus()
			var unassign_key: String = str(unassign.get_meta("modal_focus_key", ""))
			world._update_building_inspector()
			_check(str(root.gui_get_focus_owner().get_meta("modal_focus_key", "")) == unassign_key, "Inspector refresh keeps focus on the same worker")
			ui.btn_workforce.pressed.emit()
			world._update_building_inspector()
			ui.close_all_modals()
			_check(str(root.gui_get_focus_owner().get_meta("modal_focus_key", "")) == unassign_key, "Closing a modal restores focus to the refreshed worker control")
			Input.parse_input_event(enter_down)
			Input.parse_input_event(enter_up)
			await process_frame
			_check(farm.assigned_workers == original_workers, "Inspector keyboard control unassigns the worker")
		world._clear_selection()

	ui.btn_workforce.pressed.emit()
	_check(ui.btn_workforce.focus_mode == Control.FOCUS_NONE, "Opening a modal prevents focus from moving behind it")
	_check(root.gui_get_focus_owner() != null and ui.panel_workforce.is_ancestor_of(root.gui_get_focus_owner()), "Opening a panel moves focus inside it")
	Input.parse_input_event(tab_down)
	Input.parse_input_event(tab_up)
	await process_frame
	_check(root.gui_get_focus_owner() != null and ui.panel_workforce.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays inside the open panel")
	_check(not ui.box_workforce_extra_filters.visible, "Extra workforce filters start collapsed")
	ui.btn_workforce_extra_filters.pressed.emit()
	ui.species_filter_buttons[&"human"].pressed.emit()
	ui.btn_workforce_extra_filters.pressed.emit()
	_check(ui.btn_workforce_extra_filters.text.contains("1 active"), "Collapsed filters show when a filter remains active")
	ui.species_filter_buttons[&"all"].pressed.emit()
	await process_frame
	var citizen_id: int = int(ui._last_workforce_citizens[0]["id"])
	var citizen_row: HBoxContainer = ui.box_workforce_citizens.get_child(0)
	var focus_button: Button = citizen_row.get_child(1)
	focus_button.grab_focus()
	world._update_workforce_panel()
	_check(str(root.gui_get_focus_owner().get_meta("modal_focus_key", "")) == "citizen:%d" % citizen_id, "Workforce refresh preserves focus on the same citizen")
	Input.parse_input_event(enter_down)
	Input.parse_input_event(enter_up)
	await process_frame
	_check(world.selected_citizen != null and world.selected_citizen.id == citizen_id, "Focus selects the matching citizen")
	_check(not ui.is_any_modal_open() and ui.panel_inspector.visible, "Focus reveals the citizen inspector")
	ui.btn_workforce.pressed.emit()
	ui.btn_government.pressed.emit()
	_check(ui.panel_government.visible and not ui.panel_workforce.visible, "Opening another realm panel closes the previous panel")
	var low_tax: Button = null
	for node in ui.box_gov_laws.find_children("*", "Button", true, false):
		if node.text == "Low Taxes":
			low_tax = node
			break
	_check(low_tax != null and not low_tax.tooltip_text.is_empty(), "Law options describe their effects before enactment")
	if low_tax != null:
		low_tax.grab_focus()
		world._update_government_ui()
		_check(str(root.gui_get_focus_owner().get_meta("modal_focus_key", "")) == "law:taxation:low", "Law refresh preserves focus on the same option")
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(world.government.get_policy(LawCatalog.LAW_TAXATION) == &"low", "Law control enacts the actual policy")
		_check(world.economy.tax_level == EconomyState.TaxLevel.LOW, "Tax law updates the economy")
	ui.close_all_modals()
	_check(not ui.modal_backdrop.visible, "Closing realm panels clears the backdrop")
	world.incidents.trigger_incident(IncidentCatalog.INCIDENT_HUNGRY_SETTLEMENT, world, 24)
	_check(ui.btn_incidents.text == "INCIDENTS (1)", "Incident count updates as soon as an incident starts")
	_check(ui.is_incident_dialog_visible(), "New incident opens automatically")
	ui.btn_incidents.pressed.emit()
	_check(not ui.is_incident_dialog_visible(), "Incident button closes the open incident")
	ui.btn_incidents.pressed.emit()
	_check(ui.is_incident_dialog_visible(), "Incident button reopens an active incident")
	await process_frame
	var ration_button: Button = null
	for node in ui.box_incident_options.get_children():
		if node is Button and node.text.begins_with("Enact Strict Rationing"):
			ration_button = node
			break
	_check(ration_button != null, "Incident presents the rationing option")
	if ration_button != null:
		_check(ration_button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Incident choices wrap long explanations")
		ration_button.grab_focus()
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(world.government.get_policy(LawCatalog.LAW_RATIONING) == &"strict", "Incident option changes the actual law")
		_check(not ui.is_incident_dialog_visible(), "Successful decision closes the incident")
	world.incidents.trigger_incident(IncidentCatalog.INCIDENT_REALM_GRIEVANCE, world, 25)
	ui.close_all_modals()
	ui.btn_incidents.pressed.emit()
	_check(ui.current_viewed_incident.get("id", &"") == IncidentCatalog.INCIDENT_REALM_GRIEVANCE, "Incident button prioritizes an incident still awaiting a decision")
	ui.close_all_modals()

	var proposal := DiplomaticProposal.new(9001, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, DiplomaticProposal.TYPE_AID, {"resource_id": &"grain", "resource_amount": 10}, 0, 100, "Aid requested", "Relationship improves")
	world.diplomacy.pending_proposals.append(proposal)
	ui.btn_diplomacy.pressed.emit()
	await process_frame
	var refuse_button: Button = null
	for node in ui.box_diplomacy_details.find_children("*", "Button", true, false):
		if node.text == "Refuse":
			refuse_button = node
			break
	_check(refuse_button != null, "Diplomacy displays a pending proposal")
	if refuse_button != null:
		refuse_button.grab_focus()
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(proposal.status == DiplomaticProposal.STATUS_REFUSED, "Refusing a proposal updates diplomacy state")
	world._set_speed(0.0)
	world.buildings[0].inventory.add_resource(&"grain", 10, "UI_TEST")
	world._update_ui_state(world._current_needs_report())
	var total_grain_before: int = 0
	for stock_building: BuildingState in world.buildings:
		total_grain_before += stock_building.inventory.get_quantity(&"grain")
	var aid := DiplomaticProposal.new(9002, FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER, DiplomaticProposal.TYPE_AID, {"resource_id": &"grain", "resource_amount": 10}, 0, 100, "Aid requested", "Relationship improves")
	world.diplomacy.pending_proposals.append(aid)
	world._update_diplomacy_ui()
	await process_frame
	var accept_button: Button = null
	for node in ui.box_diplomacy_details.find_children("*", "Button", true, false):
		if node.text == "Accept":
			accept_button = node
			break
	_check(accept_button != null, "Diplomacy displays the aid request")
	if accept_button != null:
		accept_button.grab_focus()
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(aid.status == DiplomaticProposal.STATUS_ACCEPTED, "Accepting aid changes the proposal state")
		_check(ui.label_grain.text == "GRAIN  %d" % (total_grain_before - 10), "Resource HUD updates immediately for an action while paused")
	ui.close_all_modals()

	var army: ArmyState = world.regional_world.create_army(FactionCatalog.FACTION_PLAYER, "UI Test Army", RegionCatalog.REGION_CROWNWEFT, {&"warrior": 8}, 25, 0)
	world.regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	ui.btn_world_map.pressed.emit()
	await process_frame
	var capital: RegionState = world.regional_world.get_region(RegionCatalog.REGION_CROWNWEFT)
	capital.is_contested = true
	world._update_world_map_ui()
	await process_frame
	var capital_label: String = ""
	for node in ui.map_node_container.get_children():
		if node is Button and str(node.get_meta("modal_focus_key", "")) == "region:%s" % capital.id:
			capital_label = node.text
	_check(capital_label.contains("Contested"), "Map shows when the capital is contested")
	capital.is_contested = false
	world._update_world_map_ui()
	await process_frame
	for node in ui.map_node_container.get_children():
		if node is Button:
			_check(node.position.x >= 0.0 and node.position.x + node.size.x <= ui.map_node_container.size.x + 1.0, "Region button stays inside the map")
	var destination: RegionState = world.regional_world.get_region(RegionCatalog.REGION_VALEN)
	var march_button: Button = null
	for card in ui.box_region_details.get_children():
		if not card is PanelContainer:
			continue
		var belongs_to_army: bool = false
		for label in card.find_children("*", "Label", true, false):
			if label.text.contains("UI Test Army"):
				belongs_to_army = true
		if belongs_to_army:
			for node in card.find_children("*", "Button", true, false):
				if node.text == "To " + destination.display_name:
					march_button = node
					break
	_check(march_button != null, "Army controls show the complete destination name")
	if march_button != null:
		world.diplomacy.get_relationship(FactionCatalog.FACTION_PLAYER, destination.controlling_faction).trust = 0.0
		march_button.grab_focus()
		world._update_world_map_ui()
		_check(str(root.gui_get_focus_owner().get_meta("modal_focus_key", "")) == "army:%d:march:%s" % [army.id, destination.id], "Map refresh preserves the focused army order")
		march_button = root.gui_get_focus_owner() as Button
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(ui.label_toast.text.contains("Cannot march") and army.destination_region_id != destination.id, "Blocked march explains the peace restriction: %s" % ui.label_toast.text)
		world.diplomacy.get_relationship(FactionCatalog.FACTION_PLAYER, destination.controlling_faction).trust = 60.0
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(army.destination_region_id == destination.id and army.status == ArmyState.STATUS_MARCHING, "Map control orders the selected army to march: %s, %s, %s" % [army.destination_region_id, army.status, ui.label_toast.text])
	ui.close_all_modals()
	world._select_building_at(world.buildings[0].tile_origin)
	ui.build_buttons[&"house"].pressed.emit()
	ui.btn_scenarios.pressed.emit()
	var scenario_buttons: Array[Node] = ui.panel_scenario.find_children("*", "Button", true, false).filter(func(node): return node.text == "START SCENARIO")
	_check(scenario_buttons.size() == ScenarioCatalog.ALL_SCENARIO_IDS.size(), "Each scenario has a start control")
	if scenario_buttons.size() > 1:
		scenario_buttons[1].grab_focus()
		Input.parse_input_event(enter_down)
		Input.parse_input_event(enter_up)
		await process_frame
		_check(world.current_scenario_id == ScenarioCatalog.ALL_SCENARIO_IDS[1], "Scenario control starts the selected scenario")
		_check(not ui.is_scenario_panel_visible(), "Scenario panel closes after starting")
		_check(world.selected_building == null and world.active_build_id == &"" and not ui.panel_inspector.visible, "Starting a scenario clears old selection and placement")
		var scenario_coin: int = 0
		for stock_building: BuildingState in world.buildings:
			scenario_coin += stock_building.inventory.get_quantity(&"coin")
		_check(ui.label_coin.text == "COIN  %d" % scenario_coin, "A new scenario immediately displays its actual resources while paused")
	ui.btn_scenarios.grab_focus()
	ui.btn_scenarios.pressed.emit()
	var escape_down := InputEventKey.new()
	escape_down.keycode = KEY_ESCAPE
	escape_down.pressed = true
	Input.parse_input_event(escape_down)
	var escape_up := InputEventKey.new()
	escape_up.keycode = KEY_ESCAPE
	Input.parse_input_event(escape_up)
	await process_frame
	_check(not ui.is_scenario_panel_visible() and root.gui_get_focus_owner() == ui.btn_scenarios, "Escape closes a panel and returns focus to its opener")
	ui.btn_event_log_toggle.pressed.emit()
	await process_frame
	_check(not ui.box_event_log_body.visible and ui.panel_event_log.size.y < 100, "Minimizing the chronicle releases its screen space")
	ui.btn_event_log_toggle.pressed.emit()
	_check(ui.box_event_log_body.visible, "Chronicle can be expanded again")

	world.queue_free()
	await process_frame
	print("UI core: %s" % ("passed" if failures == 0 else "%d failures" % failures))
	quit(failures)
