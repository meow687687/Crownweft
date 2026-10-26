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
signal toggle_government_panel_requested()
signal policy_enact_requested(law_id: StringName, option_id: StringName)
signal toggle_diplomacy_panel_requested()
signal proposal_response_requested(proposal_id: int, accept: bool)
signal ceasefire_requested(war_id: int)
signal peace_requested(war_id: int)
signal toggle_world_map_panel_requested()
signal region_selected(region_id: StringName)
signal army_march_requested(army_id: int, dest_region_id: StringName)
signal army_halt_requested(army_id: int)
signal army_resupply_requested(army_id: int)

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
var active_culture_filter: StringName = &"all"
var culture_filter_buttons: Dictionary = {}
var _last_workforce_citizens: Array = []
var _last_workforce_summary: Dictionary = {}
var _last_auto_staffing: bool = false

# Government & Laws Panel
var btn_government: Button = null
var panel_government: PanelContainer = null
var label_gov_summary: Label = null
var box_gov_laws: VBoxContainer = null
var label_gov_history: Label = null
var _last_gov_data: Dictionary = {}

# Faction Diplomacy Panel
var btn_diplomacy: Button = null
var panel_diplomacy: PanelContainer = null
var list_diplomacy_factions: VBoxContainer = null
var box_diplomacy_details: VBoxContainer = null
var selected_diplomacy_faction_id: StringName = FactionCatalog.FACTION_VALEN
var _last_diplomacy_data: Dictionary = {}

# Strategic World Map Panel
var btn_world_map: Button = null
var panel_world_map: PanelContainer = null
var map_canvas: Control = null
var map_node_container: Control = null
var box_region_details: VBoxContainer = null
var selected_region_id: StringName = RegionCatalog.REGION_CROWNWEFT
var _last_world_map_data: Dictionary = {}

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
	btn_government = _create_ctrl_button(ctrl_box, "LAWS", func(): toggle_government_panel_requested.emit())
	btn_diplomacy = _create_ctrl_button(ctrl_box, "DIPLOMACY", func(): toggle_diplomacy_panel_requested.emit())
	btn_world_map = _create_ctrl_button(ctrl_box, "WORLD MAP", func(): toggle_world_map_panel_requested.emit())
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
	_build_government_panel()
	_build_diplomacy_panel()
	_build_world_map_panel()

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
	elif building.current_block_reason.begins_with("LAW_BLOCKED"):
		label_inspector_status.text = "STATUS: BLOCKED BY LAW — Protected Forests decree prohibits timber harvesting"
		label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
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

func show_citizen_details(citizen: CitizenState, workplace: BuildingState = null, home: BuildingState = null, government: GovernmentState = null) -> void:
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
	var cult_name: String = CultureCatalog.get_display_name(citizen.culture_id)
	var rel_name: String = ReligionCatalog.get_display_name(citizen.religion_id)
	var doc_name: String = DoctrineCatalog.get_display_name(citizen.doctrine_id)
	label_inspector_title.text = "CITIZEN #%d — %s (%s, %s, %s)" % [citizen.id, str(citizen.role_id).capitalize(), sp_name, st_name, cult_name]

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

	var text: String = "CULTURE: %s\n" % cult_name
	text += "RELIGION: %s (%s)\n" % [rel_name, doc_name]
	var belief_conflict: String = citizen.get_active_belief_conflict(government)
	if belief_conflict != "":
		text += "BELIEF CONFLICT: %s\n" % belief_conflict
	text += "SPECIES: %s\n" % sp_name
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
	text += "CONVICTIONS:\n"
	text += " • Work Ethic: %.2f\n" % citizen.get_conviction(&"work_ethic")
	text += " • Nature Conservation: %.2f\n" % citizen.get_conviction(&"nature_conservation")
	text += " • Dietary Preference: %s\n" % str(citizen.convictions.get(&"dietary_type", "omnivore")).capitalize()
	text += " • Piety: %.2f\n" % citizen.get_conviction(&"piety")
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
	panel_workforce.offset_left = -340
	panel_workforce.offset_top = -250
	panel_workforce.offset_right = 340
	panel_workforce.offset_bottom = 250
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

	var culture_filter_bar := HBoxContainer.new()
	culture_filter_bar.add_theme_constant_override("separation", 4)
	main_vbox.add_child(culture_filter_bar)

	var culture_filters: Array[String] = ["ALL CULTURES", "VALEN", "KHORVATH", "SYLVANARI"]
	for cult_f in culture_filters:
		var btn := Button.new()
		btn.text = cult_f
		btn.custom_minimum_size = Vector2(0, 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		UITheme.apply_button_style(btn, cult_f == "ALL CULTURES")
		var cult_key := StringName("all" if cult_f.begins_with("ALL") else cult_f.to_lower())
		btn.pressed.connect(func(): _set_culture_filter(cult_key))
		culture_filter_bar.add_child(btn)
		culture_filter_buttons[cult_key] = btn

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

func _set_culture_filter(cult_key: StringName) -> void:
	active_culture_filter = cult_key
	for k in culture_filter_buttons:
		UITheme.apply_button_style(culture_filter_buttons[k], k == cult_key)
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

		var cult_id: StringName = c.get("culture_id", &"valen")
		if active_culture_filter != &"all" and cult_id != active_culture_filter:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		var state_str: String = c.get("state_str", "Idle")
		var wp_str: String = c.get("workplace_str", "None")
		var sp_name_str: String = c.get("species_name", "Human")
		var st_name_str: String = c.get("social_status_name", "Commoner")
		var cult_name_str: String = c.get("culture_name", "Valen")
		var conflict_str: String = c.get("active_belief_conflict", "")
		var conflict_suffix: String = " [CONFLICT]" if conflict_str != "" else ""
		var skill_name: String = str(c.get("primary_skill_name", "")).capitalize()
		var skill_val: int = c.get("primary_skill_val", 50)
		lbl.text = "#%d | %s (%s, %s, %s) | %s | %s | Energy: %d%% | %s: %d%s" % [
			c.get("id", 0),
			str(role).capitalize(),
			sp_name_str,
			st_name_str,
			cult_name_str,
			state_str,
			wp_str,
			c.get("energy", 100),
			skill_name,
			skill_val,
			conflict_suffix
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

func _build_government_panel() -> void:
	panel_government = PanelContainer.new()
	panel_government.set_anchors_preset(Control.PRESET_CENTER)
	panel_government.offset_left = -340
	panel_government.offset_top = -250
	panel_government.offset_right = 340
	panel_government.offset_bottom = 250
	panel_government.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 6))
	panel_government.visible = false
	panel_government.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_government)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel_government.add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var lbl_title := Label.new()
	lbl_title.text = "REALM GOVERNMENT & LAWS"
	lbl_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 26)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_government.visible = false)
	header.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	label_gov_summary = Label.new()
	label_gov_summary.text = "Treasury: 50 Coin | Approval: 60% | Administration: Unstaffed"
	label_gov_summary.add_theme_font_size_override("font_size", 11)
	label_gov_summary.add_theme_color_override("font_color", Color("#c8d6e5"))
	main_vbox.add_child(label_gov_summary)

	main_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	box_gov_laws = VBoxContainer.new()
	box_gov_laws.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_gov_laws.add_theme_constant_override("separation", 10)
	scroll.add_child(box_gov_laws)

	main_vbox.add_child(HSeparator.new())

	label_gov_history = Label.new()
	label_gov_history.text = "POLICY CHRONICLE:\n  • Settlement established with default statutes."
	label_gov_history.add_theme_font_size_override("font_size", 10)
	label_gov_history.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	label_gov_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(label_gov_history)

func toggle_government_panel() -> void:
	if panel_government != null:
		panel_government.visible = not panel_government.visible
		if panel_government.visible:
			_refresh_government_panel()

func is_government_panel_visible() -> bool:
	return panel_government != null and panel_government.visible

func update_government_panel(gov_data: Dictionary) -> void:
	_last_gov_data = gov_data
	if panel_government != null and panel_government.visible:
		_refresh_government_panel()

func _refresh_government_panel() -> void:
	if box_gov_laws == null:
		return

	var enacted: Dictionary = _last_gov_data.get("enacted_policies", {})
	var has_admin: bool = _last_gov_data.get("has_admin", false)
	var treasury: int = _last_gov_data.get("treasury_coin", 0)
	var tax_inc: int = _last_gov_data.get("last_tax_income", 0)
	var approval_val: float = _last_gov_data.get("approval", 60.0)

	if label_gov_summary != null:
		var admin_str: String = "Active (Town Hall Administrator +15% tax yield)" if has_admin else "Unstaffed (Assign Administrator to Town Hall)"
		label_gov_summary.text = "Treasury: %d Coin (Last Tax: +%d) | Approval: %d%% | Administration: %s" % [
			treasury, tax_inc, int(roundf(approval_val)), admin_str
		]

	for child in box_gov_laws.get_children():
		child.queue_free()

	for law_id in LawCatalog.LAW_IDS:
		var law_def: Dictionary = LawCatalog.get_law_def(law_id)
		var current_opt: StringName = enacted.get(law_id, LawCatalog.get_default_option(law_id))

		var law_box := VBoxContainer.new()
		law_box.add_theme_constant_override("separation", 4)
		box_gov_laws.add_child(law_box)

		var title_lbl := Label.new()
		title_lbl.text = "%s" % str(law_def.get("display_name", str(law_id))).to_upper()
		title_lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		title_lbl.add_theme_font_size_override("font_size", 12)
		law_box.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(law_def.get("description", ""))
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color("#b0bec5"))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		law_box.add_child(desc_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		law_box.add_child(btn_row)

		var options: Dictionary = law_def.get("options", {})
		for opt_key in options:
			var opt_def: Dictionary = options[opt_key]
			var opt_btn := Button.new()
			var is_selected: bool = (opt_key == current_opt)
			opt_btn.text = "[ENACTED] %s" % opt_def.get("display_name") if is_selected else str(opt_def.get("display_name"))
			opt_btn.custom_minimum_size = Vector2(0, 24)
			opt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt_btn.add_theme_font_size_override("font_size", 10)
			UITheme.apply_button_style(opt_btn, is_selected)
			var captured_law: StringName = law_id
			var captured_opt: StringName = opt_key
			opt_btn.pressed.connect(func():
				policy_enact_requested.emit(captured_law, captured_opt)
			)
			btn_row.add_child(opt_btn)

		var active_opt_def: Dictionary = options.get(current_opt, {})
		var trade_lbl := Label.new()
		trade_lbl.text = "Current Effects: %s" % str(active_opt_def.get("trade_offs", ""))
		trade_lbl.add_theme_font_size_override("font_size", 10)
		trade_lbl.add_theme_color_override("font_color", Color("#a5d6a7") if is_selected_positive(law_id, current_opt) else Color("#ffcc80"))
		trade_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		law_box.add_child(trade_lbl)

		law_box.add_child(HSeparator.new())

	if label_gov_history != null:
		var hist: Array = _last_gov_data.get("history", [])
		if hist.is_empty():
			label_gov_history.text = "POLICY CHRONICLE:\n  • Settlement established with default statutes."
		else:
			var h_text: String = "POLICY CHRONICLE:\n"
			for entry in hist:
				h_text += "  • %s\n" % str(entry.get("description", ""))
			label_gov_history.text = h_text.strip_edges()

func is_selected_positive(law_id: StringName, opt_id: StringName) -> bool:
	if law_id == LawCatalog.LAW_TAXATION and opt_id == &"low":
		return true
	if law_id == LawCatalog.LAW_LABOUR and opt_id != &"extended":
		return true
	if law_id == LawCatalog.LAW_FORESTRY and opt_id != &"open_extraction":
		return true
	return false

# =========================================================================
# FACTION DIPLOMACY PANEL
# =========================================================================

func _build_diplomacy_panel() -> void:
	panel_diplomacy = PanelContainer.new()
	panel_diplomacy.set_anchors_preset(Control.PRESET_CENTER)
	panel_diplomacy.offset_left = -380
	panel_diplomacy.offset_top = -260
	panel_diplomacy.offset_right = 380
	panel_diplomacy.offset_bottom = 260
	panel_diplomacy.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 6))
	panel_diplomacy.visible = false
	panel_diplomacy.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_diplomacy)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel_diplomacy.add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var lbl_title := Label.new()
	lbl_title.text = "FACTION DIPLOMACY & REALM RELATIONS"
	lbl_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 24)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_diplomacy.visible = false)
	header.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body_hbox)

	# Left pane: Faction selector
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(190, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hbox.add_child(left_scroll)

	list_diplomacy_factions = VBoxContainer.new()
	list_diplomacy_factions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_diplomacy_factions.add_theme_constant_override("separation", 6)
	left_scroll.add_child(list_diplomacy_factions)

	body_hbox.add_child(VSeparator.new())

	# Right pane: Details & Interactions
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hbox.add_child(right_scroll)

	box_diplomacy_details = VBoxContainer.new()
	box_diplomacy_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_diplomacy_details.add_theme_constant_override("separation", 8)
	right_scroll.add_child(box_diplomacy_details)

func toggle_diplomacy_panel() -> void:
	if panel_diplomacy != null:
		panel_diplomacy.visible = not panel_diplomacy.visible
		if panel_diplomacy.visible:
			_refresh_diplomacy_panel()

func is_diplomacy_panel_visible() -> bool:
	return panel_diplomacy != null and panel_diplomacy.visible

func update_diplomacy_panel(dip_data: Dictionary) -> void:
	_last_diplomacy_data = dip_data
	if panel_diplomacy != null and panel_diplomacy.visible:
		_refresh_diplomacy_panel()

func _refresh_diplomacy_panel() -> void:
	if list_diplomacy_factions == null or box_diplomacy_details == null:
		return

	# Rebuild Left Faction Selector
	for child in list_diplomacy_factions.get_children():
		child.queue_free()

	for f_id in FactionCatalog.FACTION_IDS:
		var def_info: Dictionary = FactionCatalog.get_faction_def(f_id)
		var btn := Button.new()
		var d_name: String = str(def_info.get("display_name", str(f_id)))
		btn.text = d_name
		btn.custom_minimum_size = Vector2(170, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		
		var is_sel: bool = (f_id == selected_diplomacy_faction_id)
		if is_sel:
			btn.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
			btn.add_theme_stylebox_override("normal", UITheme.create_panel_style(Color(0.2, 0.25, 0.35), UITheme.COLOR_ACCENT_GOLD, 2, 4))
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_stylebox_override("normal", UITheme.create_panel_style(Color(0.12, 0.14, 0.18), Color(0.25, 0.28, 0.32), 1, 4))
		
		var f_key: StringName = f_id
		btn.pressed.connect(func():
			selected_diplomacy_faction_id = f_key
			_refresh_diplomacy_panel()
		)
		list_diplomacy_factions.add_child(btn)

	# Rebuild Right Details Pane
	for child in box_diplomacy_details.get_children():
		child.queue_free()

	var fac_dict: Dictionary = _last_diplomacy_data.get("factions", {}).get(str(selected_diplomacy_faction_id), {})
	var def_info: Dictionary = FactionCatalog.get_faction_def(selected_diplomacy_faction_id)
	
	# 1. Header: Name & Cultural Profile
	var title_lbl := Label.new()
	title_lbl.text = "%s" % str(def_info.get("display_name", selected_diplomacy_faction_id))
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", def_info.get("color", UITheme.COLOR_ACCENT_GOLD))
	box_diplomacy_details.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Culture: %s  |  Religion: %s  |  Doctrine: %s" % [
		str(fac_dict.get("culture", def_info.get("culture", "Valen"))).capitalize(),
		str(fac_dict.get("religion", def_info.get("religion", "Pantheon"))).capitalize(),
		str(fac_dict.get("doctrine", def_info.get("doctrine", "Communal"))).capitalize()
	]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	box_diplomacy_details.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(def_info.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_diplomacy_details.add_child(desc_lbl)

	# 2. Goals
	var goals_arr: Array = fac_dict.get("active_goals", def_info.get("default_goals", []))
	var g_str: String = "Strategic Goals: "
	for g in goals_arr:
		g_str += "%s • " % FactionCatalog.get_goal_display_name(StringName(g))
	var goal_lbl := Label.new()
	goal_lbl.text = g_str.trim_suffix(" • ")
	goal_lbl.add_theme_font_size_override("font_size", 10)
	goal_lbl.add_theme_color_override("font_color", Color("#54a0ff"))
	box_diplomacy_details.add_child(goal_lbl)

	box_diplomacy_details.add_child(HSeparator.new())

	# 3. Relationship Gauges (if not player)
	if selected_diplomacy_faction_id != FactionCatalog.FACTION_PLAYER:
		var rel_dict: Dictionary = _last_diplomacy_data.get("relationships", {}).get(str(selected_diplomacy_faction_id), {})
		var trust_val: float = float(rel_dict.get("trust", 0.0))
		var threat_val: float = float(rel_dict.get("threat", 10.0))
		var resent_val: float = float(rel_dict.get("resentment", 0.0))
		var respect_val: float = float(rel_dict.get("respect", 20.0))
		var coop_val: float = float(rel_dict.get("economic_cooperation", 0.0))
		var stance_str: String = str(rel_dict.get("stance", "Neutral & Cautious"))

		var rel_header := Label.new()
		rel_header.text = "BILATERAL RELATIONSHIP (Stance: %s)" % stance_str
		rel_header.add_theme_font_size_override("font_size", 11)
		rel_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		box_diplomacy_details.add_child(rel_header)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		box_diplomacy_details.add_child(grid)

		_add_rel_stat_row(grid, "Trust:", "%+.0f [-100, +100]" % trust_val, Color("#1dd1a1") if trust_val >= 0 else Color("#ff6b6b"))
		_add_rel_stat_row(grid, "Perceived Threat:", "%.0f / 100" % threat_val, Color("#feca57") if threat_val < 40 else Color("#ff6b6b"))
		_add_rel_stat_row(grid, "Resentment:", "%.0f / 100" % resent_val, Color("#ff6b6b") if resent_val > 25 else Color("#1dd1a1"))
		_add_rel_stat_row(grid, "Respect:", "%.0f / 100" % respect_val, Color("#54a0ff"))
		_add_rel_stat_row(grid, "Cooperation:", "%.0f / 100" % coop_val, Color("#48dbfb"))

		# Active treaties
		var treaties: Array = fac_dict.get("active_treaties", [])
		var t_text: String = "Active Treaties: "
		if treaties.is_empty():
			t_text += "None"
		else:
			for t in treaties:
				var t_type: String = str(t.get("type", "Pact")).capitalize()
				var exp: int = int(t.get("expires_tick", -1))
				t_text += "%s (Expires tick %d) • " % [t_type, exp]
			t_text = t_text.trim_suffix(" • ")
		var t_lbl := Label.new()
		t_lbl.text = t_text
		t_lbl.add_theme_font_size_override("font_size", 10)
		t_lbl.add_theme_color_override("font_color", Color("#1dd1a1") if not treaties.is_empty() else UITheme.COLOR_TEXT_MUTED)
		box_diplomacy_details.add_child(t_lbl)

		box_diplomacy_details.add_child(HSeparator.new())

		# 4. Active Wars & Conflict Status
		var war_card := VBoxContainer.new()
		war_card.add_theme_constant_override("separation", 6)
		box_diplomacy_details.add_child(war_card)

		var war_header := Label.new()
		war_header.text = "MILITARY CONFLICT & WAR STATUS"
		war_header.add_theme_font_size_override("font_size", 11)
		war_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		war_card.add_child(war_header)

		var active_wars: Array = _last_diplomacy_data.get("active_wars", [])
		var relevant_war: Dictionary = {}
		for w in active_wars:
			var init_f: StringName = StringName(w.get("initiating_faction", ""))
			var targ_f: StringName = StringName(w.get("target_faction", ""))
			if (init_f == selected_diplomacy_faction_id and targ_f == FactionCatalog.FACTION_PLAYER) or (init_f == FactionCatalog.FACTION_PLAYER and targ_f == selected_diplomacy_faction_id):
				relevant_war = w
				break

		if relevant_war.is_empty():
			var no_war_lbl := Label.new()
			no_war_lbl.text = "State of Peace. No active military conflict with this realm."
			no_war_lbl.add_theme_font_size_override("font_size", 10)
			no_war_lbl.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
			war_card.add_child(no_war_lbl)
		else:
			var w_panel := PanelContainer.new()
			var w_status: String = str(relevant_war.get("status", "peace"))
			var border_col: Color = UITheme.COLOR_RED_ALERT if w_status == "war" else Color("#feca57")
			w_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.2, 0.15, 0.18), border_col, 1, 4))
			war_card.add_child(w_panel)

			var w_vbox := VBoxContainer.new()
			w_vbox.add_theme_constant_override("separation", 4)
			w_panel.add_child(w_vbox)

			var status_str: String = "STATUS: %s" % w_status.to_upper()
			if w_status == "ceasefire":
				status_str += " (Truce: %d ticks left)" % int(relevant_war.get("ceasefire_ticks_remaining", 0))
			var w_status_lbl := Label.new()
			w_status_lbl.text = status_str
			w_status_lbl.add_theme_font_size_override("font_size", 11)
			w_status_lbl.add_theme_color_override("font_color", border_col)
			w_vbox.add_child(w_status_lbl)

			var w_reason := Label.new()
			w_reason.text = "Cause: %s" % str(relevant_war.get("reason", "Border tensions"))
			w_reason.add_theme_font_size_override("font_size", 10)
			w_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			w_vbox.add_child(w_reason)

			var cas_dict: Dictionary = relevant_war.get("casualties", {})
			var crown_cas: int = int(cas_dict.get(str(FactionCatalog.FACTION_PLAYER), 0))
			var enemy_cas: int = int(cas_dict.get(str(selected_diplomacy_faction_id), 0))
			var w_cas_lbl := Label.new()
			w_cas_lbl.text = "Casualties: Crown %d  |  Enemy %d" % [crown_cas, enemy_cas]
			w_cas_lbl.add_theme_font_size_override("font_size", 10)
			w_cas_lbl.add_theme_color_override("font_color", Color("#c8d6e5"))
			w_vbox.add_child(w_cas_lbl)

			var battles: Array = relevant_war.get("battles", [])
			if not battles.is_empty():
				var b_header := Label.new()
				b_header.text = "Recorded Engagements:"
				b_header.add_theme_font_size_override("font_size", 9)
				b_header.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
				w_vbox.add_child(b_header)
				for b in battles:
					var b_lbl := Label.new()
					b_lbl.text = "  • Tick %d: %s (Result: %s)" % [
						int(b.get("tick", 0)),
						str(b.get("description", "")),
						str(b.get("result", "")).capitalize()
					]
					b_lbl.add_theme_font_size_override("font_size", 9)
					w_vbox.add_child(b_lbl)

			# Negotiation buttons
			var war_id: int = int(relevant_war.get("id", 0))
			var war_btn_box := HBoxContainer.new()
			war_btn_box.add_theme_constant_override("separation", 10)
			w_vbox.add_child(war_btn_box)

			if w_status == "war":
				var btn_truce := Button.new()
				btn_truce.text = "Negotiate Ceasefire (Truce)"
				btn_truce.custom_minimum_size = Vector2(160, 24)
				btn_truce.add_theme_font_size_override("font_size", 10)
				UITheme.apply_button_style(btn_truce)
				btn_truce.add_theme_color_override("font_color", Color("#feca57"))
				btn_truce.pressed.connect(func(): ceasefire_requested.emit(war_id))
				war_btn_box.add_child(btn_truce)

			var btn_peace := Button.new()
			btn_peace.text = "Conclude Peace Treaty"
			btn_peace.custom_minimum_size = Vector2(150, 24)
			btn_peace.add_theme_font_size_override("font_size", 10)
			UITheme.apply_button_style(btn_peace)
			btn_peace.add_theme_color_override("font_color", Color("#1dd1a1"))
			btn_peace.pressed.connect(func(): peace_requested.emit(war_id))
			war_btn_box.add_child(btn_peace)

		box_diplomacy_details.add_child(HSeparator.new())

		# 5. Pending Proposals Card
		var prop_card := VBoxContainer.new()
		prop_card.add_theme_constant_override("separation", 6)
		box_diplomacy_details.add_child(prop_card)

		var p_title := Label.new()
		p_title.text = "PENDING DIPLOMATIC PROPOSALS"
		p_title.add_theme_font_size_override("font_size", 11)
		p_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		prop_card.add_child(p_title)

		var pending_proposals: Array = _last_diplomacy_data.get("proposals", [])
		var active_prop: Dictionary = {}
		for p in pending_proposals:
			if p.get("from_faction", &"") == selected_diplomacy_faction_id and p.get("status", "") == "pending":
				active_prop = p
				break

		if active_prop.is_empty():
			var no_p_lbl := Label.new()
			no_p_lbl.text = "No pending proposals awaiting royal response."
			no_p_lbl.add_theme_font_size_override("font_size", 10)
			no_p_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
			prop_card.add_child(no_p_lbl)
		else:
			var prop_panel := PanelContainer.new()
			prop_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.18, 0.22, 0.3), UITheme.COLOR_ACCENT_GOLD, 1, 4))
			prop_card.add_child(prop_panel)

			var p_vbox := VBoxContainer.new()
			p_vbox.add_theme_constant_override("separation", 4)
			prop_panel.add_child(p_vbox)

			var p_name_lbl := Label.new()
			p_name_lbl.text = str(active_prop.get("title", "Diplomatic Proposal"))
			p_name_lbl.add_theme_font_size_override("font_size", 11)
			p_name_lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
			p_vbox.add_child(p_name_lbl)

			var p_reason_lbl := Label.new()
			p_reason_lbl.text = str(active_prop.get("reason", ""))
			p_reason_lbl.add_theme_font_size_override("font_size", 10)
			p_reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p_vbox.add_child(p_reason_lbl)

			var p_fore_lbl := Label.new()
			p_fore_lbl.text = "Forecast: %s" % str(active_prop.get("forecast", ""))
			p_fore_lbl.add_theme_font_size_override("font_size", 9)
			p_fore_lbl.add_theme_color_override("font_color", Color("#c8d6e5"))
			p_fore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p_vbox.add_child(p_fore_lbl)

			var btn_hbox := HBoxContainer.new()
			btn_hbox.add_theme_constant_override("separation", 10)
			p_vbox.add_child(btn_hbox)

			var prop_id: int = int(active_prop.get("id", 0))
			var btn_accept := Button.new()
			btn_accept.text = "Accept"
			btn_accept.custom_minimum_size = Vector2(80, 24)
			btn_accept.add_theme_font_size_override("font_size", 10)
			UITheme.apply_button_style(btn_accept)
			btn_accept.add_theme_color_override("font_color", Color("#1dd1a1"))
			btn_accept.pressed.connect(func(): proposal_response_requested.emit(prop_id, true))
			btn_hbox.add_child(btn_accept)

			var btn_refuse := Button.new()
			btn_refuse.text = "Refuse"
			btn_refuse.custom_minimum_size = Vector2(80, 24)
			btn_refuse.add_theme_font_size_override("font_size", 10)
			UITheme.apply_button_style(btn_refuse)
			btn_refuse.add_theme_color_override("font_color", Color("#ff6b6b"))
			btn_refuse.pressed.connect(func(): proposal_response_requested.emit(prop_id, false))
			btn_hbox.add_child(btn_refuse)

		box_diplomacy_details.add_child(HSeparator.new())

		# 5. Faction Memory
		var mem_header := Label.new()
		mem_header.text = "FACTION MEMORIES & INTERPRETATIONS"
		mem_header.add_theme_font_size_override("font_size", 11)
		mem_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		box_diplomacy_details.add_child(mem_header)

		var memories: Array = fac_dict.get("memories", [])
		if memories.is_empty():
			var no_mem := Label.new()
			no_mem.text = "No recorded diplomatic memories involving this realm."
			no_mem.add_theme_font_size_override("font_size", 10)
			no_mem.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
			box_diplomacy_details.add_child(no_mem)
		else:
			for m in memories:
				var m_lbl := Label.new()
				m_lbl.text = "• Tick %d [%s]: %s" % [
					int(m.get("tick", 0)),
					str(m.get("event_type", "")).capitalize(),
					str(m.get("interpretation", ""))
				]
				m_lbl.add_theme_font_size_override("font_size", 9)
				m_lbl.add_theme_color_override("font_color", Color("#c8d6e5"))
				m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box_diplomacy_details.add_child(m_lbl)

		box_diplomacy_details.add_child(HSeparator.new())

		# 6. Developer Diagnostics: Utility Breakdown
		var diag_header := Label.new()
		diag_header.text = "DEVELOPER DIAGNOSTICS: AGENT UTILITY SCORING"
		diag_header.add_theme_font_size_override("font_size", 10)
		diag_header.add_theme_color_override("font_color", Color("#feca57"))
		box_diplomacy_details.add_child(diag_header)

		var diag: Dictionary = fac_dict.get("last_utility_breakdown", {})
		if diag.is_empty():
			var no_diag := Label.new()
			no_diag.text = "Agent has not evaluated candidate actions yet."
			no_diag.add_theme_font_size_override("font_size", 9)
			no_diag.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
			box_diplomacy_details.add_child(no_diag)
		else:
			var b_down: Dictionary = diag.get("breakdown", {})
			var diag_lbl := Label.new()
			diag_lbl.text = "Chosen Action: %s (Utility: %.1f)\nBreakdown: GoalFit=%.1f  Benefit=%.1f  RelEffect=%.1f  Doctrine=%.1f  Cost=%.1f  Risk=%.1f  OppCost=%.1f" % [
				str(diag.get("chosen_action", "none")),
				float(diag.get("utility", 0.0)),
				float(b_down.get("goal_fit", 0.0)),
				float(b_down.get("expected_benefit", 0.0)),
				float(b_down.get("relationship_effect", 0.0)),
				float(b_down.get("doctrine_fit", 0.0)),
				float(b_down.get("resource_cost", 0.0)),
				float(b_down.get("risk", 0.0)),
				float(b_down.get("opportunity_cost", 0.0))
			]
			diag_lbl.add_theme_font_size_override("font_size", 9)
			diag_lbl.add_theme_color_override("font_color", Color("#a4b0be"))
			diag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box_diplomacy_details.add_child(diag_lbl)
	else:
		# Player Faction Overview
		var p_header := Label.new()
		p_header.text = "SOVEREIGN STATUS"
		p_header.add_theme_font_size_override("font_size", 11)
		p_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		box_diplomacy_details.add_child(p_header)

		var p_info := Label.new()
		p_info.text = "The realm is sovereign. Neighboring states form impressions and craft proposals based on your trade commitments, relief aid, military posture, and enacted decrees."
		p_info.add_theme_font_size_override("font_size", 10)
		p_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box_diplomacy_details.add_child(p_info)

func _add_rel_stat_row(grid: GridContainer, label_text: String, val_text: String, col: Color) -> void:
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	grid.add_child(l)

	var v := Label.new()
	v.text = val_text
	v.add_theme_font_size_override("font_size", 10)
	v.add_theme_color_override("font_color", col)
	grid.add_child(v)

# =========================================================================
# STRATEGIC REGIONAL WORLD MAP & TERRITORIAL CONTROL
# =========================================================================

func _build_world_map_panel() -> void:
	panel_world_map = PanelContainer.new()
	panel_world_map.set_anchors_preset(Control.PRESET_CENTER)
	panel_world_map.offset_left = -440
	panel_world_map.offset_top = -280
	panel_world_map.offset_right = 440
	panel_world_map.offset_bottom = 280
	panel_world_map.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 6))
	panel_world_map.visible = false
	panel_world_map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_world_map)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel_world_map.add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var lbl_title := Label.new()
	lbl_title.text = "STRATEGIC REGIONAL WORLD MAP"
	lbl_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 24)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_world_map.visible = false)
	header.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body_hbox)

	# Left side: Strategic Map Area (560 x 480)
	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(560, 480)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.30, 0.35, 0.45), 1, 4))
	map_panel.clip_contents = true
	body_hbox.add_child(map_panel)

	# Canvas for drawing routes & connections
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(560, 480)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(map_canvas)
	map_canvas.draw.connect(_on_map_canvas_draw)

	# Interactive node container
	map_node_container = Control.new()
	map_node_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.add_child(map_node_container)

	# Right side: Region Inspector
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(280, 480)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hbox.add_child(right_scroll)

	box_region_details = VBoxContainer.new()
	box_region_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_region_details.add_theme_constant_override("separation", 8)
	right_scroll.add_child(box_region_details)

func toggle_world_map_panel() -> void:
	if panel_world_map != null:
		panel_world_map.visible = not panel_world_map.visible
		if panel_world_map.visible:
			if panel_workforce != null:
				panel_workforce.visible = false
			if panel_government != null:
				panel_government.visible = false
			if panel_diplomacy != null:
				panel_diplomacy.visible = false
			_refresh_world_map()

func is_world_map_visible() -> bool:
	return panel_world_map != null and panel_world_map.visible

func update_world_map(map_data: Dictionary) -> void:
	_last_world_map_data = map_data
	if map_data.has("selected_region_id"):
		selected_region_id = StringName(map_data["selected_region_id"])
	if is_world_map_visible():
		_refresh_world_map()

func _refresh_world_map() -> void:
	if map_node_container == null or box_region_details == null:
		return

	# Clear previous interactive nodes
	for child in map_node_container.get_children():
		child.queue_free()

	var regions: Dictionary = _last_world_map_data.get("regions", {})
	if regions.is_empty():
		return

	if not regions.has(selected_region_id) and not regions.is_empty():
		selected_region_id = regions.keys()[0]

	for r_id in regions:
		var reg: RegionState = regions[r_id]
		var btn := Button.new()
		var is_selected: bool = (reg.id == selected_region_id)
		
		var status_tag: String = "Controlled"
		if reg.id == RegionCatalog.REGION_CROWNWEFT:
			status_tag = "Crown Capital"
		elif reg.is_contested:
			status_tag = "Contested Pass"
		elif reg.occupying_faction != &"":
			status_tag = "Occupied"
		elif reg.controlling_faction == &"":
			status_tag = "Unclaimed"
		elif reg.has_settlement():
			status_tag = reg.settlement_name

		btn.text = "%s\n[%s]" % [reg.display_name, status_tag]
		btn.custom_minimum_size = Vector2(120, 46)
		btn.position = Vector2(reg.map_pos.x - 60, reg.map_pos.y - 23)
		btn.add_theme_font_size_override("font_size", 10)

		# Faction color border
		var border_col: Color = _get_faction_color(reg.controlling_faction)
		if reg.is_contested:
			border_col = Color(0.95, 0.35, 0.25)
		elif reg.controlling_faction == &"":
			border_col = Color(0.60, 0.65, 0.70)

		var bg_col: Color = Color(0.12, 0.15, 0.22, 0.95) if is_selected else Color(0.08, 0.10, 0.14, 0.90)
		var border_w: int = 3 if is_selected else 2
		btn.add_theme_stylebox_override("normal", UITheme.create_panel_style(bg_col, border_col, border_w, 4))
		btn.add_theme_stylebox_override("hover", UITheme.create_panel_style(bg_col.lightened(0.1), UITheme.COLOR_ACCENT_GOLD, border_w, 4))
		btn.add_theme_stylebox_override("pressed", UITheme.create_panel_style(bg_col.darkened(0.1), border_col, border_w, 4))

		var capture_id: StringName = reg.id
		btn.pressed.connect(func():
			selected_region_id = capture_id
			region_selected.emit(capture_id)
			_refresh_world_map()
		)
		map_node_container.add_child(btn)

	# Trigger canvas redraw for routes
	if map_canvas != null:
		map_canvas.queue_redraw()

	# Rebuild inspector details
	var selected_reg: RegionState = regions.get(selected_region_id, null)
	if selected_reg != null:
		_render_region_details(selected_reg)

func _on_map_canvas_draw() -> void:
	if map_canvas == null:
		return

	# Draw subtle strategic grid lines
	for x in range(40, 560, 60):
		map_canvas.draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.2, 0.25, 0.32, 0.15), 1.0)
	for y in range(40, 480, 60):
		map_canvas.draw_line(Vector2(0, y), Vector2(560, y), Color(0.2, 0.25, 0.32, 0.15), 1.0)

	var regions: Dictionary = _last_world_map_data.get("regions", {})
	var routes: Array = _last_world_map_data.get("routes", [])

	# Draw routes connecting regions
	for r in routes:
		var reg_a: RegionState = regions.get(r.region_a, null)
		var reg_b: RegionState = regions.get(r.region_b, null)
		if reg_a == null or reg_b == null:
			continue

		var pos_a: Vector2 = reg_a.map_pos
		var pos_b: Vector2 = reg_b.map_pos

		var route_col: Color = Color(0.85, 0.75, 0.45, 0.75) # Default road
		var line_w: float = 2.5
		if not r.is_open:
			route_col = Color(0.85, 0.25, 0.25, 0.85) # Blocked / Closed
			line_w = 2.0
		else:
			match r.traversal_constraint:
				RegionRoute.CONSTRAINT_PAVED_ROAD:
					route_col = Color(0.95, 0.85, 0.45, 0.85)
					line_w = 3.0
				RegionRoute.CONSTRAINT_FOREST_TRAIL:
					route_col = Color(0.40, 0.85, 0.45, 0.75)
				RegionRoute.CONSTRAINT_MOUNTAIN_PASS:
					route_col = Color(0.70, 0.75, 0.85, 0.80)
				RegionRoute.CONSTRAINT_MARSH_CROSSING:
					route_col = Color(0.65, 0.55, 0.40, 0.75)

		map_canvas.draw_line(pos_a, pos_b, route_col, line_w)

		# Draw travel ticks marker on route midpoint
		var mid: Vector2 = (pos_a + pos_b) * 0.5
		map_canvas.draw_circle(mid, 4.0, route_col)

	# Highlight selection ring
	if regions.has(selected_region_id):
		var sel_reg: RegionState = regions[selected_region_id]
		map_canvas.draw_arc(sel_reg.map_pos, 32.0, 0.0, TAU, 32, UITheme.COLOR_ACCENT_GOLD, 2.5)

	# Draw active regional armies
	var armies: Dictionary = _last_world_map_data.get("armies", {})
	for a in armies.values():
		if not a.is_active():
			continue
		var a_reg: RegionState = regions.get(a.current_region_id, null)
		if a_reg != null:
			var army_pos: Vector2 = a_reg.map_pos + Vector2(0, 30)
			var a_col: Color = _get_faction_color(a.faction_id)
			map_canvas.draw_circle(army_pos, 7.0, a_col)
			map_canvas.draw_circle(army_pos, 5.0, Color.BLACK)
			map_canvas.draw_circle(army_pos, 3.0, a_col)

func _render_region_details(reg: RegionState) -> void:
	for child in box_region_details.get_children():
		child.queue_free()

	# Title & Terrain
	var lbl_name := Label.new()
	lbl_name.text = reg.display_name.to_upper()
	lbl_name.add_theme_font_size_override("font_size", 13)
	lbl_name.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_region_details.add_child(lbl_name)

	var lbl_terrain := Label.new()
	lbl_terrain.text = "Terrain: %s | %s" % [str(reg.terrain_type).capitalize(), reg.settlement_name if reg.settlement_name != "" else "No Settlement"]
	lbl_terrain.add_theme_font_size_override("font_size", 10)
	lbl_terrain.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	box_region_details.add_child(lbl_terrain)

	box_region_details.add_child(HSeparator.new())

	# Status Card
	var status_card := PanelContainer.new()
	var border_col: Color = _get_faction_color(reg.controlling_faction)
	if reg.is_contested:
		border_col = Color(0.95, 0.35, 0.25)
	status_card.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.12, 0.15, 0.22, 0.95), border_col, 1, 4))
	box_region_details.add_child(status_card)

	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 3)
	status_card.add_child(status_box)

	var lbl_status := Label.new()
	lbl_status.text = "STATUS: %s" % str(reg.status).to_upper()
	lbl_status.add_theme_font_size_override("font_size", 11)
	lbl_status.add_theme_color_override("font_color", border_col)
	status_box.add_child(lbl_status)

	var controller_name: String = _get_faction_display_name(reg.controlling_faction)
	var lbl_ctrl := Label.new()
	lbl_ctrl.text = "Administering: %s" % controller_name
	lbl_ctrl.add_theme_font_size_override("font_size", 10)
	status_box.add_child(lbl_ctrl)

	var claimant_name: String = _get_faction_display_name(reg.claimed_by_faction)
	var lbl_claim := Label.new()
	lbl_claim.text = "Recognized Claim: %s" % (claimant_name if claimant_name != "None" else "Unclaimed / Disputed")
	lbl_claim.add_theme_font_size_override("font_size", 10)
	lbl_claim.add_theme_color_override("font_color", Color("#cbd5e1"))
	status_box.add_child(lbl_claim)

	if reg.occupying_faction != &"":
		var lbl_occ := Label.new()
		lbl_occ.text = "MILITARY OCCUPATION: %s" % _get_faction_display_name(reg.occupying_faction)
		lbl_occ.add_theme_font_size_override("font_size", 10)
		lbl_occ.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
		status_box.add_child(lbl_occ)

	# Strategic Attributes
	var strat_header := Label.new()
	strat_header.text = "STRATEGIC ATTRIBUTES"
	strat_header.add_theme_font_size_override("font_size", 11)
	strat_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_region_details.add_child(strat_header)

	var grid_strat := GridContainer.new()
	grid_strat.columns = 2
	grid_strat.add_theme_constant_override("h_separation", 10)
	grid_strat.add_theme_constant_override("v_separation", 2)
	box_region_details.add_child(grid_strat)

	_add_rel_stat_row(grid_strat, "Defensive Advantage:", "x%.2f" % reg.defensive_advantage, Color("#7bed9f"))
	_add_rel_stat_row(grid_strat, "Travel Difficulty:", "x%.2f" % reg.travel_difficulty, Color("#eccc68"))

	# Regional Resources
	var res_header := Label.new()
	res_header.text = "REGIONAL RESOURCES"
	res_header.add_theme_font_size_override("font_size", 11)
	res_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_region_details.add_child(res_header)

	var prim_res_str: String = ""
	for r in reg.primary_resources:
		prim_res_str += ("" if prim_res_str == "" else ", ") + str(r).capitalize()
	var lbl_prim := Label.new()
	lbl_prim.text = "Specialisation: %s" % (prim_res_str if prim_res_str != "" else "None")
	lbl_prim.add_theme_font_size_override("font_size", 10)
	box_region_details.add_child(lbl_prim)

	var res_str: String = ""
	for k in reg.regional_resources:
		res_str += ("" if res_str == "" else "  |  ") + "%s: %d" % [str(k).capitalize(), reg.regional_resources[k]]
	var lbl_res := Label.new()
	lbl_res.text = "Stockpiles: %s" % (res_str if res_str != "" else "Depleted")
	lbl_res.add_theme_font_size_override("font_size", 10)
	lbl_res.add_theme_color_override("font_color", Color("#a4b0be"))
	lbl_res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_region_details.add_child(lbl_res)

	# Connected Routes
	var route_header := Label.new()
	route_header.text = "CONNECTED ROUTES"
	route_header.add_theme_font_size_override("font_size", 11)
	route_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_region_details.add_child(route_header)

	var routes: Array = _last_world_map_data.get("routes", [])
	var regions: Dictionary = _last_world_map_data.get("regions", {})
	var found_routes: int = 0
	for r in routes:
		if r.has_endpoint(reg.id):
			found_routes += 1
			var other_id: StringName = r.get_other_region(reg.id)
			var other_reg: RegionState = regions.get(other_id, null)
			var dest_name: String = other_reg.display_name if other_reg != null else str(other_id)
			
			var r_lbl := Label.new()
			var avail_str: String = "OPEN" if r.is_open else "BLOCKED"
			r_lbl.text = "-> %s [%s]\n   %d ticks | %d coin toll | %s" % [
				dest_name,
				str(r.traversal_constraint).replace("_", " ").capitalize(),
				r.travel_ticks,
				r.supply_cost_coin,
				avail_str
			]
			r_lbl.add_theme_font_size_override("font_size", 9)
			r_lbl.add_theme_color_override("font_color", Color("#2ed573") if r.is_open else Color("#ff4757"))
			box_region_details.add_child(r_lbl)

	if found_routes == 0:
		var no_routes := Label.new()
		no_routes.text = "No direct routes connected."
		no_routes.add_theme_font_size_override("font_size", 9)
		no_routes.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		box_region_details.add_child(no_routes)

	# Regional Armies & Formations
	box_region_details.add_child(HSeparator.new())
	var army_header := Label.new()
	army_header.text = "REGIONAL ARMIES & GARRISONS"
	army_header.add_theme_font_size_override("font_size", 11)
	army_header.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_region_details.add_child(army_header)

	var armies: Dictionary = _last_world_map_data.get("armies", {})
	var found_armies: int = 0
	for a in armies.values():
		if not a.is_active():
			continue
		if a.current_region_id != reg.id:
			continue
		found_armies += 1

		var army_card := PanelContainer.new()
		var a_col: Color = _get_faction_color(a.faction_id)
		army_card.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.12, 0.14, 0.18, 0.95), a_col, 1, 4))
		box_region_details.add_child(army_card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 3)
		army_card.add_child(card_vbox)

		# Army Title & Faction
		var a_title := Label.new()
		a_title.text = "⚔ %s (%s)" % [a.name, _get_faction_display_name(a.faction_id)]
		a_title.add_theme_font_size_override("font_size", 10)
		a_title.add_theme_color_override("font_color", a_col)
		card_vbox.add_child(a_title)

		# Status Badge
		var stat_col: Color = Color("#2ed573")
		match a.status:
			ArmyState.STATUS_MARCHING:
				stat_col = Color("#eccc68")
			ArmyState.STATUS_SUPPLY_STRAINED:
				stat_col = Color("#ff4757")
			ArmyState.STATUS_RETREATING:
				stat_col = Color("#ffa502")
			ArmyState.STATUS_ENGAGED:
				stat_col = Color("#ff6348")
		var a_stat := Label.new()
		a_stat.text = "Status: %s" % str(a.status).replace("_", " ").to_upper()
		a_stat.add_theme_font_size_override("font_size", 9)
		a_stat.add_theme_color_override("font_color", stat_col)
		card_vbox.add_child(a_stat)

		# Movement info
		if a.status in [ArmyState.STATUS_MARCHING, ArmyState.STATUS_SUPPLY_STRAINED] and not a.route_path.is_empty():
			var dest_reg_info: RegionState = regions.get(a.destination_region_id, null)
			var dest_name: String = dest_reg_info.display_name if dest_reg_info != null else str(a.destination_region_id)
			var a_dest := Label.new()
			a_dest.text = "Marching to: %s\nSegment: %.0f / %d ticks" % [dest_name, a.segment_ticks_progress, a.segment_total_ticks]
			a_dest.add_theme_font_size_override("font_size", 9)
			a_dest.add_theme_color_override("font_color", Color("#cbd5e1"))
			card_vbox.add_child(a_dest)

		# Strength & Roster
		var roster_str: String = ""
		for u_type in a.unit_roster:
			roster_str += ("" if roster_str == "" else ", ") + "%d %s" % [a.unit_roster[u_type], str(u_type).capitalize()]
		var a_strength := Label.new()
		a_strength.text = "Strength: %d (%s)" % [a.strength, roster_str]
		a_strength.add_theme_font_size_override("font_size", 9)
		card_vbox.add_child(a_strength)

		# Carried Supplies
		var a_supp := Label.new()
		var grain_val: float = a.get_supplies(&"grain")
		a_supp.text = "Supplies Carried: %.1f / %d Grain" % [grain_val, a.max_supply_capacity]
		a_supp.add_theme_font_size_override("font_size", 9)
		a_supp.add_theme_color_override("font_color", Color("#ffa502") if grain_val < 10.0 else Color("#7bed9f"))
		card_vbox.add_child(a_supp)

		# Supply Line
		var a_line := Label.new()
		if a.supply_line_connected:
			var base_reg: RegionState = regions.get(a.supply_source_region_id, null)
			var base_name: String = base_reg.display_name if base_reg != null else str(a.supply_source_region_id)
			a_line.text = "Supply Line: CONNECTED (Base: %s)" % base_name
			a_line.add_theme_color_override("font_color", Color("#2ed573"))
		else:
			a_line.text = "Supply Line: SEVERED (No secure friendly path)"
			a_line.add_theme_color_override("font_color", Color("#ff4757"))
		a_line.add_theme_font_size_override("font_size", 9)
		card_vbox.add_child(a_line)

		# Player Controls
		if a.faction_id == FactionCatalog.FACTION_PLAYER:
			var btn_box := HBoxContainer.new()
			btn_box.add_theme_constant_override("separation", 4)
			card_vbox.add_child(btn_box)

			var capture_aid: int = a.id
			for n_id in reg.neighbors:
				var n_reg: RegionState = regions.get(n_id, null)
				if n_reg != null:
					var btn_march := Button.new()
					btn_march.text = "To %s" % n_reg.display_name.split(" ")[0]
					btn_march.add_theme_font_size_override("font_size", 8)
					UITheme.apply_button_style(btn_march)
					var cap_nid: StringName = n_id
					btn_march.pressed.connect(func(): army_march_requested.emit(capture_aid, cap_nid))
					btn_box.add_child(btn_march)

			var btn_halt := Button.new()
			btn_halt.text = "Halt"
			btn_halt.add_theme_font_size_override("font_size", 8)
			UITheme.apply_button_style(btn_halt)
			btn_halt.pressed.connect(func(): army_halt_requested.emit(capture_aid))
			btn_box.add_child(btn_halt)

			var btn_resupply := Button.new()
			btn_resupply.text = "Resupply"
			btn_resupply.add_theme_font_size_override("font_size", 8)
			UITheme.apply_button_style(btn_resupply)
			btn_resupply.pressed.connect(func(): army_resupply_requested.emit(capture_aid))
			btn_box.add_child(btn_resupply)

	if found_armies == 0:
		var no_armies := Label.new()
		no_armies.text = "No military formations stationed in this region."
		no_armies.add_theme_font_size_override("font_size", 9)
		no_armies.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		box_region_details.add_child(no_armies)

	# Active Campaign Objectives
	var objectives: Dictionary = _last_world_map_data.get("objectives", {})
	var relevant_objectives: Array = []
	for obj in objectives.values():
		if obj.faction_id == FactionCatalog.FACTION_PLAYER and obj.status == CampaignObjective.STATUS_IN_PROGRESS:
			if obj.target_region_id == reg.id or obj.target_region_id == &"":
				relevant_objectives.append(obj)

	if not relevant_objectives.is_empty():
		box_region_details.add_child(HSeparator.new())
		var obj_hdr := Label.new()
		obj_hdr.text = "ACTIVE CAMPAIGN OBJECTIVES"
		obj_hdr.add_theme_font_size_override("font_size", 11)
		obj_hdr.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		box_region_details.add_child(obj_hdr)

		for obj in relevant_objectives:
			var obj_card := PanelContainer.new()
			obj_card.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.14, 0.16, 0.22, 0.95), UITheme.COLOR_ACCENT_GOLD, 1, 4))
			box_region_details.add_child(obj_card)

			var obj_vbox := VBoxContainer.new()
			obj_vbox.add_theme_constant_override("separation", 2)
			obj_card.add_child(obj_vbox)

			var obj_title := Label.new()
			obj_title.text = "🎯 %s" % obj.description
			obj_title.add_theme_font_size_override("font_size", 10)
			obj_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
			obj_vbox.add_child(obj_title)

			var obj_type_lbl := Label.new()
			obj_type_lbl.text = "Type: %s  |  Status: IN PROGRESS" % str(obj.type).replace("_", " ").to_upper()
			obj_type_lbl.add_theme_font_size_override("font_size", 9)
			obj_type_lbl.add_theme_color_override("font_color", Color("#7bed9f"))
			obj_vbox.add_child(obj_type_lbl)

	# Recent Engagements
	var engagements: Dictionary = _last_world_map_data.get("engagements", {})
	var reg_engagements: Array = []
	for eng in engagements.values():
		if eng.region_id == reg.id:
			reg_engagements.append(eng)

	if not reg_engagements.is_empty():
		box_region_details.add_child(HSeparator.new())
		var eng_hdr := Label.new()
		eng_hdr.text = "REGIONAL ENGAGEMENTS & BATTLES"
		eng_hdr.add_theme_font_size_override("font_size", 11)
		eng_hdr.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		box_region_details.add_child(eng_hdr)

		for eng in reg_engagements:
			var eng_card := PanelContainer.new()
			var outcome_col: Color = UITheme.COLOR_ACCENT_GOLD
			if eng.outcome == RegionalEngagement.OUTCOME_ATTACKER_VICTORY:
				outcome_col = Color("#e74c3c")
			elif eng.outcome == RegionalEngagement.OUTCOME_DEFENDER_VICTORY:
				outcome_col = Color("#2ecc71")
			eng_card.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.12, 0.14, 0.18, 0.95), outcome_col, 1, 4))
			box_region_details.add_child(eng_card)

			var eng_vbox := VBoxContainer.new()
			eng_vbox.add_theme_constant_override("separation", 2)
			eng_card.add_child(eng_vbox)

			var eng_title := Label.new()
			eng_title.text = "⚔ Battle (Tick %d) - %s" % [eng.resolved_tick, str(eng.outcome).replace("_", " ").to_upper()]
			eng_title.add_theme_font_size_override("font_size", 10)
			eng_title.add_theme_color_override("font_color", outcome_col)
			eng_vbox.add_child(eng_title)

			var eng_stats := Label.new()
			eng_stats.text = "%s: -%d losses  |  %s: -%d losses" % [
				_get_faction_display_name(eng.attacker_faction_id), eng.attacker_casualties,
				_get_faction_display_name(eng.defender_faction_id), eng.defender_casualties
			]
			eng_stats.add_theme_font_size_override("font_size", 9)
			eng_stats.add_theme_color_override("font_color", Color("#cbd5e1"))
			eng_vbox.add_child(eng_stats)

	# Faction Relations / Active Wars
	var diplomacy: DiplomacyState = _last_world_map_data.get("diplomacy", null)
	if diplomacy != null and reg.controlling_faction != &"" and reg.controlling_faction != FactionCatalog.FACTION_PLAYER:
		box_region_details.add_child(HSeparator.new())
		var has_war: bool = diplomacy.has_active_war(reg.controlling_faction, FactionCatalog.FACTION_PLAYER)
		var dip_lbl := Label.new()
		if has_war:
			dip_lbl.text = "WARNING: Sovereign state is at WAR with the Crown!"
			dip_lbl.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
		else:
			var rel: DiplomaticRelationship = diplomacy.get_relationship(reg.controlling_faction, FactionCatalog.FACTION_PLAYER)
			dip_lbl.text = "Relations: Trust %.0f | Threat %.0f" % [rel.trust, rel.threat]
			dip_lbl.add_theme_color_override("font_color", Color("#70a1ff"))
		dip_lbl.add_theme_font_size_override("font_size", 10)
		box_region_details.add_child(dip_lbl)

func _get_faction_color(faction_id: StringName) -> Color:
	match faction_id:
		FactionCatalog.FACTION_PLAYER:
			return Color(0.95, 0.85, 0.35) # Imperial Gold
		FactionCatalog.FACTION_VALEN:
			return Color(0.30, 0.75, 0.95) # Cyan
		FactionCatalog.FACTION_OLD_GROVE:
			return Color(0.35, 0.85, 0.45) # Emerald
		FactionCatalog.FACTION_IRONPEAK:
			return Color(0.95, 0.45, 0.25) # Rust Orange
		_:
			return Color(0.60, 0.65, 0.70) # Neutral Grey

func _get_faction_display_name(faction_id: StringName) -> String:
	match faction_id:
		FactionCatalog.FACTION_PLAYER:
			return "The Crown"
		FactionCatalog.FACTION_VALEN:
			return "Valen Trade Compact"
		FactionCatalog.FACTION_OLD_GROVE:
			return "Old Grove Commune"
		FactionCatalog.FACTION_IRONPEAK:
			return "Ironpeak Clans"
		_:
			return "None"



