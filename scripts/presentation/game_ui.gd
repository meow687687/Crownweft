class_name GameUI
extends CanvasLayer

signal build_selected(building_id: StringName)
signal speed_changed(speed_multiplier: float)
signal toggle_overlay_requested()
signal worker_assignment_changed(delta: int)
signal building_priority_changed(delta: int)
signal unassign_specific_worker_requested(citizen_id: int)
signal toggle_workforce_panel_requested()
signal auto_staffing_toggled(enabled: bool)
signal citizen_selected_from_panel(citizen_id: int)
signal recruit_unit_requested(unit_def_id: StringName)
signal tax_level_cycled()
signal save_game_requested()
signal load_game_requested()

# Top Bar Elements
var label_coin: Label = null
var label_bread: Label = null
var label_grain: Label = null
var label_timber: Label = null
var label_stone: Label = null
var label_population: Label = null
var label_approval: Label = null

var btn_tax: Button = null
var btn_speed_pause: Button = null
var btn_speed_1x: Button = null
var btn_speed_2x: Button = null
var btn_speed_3x: Button = null
var btn_overlay: Button = null
var speed_buttons: Array[Button] = []

# Build Mode Indicator
var panel_build_prompt: PanelContainer = null
var label_build_prompt: Label = null
var build_buttons: Dictionary = {} # StringName -> Button

# War / Raid Alert Banner
var panel_raid_alert: PanelContainer = null
var label_raid_alert: Label = null

# Toast Notification
var panel_toast: PanelContainer = null
var label_toast: Label = null
var toast_timer: float = 0.0

# Inspector Drawer
var panel_inspector: PanelContainer = null
var label_inspector_title: Label = null
var label_inspector_status: Label = null
var progress_inspector: ProgressBar = null
var box_priority: HBoxContainer = null
var label_priority: Label = null
var box_workers: HBoxContainer = null
var label_inspector_workers: Label = null
var box_assigned_workers: VBoxContainer = null
var progress_capacity: ProgressBar = null
var label_inspector_inv: Label = null
var label_production_chain: Label = null
var label_transactions: Label = null
var box_recruitment: VBoxContainer = null

# Workforce Overview Panel
var btn_workforce: Button = null
var panel_workforce: PanelContainer = null
var label_workforce_summary: Label = null
var btn_auto_staffing: Button = null
var box_workforce_citizens: VBoxContainer = null
var active_workforce_filter: StringName = &"ALL"
var filter_buttons: Dictionary = {}
var active_species_filter: StringName = &"all"
var species_filter_buttons: Dictionary = {}
var active_status_filter: StringName = &"all"
var status_filter_buttons: Dictionary = {}
var _last_workforce_citizens: Array = []
var _last_workforce_summary: Dictionary = {}
var _last_auto_staffing: bool = false

func _ready() -> void:
	_build_ui_layout()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			panel_toast.visible = false

func _build_ui_layout() -> void:
	# Two-tier HUD: resources on row one, realm status and controls on row two.
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 8
	top_panel.offset_right = -8
	top_panel.offset_top = 8
	top_panel.offset_bottom = 96
	top_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_GOLD, 2, 6))
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_box)
	var resources_row := HBoxContainer.new()
	resources_row.add_theme_constant_override("separation", 22)
	top_box.add_child(resources_row)
	var lbl_brand := Label.new()
	lbl_brand.text = "CROWNWEFT"
	lbl_brand.custom_minimum_size = Vector2(150, 0)
	lbl_brand.add_theme_font_size_override("font_size", 16)
	lbl_brand.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	resources_row.add_child(lbl_brand)
	label_coin = _create_badge(resources_row, "COIN", "50", Color("#e8c76f"))
	label_bread = _create_badge(resources_row, "BREAD", "20", Color("#d9a86c"))
	label_grain = _create_badge(resources_row, "GRAIN", "0", Color("#e5d07a"))
	label_timber = _create_badge(resources_row, "TIMBER", "25", Color("#c89b72"))
	label_stone = _create_badge(resources_row, "STONE", "10", Color("#b4c0ca"))
	var grow_spacer := Control.new()
	grow_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources_row.add_child(grow_spacer)
	var lbl_phase := Label.new()
	lbl_phase.text = "REALM SIMULATION  /  v0.1"
	lbl_phase.add_theme_font_size_override("font_size", 10)
	lbl_phase.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	resources_row.add_child(lbl_phase)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 16)
	top_box.add_child(status_row)
	label_population = _create_badge(status_row, "POPULATION", "10 FED", Color("#9ed7e7"))
	label_approval = _create_badge(status_row, "APPROVAL", "60%", UITheme.COLOR_GREEN_OK)
	btn_tax = Button.new()
	btn_tax.text = "TAX: NORMAL"
	btn_tax.custom_minimum_size = Vector2(118, 28)
	UITheme.apply_button_style(btn_tax)
	btn_tax.pressed.connect(func(): tax_level_cycled.emit())
	status_row.add_child(btn_tax)
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_spacer)
	var ctrl_box := HBoxContainer.new()
	ctrl_box.add_theme_constant_override("separation", 5)
	status_row.add_child(ctrl_box)
	btn_speed_pause = _create_ctrl_button(ctrl_box, "PAUSE", func(): _on_speed_clicked(0.0))
	btn_speed_1x = _create_ctrl_button(ctrl_box, "1x", func(): _on_speed_clicked(1.0))
	btn_speed_2x = _create_ctrl_button(ctrl_box, "2x", func(): _on_speed_clicked(2.0))
	btn_speed_3x = _create_ctrl_button(ctrl_box, "3x", func(): _on_speed_clicked(3.0))
	btn_speed_pause.custom_minimum_size = Vector2(62, 28)
	btn_speed_1x.custom_minimum_size = Vector2(42, 28)
	btn_speed_2x.custom_minimum_size = Vector2(42, 28)
	btn_speed_3x.custom_minimum_size = Vector2(42, 28)
	speed_buttons = [btn_speed_pause, btn_speed_1x, btn_speed_2x, btn_speed_3x]
	_highlight_speed_button(btn_speed_1x)
	btn_overlay = _create_ctrl_button(ctrl_box, "LOGISTICS", func(): toggle_overlay_requested.emit())
	btn_workforce = _create_ctrl_button(ctrl_box, "WORKFORCE", func(): toggle_workforce_panel_requested.emit())
	_create_ctrl_button(ctrl_box, "SAVE", func(): save_game_requested.emit())
	_create_ctrl_button(ctrl_box, "LOAD", func(): load_game_requested.emit())

	panel_build_prompt = PanelContainer.new()
	panel_build_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_build_prompt.offset_top = 108
	panel_build_prompt.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.15, 0.18, 0.25, 0.97), UITheme.COLOR_ACCENT_GOLD, 2, 5))
	panel_build_prompt.visible = false
	panel_build_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_build_prompt)
	label_build_prompt = Label.new()
	label_build_prompt.text = "BUILD MODE  |  Left-click: place  |  Right-click: cancel"
	label_build_prompt.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	label_build_prompt.add_theme_font_size_override("font_size", 12)
	panel_build_prompt.add_child(label_build_prompt)

	panel_raid_alert = PanelContainer.new()
	panel_raid_alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_raid_alert.offset_top = 148
	panel_raid_alert.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.28, 0.08, 0.08, 0.97), UITheme.COLOR_RED_ALERT, 2, 5))
	panel_raid_alert.visible = false
	panel_raid_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_raid_alert)
	label_raid_alert = Label.new()
	label_raid_alert.text = "RAID INCOMING — PREPARE DEFENCES"
	label_raid_alert.add_theme_color_override("font_color", Color("#ffe7e2"))
	label_raid_alert.add_theme_font_size_override("font_size", 12)
	panel_raid_alert.add_child(label_raid_alert)

	panel_toast = PanelContainer.new()
	panel_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_toast.offset_top = 188
	panel_toast.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER, 1, 5))
	panel_toast.visible = false
	panel_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_toast)
	label_toast = Label.new()
	label_toast.text = "Notification"
	label_toast.add_theme_font_size_override("font_size", 12)
	panel_toast.add_child(label_toast)

	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 8
	bottom_panel.offset_right = -8
	bottom_panel.offset_top = -134
	bottom_panel.offset_bottom = -8
	bottom_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_GOLD, 2, 6))
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bottom_panel)
	var bottom_box := GridContainer.new()
	bottom_box.columns = 4
	bottom_box.add_theme_constant_override("h_separation", 7)
	bottom_box.add_theme_constant_override("v_separation", 4)
	bottom_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_panel.add_child(bottom_box)
	var build_options: Array[Dictionary] = [
		{"id": &"house", "label": "HOUSE\n4 Timber"},
		{"id": &"farm", "label": "FARM\n5 Timber"},
		{"id": &"woodcutter", "label": "WOODCUTTER\n2 Timber"},
		{"id": &"quarry", "label": "QUARRY\n6 Timber"},
		{"id": &"bakery", "label": "BAKERY\n4 Timber · 4 Stone"},
		{"id": &"storehouse", "label": "STOREHOUSE\n8 Timber · 4 Stone"},
		{"id": &"barracks", "label": "BARRACKS\n10 Timber · 8 Stone"},
		{"id": &"road", "label": "ROAD\nFree"}
	]
	for option: Dictionary in build_options:
		var btn := Button.new()
		btn.text = option["label"]
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		UITheme.apply_button_style(btn)
		var building_id: StringName = option["id"]
		btn.pressed.connect(func(): _on_build_btn_pressed(building_id))
		bottom_box.add_child(btn)
		build_buttons[building_id] = btn

	panel_inspector = PanelContainer.new()
	panel_inspector.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel_inspector.offset_left = -340
	panel_inspector.offset_top = 106
	panel_inspector.offset_right = -10
	panel_inspector.offset_bottom = -144
	panel_inspector.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 6))
	panel_inspector.visible = false
	panel_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_inspector)
	var insp_scroll := ScrollContainer.new()
	insp_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_inspector.add_child(insp_scroll)
	var insp_box := VBoxContainer.new()
	insp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp_box.add_theme_constant_override("separation", 7)
	insp_scroll.add_child(insp_box)
	var header_box := HBoxContainer.new()
	insp_box.add_child(header_box)
	label_inspector_title = Label.new()
	label_inspector_title.text = "BUILDING INSPECTOR"
	label_inspector_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	label_inspector_title.add_theme_font_size_override("font_size", 14)
	label_inspector_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(label_inspector_title)
	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 26)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_inspector.visible = false)
	header_box.add_child(btn_close)
	insp_box.add_child(HSeparator.new())
	label_inspector_status = Label.new()
	label_inspector_status.text = "STATUS: IDLE"
	label_inspector_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(label_inspector_status)
	progress_inspector = ProgressBar.new()
	progress_inspector.custom_minimum_size = Vector2(0, 10)
	progress_inspector.show_percentage = false
	progress_inspector.visible = false
	insp_box.add_child(progress_inspector)
	box_priority = HBoxContainer.new()
	box_priority.add_theme_constant_override("separation", 8)
	insp_box.add_child(box_priority)
	label_priority = Label.new()
	label_priority.text = "Priority: 3 (Normal)"
	label_priority.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_priority.add_theme_font_size_override("font_size", 12)
	box_priority.add_child(label_priority)
	var btn_pri_minus := Button.new()
	btn_pri_minus.text = "[-]"
	btn_pri_minus.custom_minimum_size = Vector2(30, 24)
	UITheme.apply_button_style(btn_pri_minus)
	btn_pri_minus.pressed.connect(func(): building_priority_changed.emit(-1))
	box_priority.add_child(btn_pri_minus)
	var btn_pri_plus := Button.new()
	btn_pri_plus.text = "[+]"
	btn_pri_plus.custom_minimum_size = Vector2(30, 24)
	UITheme.apply_button_style(btn_pri_plus)
	btn_pri_plus.pressed.connect(func(): building_priority_changed.emit(1))
	box_priority.add_child(btn_pri_plus)
	box_workers = HBoxContainer.new()
	box_workers.add_theme_constant_override("separation", 8)
	insp_box.add_child(box_workers)
	label_inspector_workers = Label.new()
	label_inspector_workers.text = "Workers: 0 / 0"
	label_inspector_workers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_workers.add_child(label_inspector_workers)
	var btn_w_minus := Button.new()
	btn_w_minus.text = "-"
	btn_w_minus.custom_minimum_size = Vector2(30, 26)
	UITheme.apply_button_style(btn_w_minus)
	btn_w_minus.pressed.connect(func(): worker_assignment_changed.emit(-1))
	box_workers.add_child(btn_w_minus)
	var btn_w_plus := Button.new()
	btn_w_plus.text = "+"
	btn_w_plus.custom_minimum_size = Vector2(30, 26)
	UITheme.apply_button_style(btn_w_plus)
	btn_w_plus.pressed.connect(func(): worker_assignment_changed.emit(1))
	box_workers.add_child(btn_w_plus)
	box_assigned_workers = VBoxContainer.new()
	box_assigned_workers.add_theme_constant_override("separation", 4)
	insp_box.add_child(box_assigned_workers)
	insp_box.add_child(HSeparator.new())
	label_inspector_inv = Label.new()
	label_inspector_inv.text = "STOCKPILE"
	label_inspector_inv.add_theme_font_size_override("font_size", 12)
	label_inspector_inv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(label_inspector_inv)
	insp_box.add_child(HSeparator.new())
	label_production_chain = Label.new()
	label_production_chain.text = ""
	label_production_chain.add_theme_font_size_override("font_size", 11)
	label_production_chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(label_production_chain)
	label_transactions = Label.new()
	label_transactions.text = ""
	label_transactions.add_theme_font_size_override("font_size", 10)
	label_transactions.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	label_transactions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(label_transactions)
	box_recruitment = VBoxContainer.new()
	box_recruitment.add_theme_constant_override("separation", 6)
	box_recruitment.visible = false
	insp_box.add_child(box_recruitment)
	var label_recruit := Label.new()
	label_recruit.text = "MILITARY RECRUITMENT"
	label_recruit.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_recruitment.add_child(label_recruit)
	var btn_spearman := Button.new()
	btn_spearman.text = "Recruit Spearman — 15 Coin"
	UITheme.apply_button_style(btn_spearman)
	btn_spearman.pressed.connect(func(): recruit_unit_requested.emit(&"spearman"))
	box_recruitment.add_child(btn_spearman)
	var btn_archer := Button.new()
	btn_archer.text = "Recruit Archer — 20 Coin"
	UITheme.apply_button_style(btn_archer)
	btn_archer.pressed.connect(func(): recruit_unit_requested.emit(&"archer"))
	box_recruitment.add_child(btn_archer)

	_build_workforce_panel()

func _create_badge(parent: Node, title: String, val: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = "%s  %s" % [title, val]
	lbl.custom_minimum_size = Vector2(74, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl

func _create_ctrl_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	UITheme.apply_button_style(btn)
	btn.pressed.connect(on_pressed)
	parent.add_child(btn)
	return btn

func _on_speed_clicked(speed: float) -> void:
	speed_changed.emit(speed)
	if speed == 0.0:
		_highlight_speed_button(btn_speed_pause)
	elif speed == 1.0:
		_highlight_speed_button(btn_speed_1x)
	elif speed == 2.0:
		_highlight_speed_button(btn_speed_2x)
	elif speed == 3.0:
		_highlight_speed_button(btn_speed_3x)

func _highlight_speed_button(active_btn: Button) -> void:
	for btn in speed_buttons:
		UITheme.apply_button_style(btn, btn == active_btn)

func _on_build_btn_pressed(b_id: StringName) -> void:
	build_selected.emit(b_id)
	set_active_build_mode(b_id)

func set_active_build_mode(b_id: StringName) -> void:
	for id in build_buttons:
		UITheme.apply_button_style(build_buttons[id], id == b_id)
		
	if b_id != &"":
		panel_build_prompt.visible = true
		update_build_prompt(b_id, "")
	else:
		panel_build_prompt.visible = false

func update_build_prompt(b_id: StringName, info_str: String = "") -> void:
	if label_build_prompt == null or b_id == &"":
		return
	var name_str: String = BuildingCatalog.get_all_defs().get(b_id, {}).get("display_name", str(b_id).capitalize())
	var is_res: bool = BuildingCatalog.is_building_resizable(b_id)
	var hint: String = "Drag or [/] {-} to resize | L-click: place | R-click: cancel" if is_res else "L-click: place | R-click: cancel"
	if info_str != "":
		label_build_prompt.text = "BUILD MODE: %s  [%s]\n%s" % [name_str.to_upper(), info_str, hint]
	else:
		label_build_prompt.text = "BUILD MODE: %s  |  %s" % [name_str.to_upper(), hint]

func show_toast(msg: String, is_error: bool = false) -> void:
	if panel_toast == null or label_toast == null:
		return
	label_toast.text = msg
	label_toast.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT if is_error else UITheme.COLOR_GREEN_OK)
	panel_toast.visible = true
	toast_timer = 3.5

func show_raid_warning(seconds_left: float) -> void:
	if panel_raid_alert != null:
		panel_raid_alert.visible = true
		if seconds_left > 0.0:
			label_raid_alert.text = "RAID INCOMING IN %d SECONDS — RALLY DEFENDERS" % int(ceilf(seconds_left))
		else:
			label_raid_alert.text = "RAID UNDERWAY — DEFEND THE REALM"

func hide_raid_warning() -> void:
	if panel_raid_alert != null:
		panel_raid_alert.visible = false

func update_resources(coin: int, bread: int, grain: int, timber: int, stone: int) -> void:
	if label_coin != null:
		label_coin.text = "COIN  %d" % coin
	if label_bread != null:
		label_bread.text = "BREAD  %d" % bread
	if label_grain != null:
		label_grain.text = "GRAIN  %d" % grain
	if label_timber != null:
		label_timber.text = "TIMBER  %d" % timber
	if label_stone != null:
		label_stone.text = "STONE  %d" % stone

func update_population(total: int, fed: int, hungry: int, at_risk: int) -> void:
	if label_population != null:
		if hungry == 0 and at_risk == 0:
			label_population.text = "POPULATION  %d FED" % total
			label_population.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
		else:
			label_population.text = "POPULATION  %d  |  %d HUNGRY  |  %d AT RISK" % [total, hungry, at_risk]
			label_population.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)

func update_economy(tax_name: String, approval_val: float) -> void:
	if label_approval != null:
		var app_int: int = int(roundf(approval_val))
		label_approval.text = "APPROVAL  %d%%" % app_int
		if app_int >= 70:
			label_approval.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
		elif app_int >= 40:
			label_approval.add_theme_color_override("font_color", Color.ORANGE)
		else:
			label_approval.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
			
	if btn_tax != null:
		var rate_str: String = "2C"
		if tax_name == "Low":
			rate_str = "1C"
		elif tax_name == "High":
			rate_str = "4C"
		btn_tax.text = "TAX: %s (%s)" % [tax_name, rate_str]

func show_building_details(building: BuildingState, def_info: Dictionary, workers_present: int = -1, details: Dictionary = {}) -> void:
	if building == null:
		panel_inspector.visible = false
		return
		
	panel_inspector.visible = true
	if box_workers != null:
		box_workers.visible = true
	if box_priority != null:
		box_priority.visible = true
		label_priority.text = "Priority: %d (%s)" % [building.work_priority, BuildingState.get_priority_name(building.work_priority)]
	if box_assigned_workers != null:
		box_assigned_workers.visible = true
		for child in box_assigned_workers.get_children():
			child.queue_free()
		var assigned_list: Array = details.get("assigned_citizens", [])
		for w_info in assigned_list:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var w_lbl := Label.new()
			w_lbl.text = "#%d %s — %s (%s %d)" % [
				w_info.get("id", 0),
				str(w_info.get("role", "worker")).capitalize(),
				w_info.get("state_str", "Idle"),
				str(w_info.get("skill_name", "")).capitalize(),
				w_info.get("skill_val", 50)
			]
			w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(w_lbl)
			var btn_un := Button.new()
			btn_un.text = "Unassign"
			btn_un.custom_minimum_size = Vector2(64, 22)
			btn_un.add_theme_font_size_override("font_size", 10)
			UITheme.apply_button_style(btn_un)
			var c_id: int = w_info.get("id", 0)
			btn_un.pressed.connect(func(): unassign_specific_worker_requested.emit(c_id))
			row.add_child(btn_un)
			box_assigned_workers.add_child(row)
		var slot_reason: String = details.get("open_slot_reason", "")
		if slot_reason != "":
			var reason_lbl := Label.new()
			reason_lbl.text = slot_reason
			reason_lbl.add_theme_font_size_override("font_size", 10)
			reason_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
			reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box_assigned_workers.add_child(reason_lbl)
	
	if details.has("production_chain"):
		var chain: Dictionary = details["production_chain"]
		var c_text: String = "PRODUCTION & LOGISTICS:\n"
		c_text += "  Operating State: %s\n" % chain.get("real_status", "IDLE")
		if chain.get("primary_blocker", "") != "":
			c_text += "  Primary Blocker: %s\n" % chain.get("primary_blocker", "")
		if chain.get("secondary_blocker", "") != "":
			c_text += "  Secondary Notice: %s\n" % chain.get("secondary_blocker", "")
		if chain.get("upstream_summary", "") != "":
			c_text += "\n  Upstream Inputs:\n%s" % chain.get("upstream_summary", "")
		if chain.get("downstream_summary", "") != "":
			c_text += "\n  Downstream Output:\n%s" % chain.get("downstream_summary", "")
		label_production_chain.text = c_text
		label_production_chain.visible = true
	else:
		label_production_chain.text = ""
		label_production_chain.visible = false

	if details.has("recent_transactions") and not (details["recent_transactions"] as Array).is_empty():
		var t_text: String = "RECENT TRANSACTIONS:\n"
		for line in details["recent_transactions"]:
			t_text += "  " + str(line) + "\n"
		label_transactions.text = t_text
		label_transactions.visible = true
	else:
		label_transactions.text = ""
		label_transactions.visible = false
	
	if building.is_under_construction():
		label_inspector_title.text = "%s (Construction Site)  |  HP %d/%d" % [
			str(def_info.get("display_name", str(building.definition_id))),
			building.health,
			building.max_health
		]
		
		# Construction status and missing materials explanation
		if building.construction_block_reason == &"ENTRANCE_UNREACHABLE":
			label_inspector_status.text = "STATUS: BLOCKED — ENTRANCE UNREACHABLE"
			label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
		elif building.status == BuildingState.Status.PLANNED:
			var missing_dict: Dictionary = building.get_outstanding_materials()
			var missing_str: String = ""
			for k in missing_dict:
				if missing_dict[k] > 0:
					missing_str += "%s: %d " % [str(k).capitalize(), missing_dict[k]]
			if missing_str == "":
				label_inspector_status.text = "STATUS: PLANNED — MATERIALS READY"
				label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
			else:
				label_inspector_status.text = "STATUS: PLANNED — WAITING FOR %s" % missing_str.strip_edges()
				label_inspector_status.add_theme_color_override("font_color", Color("#e8a838"))
		elif building.status == BuildingState.Status.UNDER_CONSTRUCTION:
			if building.construction_block_reason == &"NO_BUILDERS":
				label_inspector_status.text = "STATUS: WAITING FOR BUILDERS TO ARRIVE"
				label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
			else:
				label_inspector_status.text = "STATUS: UNDER CONSTRUCTION (%d%%)" % int(roundf(building.construction_progress * 100.0))
				label_inspector_status.add_theme_color_override("font_color", Color("#e8b839"))
		else:
			label_inspector_status.text = "STATUS: %s" % str(building.status)
			label_inspector_status.add_theme_color_override("font_color", Color.WHITE)
			
		# Construction progress bar
		progress_inspector.visible = true
		progress_inspector.max_value = 100
		progress_inspector.value = int(roundf(building.construction_progress * 100.0))
		
		# Builders
		if workers_present >= 0:
			label_inspector_workers.text = "Builders: %d assigned / %d present / 3 slots" % [building.assigned_workers, workers_present]
		else:
			label_inspector_workers.text = "Builders: %d assigned / 3 slots" % building.assigned_workers
			
		# Material requirements and deliveries
		var ent: Vector2i = building.get_entrance_tile()
		var ent_tag: String = " [BLOCKED]" if building.construction_block_reason == &"ENTRANCE_UNREACHABLE" else ""
		var inv_text: String = "Entrance: (%d, %d)%s\nConstruction Materials:\n" % [ent.x, ent.y, ent_tag]
		for res_id in building.construction_cost:
			var req: int = building.construction_cost[res_id]
			var deliv: int = building.get_delivered_materials().get(res_id, 0)
			inv_text += "  %s: %d / %d (Delivered)\n" % [str(res_id).capitalize(), deliv, req]
		label_inspector_inv.text = inv_text
		if box_recruitment != null:
			box_recruitment.visible = false
		return

	var b_fp: Vector2i = building.get_footprint()
	var name_str: String = str(def_info.get("display_name", str(building.definition_id)))
	if BuildingCatalog.is_building_resizable(building.definition_id):
		name_str += " (%dx%d)" % [b_fp.x, b_fp.y]
	label_inspector_title.text = "%s  |  HP %d/%d" % [
		name_str,
		building.health,
		building.max_health
	]
	
	# Status & Block Reasons
	if building.current_block_reason == &"":
		label_inspector_status.text = "STATUS: ACTIVE"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
	elif building.current_block_reason == &"ENTRANCE_UNREACHABLE":
		label_inspector_status.text = "STATUS: BLOCKED — ENTRANCE UNREACHABLE"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif building.current_block_reason == &"MISSING_INPUTS":
		label_inspector_status.text = "STATUS: BLOCKED — MISSING INPUTS"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif building.current_block_reason == &"OUTPUT_FULL":
		label_inspector_status.text = "STATUS: BLOCKED — STORAGE FULL"
		label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
	elif building.current_block_reason == &"NO_WORKERS":
		if building.assigned_workers > 0 and workers_present == 0:
			label_inspector_status.text = "STATUS: WAITING FOR WORKERS TO ARRIVE"
			label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
		else:
			label_inspector_status.text = "STATUS: UNSTAFFED — ASSIGN WORKERS"
			label_inspector_status.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	elif building.current_block_reason == &"NO_RESOURCE":
		label_inspector_status.text = "STATUS: BLOCKED — NO NEARBY DEPOSIT"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif building.current_block_reason == &"DISABLED":
		label_inspector_status.text = "STATUS: DISABLED"
		label_inspector_status.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		label_inspector_status.text = "Status: %s" % str(building.current_block_reason)
		label_inspector_status.add_theme_color_override("font_color", Color.WHITE)
		
	# Recipe progress bar
	var recipe: RecipeDef = def_info.get("recipe", null)
	if recipe != null and recipe.duration_ticks > 0:
		progress_inspector.visible = true
		progress_inspector.max_value = recipe.duration_ticks
		progress_inspector.value = building.production_progress
	else:
		progress_inspector.visible = false
		
	# Workers
	var max_slots: int = BuildingCatalog.get_worker_slots_for_footprint(building.definition_id, building.get_footprint())
	if workers_present >= 0:
		label_inspector_workers.text = "Workers: %d assigned / %d at work / %d slots" % [building.assigned_workers, workers_present, max_slots]
	else:
		label_inspector_workers.text = "Workers: %d assigned / %d slots" % [building.assigned_workers, max_slots]
	
	# Inventory items
	var total_stored: int = building.inventory.get_total_quantity()
	var cap: int = building.inventory.capacity
	var act_ent: Vector2i = building.get_entrance_tile()
	var act_tag: String = " [BLOCKED]" if building.current_block_reason == &"ENTRANCE_UNREACHABLE" else ""
	var inv_text: String = "Entrance: (%d, %d)%s\nPhysical Storage (%d / %d):\n" % [act_ent.x, act_ent.y, act_tag, total_stored, cap]
	if building.inventory.quantities.is_empty():
		inv_text += "  (Empty)\n"
	else:
		for res_id in building.inventory.quantities:
			var qty: int = building.inventory.quantities[res_id]
			inv_text += "  %s: %d\n" % [str(res_id).capitalize(), qty]
			
	label_inspector_inv.text = inv_text
	
	if box_recruitment != null:
		box_recruitment.visible = (building.definition_id == &"barracks")

func show_citizen_details(citizen: CitizenState, workplace: BuildingState = null, home: BuildingState = null) -> void:
	if citizen == null:
		panel_inspector.visible = false
		return

	panel_inspector.visible = true
	if box_workers != null:
		box_workers.visible = false
	if box_priority != null:
		box_priority.visible = false
	if box_assigned_workers != null:
		box_assigned_workers.visible = false
	if label_production_chain != null:
		label_production_chain.visible = false
	if label_transactions != null:
		label_transactions.visible = false
	if box_recruitment != null:
		box_recruitment.visible = false

	var sp_name: String = SpeciesCatalog.get_display_name(citizen.species_id)
	var st_name: String = SocialClassCatalog.get_display_name(citizen.social_status_id)
	label_inspector_title.text = "CITIZEN #%d — %s (%s, %s)" % [citizen.id, str(citizen.role_id).capitalize(), sp_name, st_name]

	# Activity / Status explanation
	if citizen.is_resting:
		label_inspector_status.text = "STATUS: RESTING — Energy %d/100" % int(citizen.energy)
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
	elif citizen.current_block_reason == &"Cannot rest — no valid home assigned":
		label_inspector_status.text = "STATUS: EXHAUSTED — Cannot rest (no valid home assigned)"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif citizen.current_block_reason == &"ENTRANCE_UNREACHABLE":
		label_inspector_status.text = "STATUS: BLOCKED — Workplace entrance unreachable"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif citizen.role_id == &"hauler":
		if citizen.carried_amount > 0:
			label_inspector_status.text = "STATUS: HAULING — %d %s (Hauling %d)" % [
				citizen.carried_amount, str(citizen.carried_resource).capitalize(), int(citizen.get_skill(&"hauling"))
			]
		else:
			label_inspector_status.text = "STATUS: HAULER IDLE — (Hauling %d)" % int(citizen.get_skill(&"hauling"))
		label_inspector_status.add_theme_color_override("font_color", Color.WHITE)
	elif citizen.workplace_id > 0 and workplace != null:
		var act_name: String = "Working"
		var skill_name: StringName = ProductionSystem.get_relevant_skill(workplace.definition_id)
		if workplace.is_under_construction():
			act_name = "Constructing"
			skill_name = &"masonry"
		elif workplace.definition_id == &"farm":
			act_name = "Farming"
		elif workplace.definition_id == &"woodcutter":
			act_name = "Harvesting"
		elif workplace.definition_id == &"bakery":
			act_name = "Baking"
		elif workplace.definition_id == &"quarry":
			act_name = "Quarrying"

		var skill_val: int = int(citizen.get_skill(skill_name)) if skill_name != &"" else 50
		var skill_factor: float = citizen.get_skill_factor(skill_name) if skill_name != &"" else 1.0

		if citizen.move_state == CitizenState.MoveState.MOVING:
			label_inspector_status.text = "STATUS: TRAVELING TO WORKPLACE"
			label_inspector_status.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		elif workplace.current_block_reason != &"":
			label_inspector_status.text = "STATUS: WAITING — %s" % str(workplace.current_block_reason).replace("_", " ").capitalize()
			label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
		elif workplace.is_under_construction() and workplace.construction_block_reason != &"":
			label_inspector_status.text = "STATUS: WAITING — %s" % str(workplace.construction_block_reason).replace("_", " ").capitalize()
			label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
		else:
			label_inspector_status.text = "STATUS: %s — %s %d (x%.2f)" % [
				act_name, str(skill_name).capitalize(), skill_val, skill_factor
			]
			label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
	else:
		label_inspector_status.text = "STATUS: IDLE — Unassigned"
		label_inspector_status.add_theme_color_override("font_color", Color.LIGHT_GRAY)

	# Energy bar
	progress_inspector.visible = true
	progress_inspector.max_value = 100
	progress_inspector.value = int(citizen.energy)

	# Details text
	var wp_name: String = "None"
	if workplace != null:
		var wp_def: Dictionary = BuildingCatalog.get_all_defs().get(workplace.definition_id, {})
		wp_name = "%s (#%d)" % [wp_def.get("display_name", str(workplace.definition_id)), workplace.entity_id]
	var hm_name: String = "None (Homeless)"
	if home != null:
		var hm_def: Dictionary = BuildingCatalog.get_all_defs().get(home.definition_id, {})
		hm_name = "%s (#%d)" % [hm_def.get("display_name", str(home.definition_id)), home.entity_id]

	var food_str: String = "Fed"
	if citizen.food_state == CitizenState.FoodState.HUNGRY:
		food_str = "Hungry"
	elif citizen.food_state == CitizenState.FoodState.AT_RISK:
		food_str = "Starving / At Risk"

	var sp_id: StringName = citizen.species_id
	var sp_def: Dictionary = SpeciesCatalog.get_def(sp_id)
	var sp_desc: String = sp_def.get("description", "")
	var sp_adv: Array = sp_def.get("advantages", [])
	var sp_dis: Array = sp_def.get("disadvantages", [])

	var st_id: StringName = citizen.social_status_id
	var st_def: Dictionary = SocialClassCatalog.get_def(st_id)
	var st_priv: Array = st_def.get("privileges", [])
	var st_resp: Array = st_def.get("responsibilities", [])

	var text: String = "SPECIES: %s\n" % sp_name
	text += "SOCIAL STATUS: %s\n" % st_name
	text += "TRAITS: %s\n" % sp_desc
	if not st_priv.is_empty():
		text += "PRIVILEGES: %s\n" % ", ".join(st_priv)
	if not st_resp.is_empty():
		text += "RESPONSIBILITIES: %s\n" % ", ".join(st_resp)
	if citizen.last_status_transition_reason != "":
		text += "TRANSITION: %s\n" % citizen.last_status_transition_reason.replace("_", " ").capitalize()
	if not sp_adv.is_empty():
		text += "SPECIES ADVANTAGES: %s\n" % ", ".join(sp_adv)
	if not sp_dis.is_empty():
		text += "SPECIES DISADVANTAGES: %s\n" % ", ".join(sp_dis)
	text += "\n"
	text += "ENERGY: %d / 100\n" % int(citizen.energy)
	text += "WORKPLACE: %s\n" % wp_name
	text += "HOME: %s\n" % hm_name
	text += "FOOD: %s\n\n" % food_str
	text += "SKILLS (with species & social modifiers):\n"
	for s: StringName in CitizenState.SKILL_NAMES:
		var s_val: int = int(citizen.get_skill(s))
		var s_fac: float = citizen.get_skill_factor(s)
		text += " • %s: %d (x%.2f)\n" % [str(s).capitalize().rpad(10), s_val, s_fac]

	label_inspector_inv.text = text

func _build_workforce_panel() -> void:
	panel_workforce = PanelContainer.new()
	panel_workforce.set_anchors_preset(Control.PRESET_CENTER)
	panel_workforce.offset_left = -330
	panel_workforce.offset_top = -225
	panel_workforce.offset_right = 330
	panel_workforce.offset_bottom = 215
	panel_workforce.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 6))
	panel_workforce.visible = false
	panel_workforce.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_workforce)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel_workforce.add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var lbl_title := Label.new()
	lbl_title.text = "WORKFORCE OVERVIEW"
	lbl_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)

	btn_auto_staffing = Button.new()
	btn_auto_staffing.text = "Auto-Staffing: OFF"
	btn_auto_staffing.custom_minimum_size = Vector2(140, 26)
	UITheme.apply_button_style(btn_auto_staffing)
	btn_auto_staffing.pressed.connect(func():
		_last_auto_staffing = not _last_auto_staffing
		_update_auto_staffing_button()
		auto_staffing_toggled.emit(_last_auto_staffing)
	)
	header.add_child(btn_auto_staffing)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 26)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_workforce.visible = false)
	header.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	label_workforce_summary = Label.new()
	label_workforce_summary.text = "Total: 0 | Employed: 0 | Unassigned: 0 | Working: 0 | Travelling: 0 | Hauling: 0 | Resting: 0 | Blocked: 0 | Builders: 0"
	label_workforce_summary.add_theme_font_size_override("font_size", 11)
	label_workforce_summary.add_theme_color_override("font_color", Color("#c8d6e5"))
	label_workforce_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(label_workforce_summary)

	main_vbox.add_child(HSeparator.new())

	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 4)
	main_vbox.add_child(filter_bar)

	var filters: Array[String] = ["ALL", "UNASSIGNED", "WORKING", "TRAVELLING", "HAULING", "RESTING", "BLOCKED", "BUILDERS"]
	for f_name in filters:
		var btn := Button.new()
		btn.text = f_name
		btn.custom_minimum_size = Vector2(0, 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		UITheme.apply_button_style(btn, f_name == "ALL")
		var s_name := StringName(f_name)
		btn.pressed.connect(func(): _set_workforce_filter(s_name))
		filter_bar.add_child(btn)
		filter_buttons[s_name] = btn

	var species_filter_bar := HBoxContainer.new()
	species_filter_bar.add_theme_constant_override("separation", 4)
	main_vbox.add_child(species_filter_bar)

	var species_filters: Array[String] = ["ALL PEOPLES", "HUMAN", "STONEBORN", "GREENWARDEN"]
	for sp_f in species_filters:
		var btn := Button.new()
		btn.text = sp_f
		btn.custom_minimum_size = Vector2(0, 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		UITheme.apply_button_style(btn, sp_f == "ALL PEOPLES")
		var sp_key := StringName("all" if sp_f.begins_with("ALL") else sp_f.to_lower())
		btn.pressed.connect(func(): _set_species_filter(sp_key))
		species_filter_bar.add_child(btn)
		species_filter_buttons[sp_key] = btn

	var status_filter_bar := HBoxContainer.new()
	status_filter_bar.add_theme_constant_override("separation", 3)
	main_vbox.add_child(status_filter_bar)

	var status_filters: Array[String] = ["ALL ESTATES", "COMMONER", "ARTISAN", "MERCHANT", "SCHOLAR", "CLERGY", "ADMIN", "NOBLE"]
	for st_f in status_filters:
		var btn := Button.new()
		btn.text = st_f
		btn.custom_minimum_size = Vector2(0, 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 9)
		UITheme.apply_button_style(btn, st_f == "ALL ESTATES")
		var st_key: StringName = &"all"
		if not st_f.begins_with("ALL"):
			st_key = &"administrator" if st_f == "ADMIN" else StringName(st_f.to_lower())
		btn.pressed.connect(func(): _set_status_filter(st_key))
		status_filter_bar.add_child(btn)
		status_filter_buttons[st_key] = btn

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	box_workforce_citizens = VBoxContainer.new()
	box_workforce_citizens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_workforce_citizens.add_theme_constant_override("separation", 3)
	scroll.add_child(box_workforce_citizens)

func _update_auto_staffing_button() -> void:
	if btn_auto_staffing != null:
		btn_auto_staffing.text = "Auto-Staffing: ON" if _last_auto_staffing else "Auto-Staffing: OFF"
		UITheme.apply_button_style(btn_auto_staffing, _last_auto_staffing)

func _set_workforce_filter(filter_name: StringName) -> void:
	active_workforce_filter = filter_name
	for s_name in filter_buttons:
		UITheme.apply_button_style(filter_buttons[s_name], s_name == filter_name)
	_refresh_workforce_citizen_list()

func _set_species_filter(sp_key: StringName) -> void:
	active_species_filter = sp_key
	for k in species_filter_buttons:
		UITheme.apply_button_style(species_filter_buttons[k], k == sp_key)
	_refresh_workforce_citizen_list()

func _set_status_filter(st_key: StringName) -> void:
	active_status_filter = st_key
	for k in status_filter_buttons:
		UITheme.apply_button_style(status_filter_buttons[k], k == st_key)
	_refresh_workforce_citizen_list()

func toggle_workforce_panel() -> void:
	if panel_workforce != null:
		panel_workforce.visible = not panel_workforce.visible
		if panel_workforce.visible:
			_refresh_workforce_citizen_list()

func is_workforce_panel_visible() -> bool:
	return panel_workforce != null and panel_workforce.visible

func update_workforce_panel(summary: Dictionary, citizens_data: Array, auto_staffing: bool) -> void:
	_last_workforce_summary = summary
	_last_workforce_citizens = citizens_data
	_last_auto_staffing = auto_staffing
	_update_auto_staffing_button()

	if label_workforce_summary != null:
		label_workforce_summary.text = "Total: %d  |  Employed: %d  |  Unassigned: %d  |  Working: %d  |  Travelling: %d  |  Hauling: %d  |  Resting: %d  |  Blocked: %d  |  Builders: %d" % [
			summary.get("total", 0),
			summary.get("employed", 0),
			summary.get("unassigned", 0),
			summary.get("working", 0),
			summary.get("travelling", 0),
			summary.get("hauling", 0),
			summary.get("resting", 0),
			summary.get("blocked", 0),
			summary.get("builders", 0)
		]
	if panel_workforce != null and panel_workforce.visible:
		_refresh_workforce_citizen_list()

func _refresh_workforce_citizen_list() -> void:
	if box_workforce_citizens == null:
		return
	for child in box_workforce_citizens.get_children():
		child.queue_free()

	for c in _last_workforce_citizens:
		var role: StringName = c.get("role", &"unassigned")
		var is_working: bool = c.get("is_working", false)
		var is_travelling: bool = c.get("is_travelling", false)
		var is_resting: bool = c.get("is_resting", false)
		var is_blocked: bool = c.get("is_blocked", false)
		var workplace_id: int = c.get("workplace_id", 0)

		var matches: bool = false
		match active_workforce_filter:
			&"ALL": matches = true
			&"UNASSIGNED": matches = (role == &"unassigned" and workplace_id == 0)
			&"WORKING": matches = is_working
			&"TRAVELLING": matches = is_travelling
			&"HAULING": matches = (role == &"hauler")
			&"RESTING": matches = is_resting
			&"BLOCKED": matches = is_blocked
			&"BUILDERS": matches = (role == &"builder")
			_: matches = true

		if not matches:
			continue

		var sp_id: StringName = c.get("species_id", &"human")
		if active_species_filter != &"all" and sp_id != active_species_filter:
			continue

		var st_id: StringName = c.get("social_status_id", &"commoner")
		if active_status_filter != &"all" and st_id != active_status_filter:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		var state_str: String = c.get("state_str", "Idle")
		var wp_str: String = c.get("workplace_str", "None")
		var sp_name_str: String = c.get("species_name", "Human")
		var st_name_str: String = c.get("social_status_name", "Commoner")
		var skill_name: String = str(c.get("primary_skill_name", "")).capitalize()
		var skill_val: int = c.get("primary_skill_val", 50)
		lbl.text = "#%d | %s (%s, %s) | %s | %s | Energy: %d%% | %s: %d" % [
			c.get("id", 0),
			str(role).capitalize(),
			sp_name_str,
			st_name_str,
			state_str,
			wp_str,
			c.get("energy", 100),
			skill_name,
			skill_val
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		if is_blocked:
			lbl.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
		elif is_resting:
			lbl.add_theme_color_override("font_color", Color.ORANGE)
		elif is_working:
			lbl.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
		row.add_child(lbl)

		var btn_focus := Button.new()
		btn_focus.text = "Focus"
		btn_focus.custom_minimum_size = Vector2(50, 22)
		btn_focus.add_theme_font_size_override("font_size", 10)
		UITheme.apply_button_style(btn_focus)
		var cid: int = c.get("id", 0)
		btn_focus.pressed.connect(func(): citizen_selected_from_panel.emit(cid))
		row.add_child(btn_focus)

		box_workforce_citizens.add_child(row)

