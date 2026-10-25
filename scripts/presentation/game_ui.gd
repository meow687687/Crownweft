class_name GameUI
extends CanvasLayer

signal build_selected(building_id: StringName)
signal speed_changed(speed_multiplier: float)
signal toggle_overlay_requested()
signal worker_assignment_changed(delta: int)
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
var label_inspector_workers: Label = null
var progress_capacity: ProgressBar = null
var label_inspector_inv: Label = null
var box_recruitment: VBoxContainer = null

func _ready() -> void:
	_build_ui_layout()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			panel_toast.visible = false

func _build_ui_layout() -> void:
	# 1. Top HUD Bar
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_GOLD, 1, 0))
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(top_panel)
	
	var top_box: HBoxContainer = HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 14)
	top_panel.add_child(top_box)
	
	# Resources Box
	var res_box: HBoxContainer = HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 10)
	top_box.add_child(res_box)
	
	label_coin = _create_badge(res_box, "🪙 Coin:", "50", Color(1.0, 0.85, 0.3))
	label_bread = _create_badge(res_box, "🍞 Bread:", "20", Color(0.9, 0.7, 0.45))
	label_grain = _create_badge(res_box, "🌾 Grain:", "0", Color(0.95, 0.9, 0.4))
	label_timber = _create_badge(res_box, "🪵 Timber:", "25", Color(0.75, 0.55, 0.4))
	label_stone = _create_badge(res_box, "🪨 Stone:", "10", Color(0.65, 0.7, 0.75))
	
	# Separator
	top_box.add_child(VSeparator.new())
	
	# Population & Realm Health
	var realm_box: HBoxContainer = HBoxContainer.new()
	realm_box.add_theme_constant_override("separation", 10)
	top_box.add_child(realm_box)
	label_population = _create_badge(realm_box, "👥 Pop:", "10 (Fed)", Color(0.4, 0.8, 1.0))
	label_approval = _create_badge(realm_box, "👑 Approval:", "60%", UITheme.COLOR_GREEN_OK)
	
	# Tax policy button
	btn_tax = Button.new()
	btn_tax.text = "⚖ Tax: Normal (2C)"
	UITheme.apply_button_style(btn_tax)
	btn_tax.pressed.connect(func(): tax_level_cycled.emit())
	realm_box.add_child(btn_tax)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.add_child(spacer)
	
	# Controls Box (Speed, Overlays, Save/Load)
	var ctrl_box: HBoxContainer = HBoxContainer.new()
	ctrl_box.add_theme_constant_override("separation", 6)
	top_box.add_child(ctrl_box)
	
	btn_speed_pause = _create_ctrl_button(ctrl_box, "⏸", func(): _on_speed_clicked(0.0))
	btn_speed_1x = _create_ctrl_button(ctrl_box, "▶ 1x", func(): _on_speed_clicked(1.0))
	btn_speed_2x = _create_ctrl_button(ctrl_box, "⏩ 2x", func(): _on_speed_clicked(2.0))
	btn_speed_3x = _create_ctrl_button(ctrl_box, "⏭ 3x", func(): _on_speed_clicked(3.0))
	speed_buttons = [btn_speed_pause, btn_speed_1x, btn_speed_2x, btn_speed_3x]
	_highlight_speed_button(btn_speed_1x)
	
	btn_overlay = _create_ctrl_button(ctrl_box, "🔍 Logistics Overlay", func(): toggle_overlay_requested.emit())
	var btn_save: Button = _create_ctrl_button(ctrl_box, "💾 Save", func(): save_game_requested.emit())
	var btn_load: Button = _create_ctrl_button(ctrl_box, "📂 Load", func(): load_game_requested.emit())
	
	# 2. Build Mode Active Prompt Banner (Top-Center)
	panel_build_prompt = PanelContainer.new()
	panel_build_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_build_prompt.offset_top = 52
	panel_build_prompt.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.15, 0.18, 0.25, 0.95), UITheme.COLOR_ACCENT_GOLD, 2, 6))
	panel_build_prompt.visible = false
	panel_build_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_build_prompt)
	
	label_build_prompt = Label.new()
	label_build_prompt.text = "🔨 BUILD MODE ACTIVE: Left-Click: Place | Right-Click: Cancel"
	label_build_prompt.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	panel_build_prompt.add_child(label_build_prompt)
	
	# 3. Raid Alert Banner (Pulsing Top)
	panel_raid_alert = PanelContainer.new()
	panel_raid_alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_raid_alert.offset_top = 90
	panel_raid_alert.add_theme_stylebox_override("panel", UITheme.create_panel_style(Color(0.4, 0.1, 0.1, 0.95), UITheme.COLOR_RED_ALERT, 2, 6))
	panel_raid_alert.visible = false
	panel_raid_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_raid_alert)
	
	label_raid_alert = Label.new()
	label_raid_alert.text = "⚔ ENEMY RAID INCOMING IN 20 SECONDS! RALLY DEFENDERS!"
	label_raid_alert.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
	panel_raid_alert.add_child(label_raid_alert)
	
	# 4. Floating Toast
	panel_toast = PanelContainer.new()
	panel_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_toast.offset_top = 130
	panel_toast.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER, 1, 6))
	panel_toast.visible = false
	panel_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_toast)
	
	label_toast = Label.new()
	label_toast.text = "Notification"
	panel_toast.add_child(label_toast)
	
	# 5. Bottom Build Palette Bar
	var bottom_panel: PanelContainer = PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_GOLD, 2, 0))
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bottom_panel)
	
	var bottom_box: HBoxContainer = HBoxContainer.new()
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_box.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_box)
	
	var build_options: Array[Dictionary] = [
		{"id": &"house", "label": "🏠 House\n[4 Timber]"},
		{"id": &"farm", "label": "🌾 Farm\n[5 Timber]"},
		{"id": &"woodcutter", "label": "🪓 Woodcutter\n[2 Timber]"},
		{"id": &"quarry", "label": "⛏ Quarry\n[6 Timber]"},
		{"id": &"bakery", "label": "🍞 Bakery\n[4T, 4 Stone]"},
		{"id": &"storehouse", "label": "🏛 Storehouse\n[8T, 4 Stone]"},
		{"id": &"barracks", "label": "⚔ Barracks\n[10T, 8 Stone]"},
		{"id": &"road", "label": "🛤 Dirt Road\n[Free]"}
	]
	
	for opt in build_options:
		var btn: Button = Button.new()
		btn.text = opt["label"]
		btn.custom_minimum_size = Vector2(110, 48)
		UITheme.apply_button_style(btn)
		var b_id: StringName = opt["id"]
		btn.pressed.connect(func(): _on_build_btn_pressed(b_id))
		bottom_box.add_child(btn)
		build_buttons[b_id] = btn
		
	# 6. Side Inspector Drawer (Top Right)
	panel_inspector = PanelContainer.new()
	panel_inspector.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel_inspector.offset_left = -280
	panel_inspector.offset_top = 55
	panel_inspector.offset_right = -10
	panel_inspector.offset_bottom = 380
	panel_inspector.add_theme_stylebox_override("panel", UITheme.create_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER_GOLD, 2, 8))
	panel_inspector.visible = false
	panel_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_inspector)
	
	var insp_box: VBoxContainer = VBoxContainer.new()
	insp_box.add_theme_constant_override("separation", 8)
	panel_inspector.add_child(insp_box)
	
	# Header with Title & Close button
	var header_box: HBoxContainer = HBoxContainer.new()
	insp_box.add_child(header_box)
	
	label_inspector_title = Label.new()
	label_inspector_title.text = "🏛 Building Inspector"
	label_inspector_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	label_inspector_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(label_inspector_title)
	
	var btn_close: Button = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(26, 26)
	UITheme.apply_button_style(btn_close)
	btn_close.pressed.connect(func(): panel_inspector.visible = false)
	header_box.add_child(btn_close)
	
	insp_box.add_child(HSeparator.new())
	
	# Status Card
	label_inspector_status = Label.new()
	label_inspector_status.text = "Status: OK"
	insp_box.add_child(label_inspector_status)
	
	progress_inspector = ProgressBar.new()
	progress_inspector.custom_minimum_size = Vector2(0, 10)
	progress_inspector.show_percentage = false
	progress_inspector.visible = false
	insp_box.add_child(progress_inspector)
	
	# Workers Card
	var worker_box: HBoxContainer = HBoxContainer.new()
	worker_box.add_theme_constant_override("separation", 8)
	insp_box.add_child(worker_box)
	
	label_inspector_workers = Label.new()
	label_inspector_workers.text = "Workers: 1 / 2"
	label_inspector_workers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worker_box.add_child(label_inspector_workers)
	
	var btn_w_minus: Button = Button.new()
	btn_w_minus.text = " - "
	btn_w_minus.custom_minimum_size = Vector2(30, 26)
	UITheme.apply_button_style(btn_w_minus)
	btn_w_minus.pressed.connect(func(): worker_assignment_changed.emit(-1))
	worker_box.add_child(btn_w_minus)
	
	var btn_w_plus: Button = Button.new()
	btn_w_plus.text = " + "
	btn_w_plus.custom_minimum_size = Vector2(30, 26)
	UITheme.apply_button_style(btn_w_plus)
	btn_w_plus.pressed.connect(func(): worker_assignment_changed.emit(1))
	worker_box.add_child(btn_w_plus)
	
	insp_box.add_child(HSeparator.new())
	
	# Physical Inventory List
	label_inspector_inv = Label.new()
	label_inspector_inv.text = "Inventory (0 / 50):"
	insp_box.add_child(label_inspector_inv)
	
	# Barracks Recruitment Actions
	box_recruitment = VBoxContainer.new()
	box_recruitment.add_theme_constant_override("separation", 6)
	box_recruitment.visible = false
	insp_box.add_child(box_recruitment)
	
	var label_recruit: Label = Label.new()
	label_recruit.text = "⚔ Recruit Military Units:"
	label_recruit.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	box_recruitment.add_child(label_recruit)
	
	var btn_spearman: Button = Button.new()
	btn_spearman.text = "🛡 Recruit Spearman (15 Coin)"
	UITheme.apply_button_style(btn_spearman)
	btn_spearman.pressed.connect(func(): recruit_unit_requested.emit(&"spearman"))
	box_recruitment.add_child(btn_spearman)
	
	var btn_archer: Button = Button.new()
	btn_archer.text = "🏹 Recruit Archer (20 Coin)"
	UITheme.apply_button_style(btn_archer)
	btn_archer.pressed.connect(func(): recruit_unit_requested.emit(&"archer"))
	box_recruitment.add_child(btn_archer)

func _create_badge(parent: Node, title: String, val: String, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = "%s %s" % [title, val]
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
		label_build_prompt.text = "🔨 BUILD MODE: Placing %s | Left-Click: Place | Right-Click: Cancel" % str(b_id).capitalize()
	else:
		panel_build_prompt.visible = false

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
			label_raid_alert.text = "⚔ ENEMY RAID INCOMING IN %d SECONDS! RALLY DEFENDERS!" % int(ceilf(seconds_left))
		else:
			label_raid_alert.text = "⚔ RAID UNDERWAY! DEFEND THE REALM!"

func hide_raid_warning() -> void:
	if panel_raid_alert != null:
		panel_raid_alert.visible = false

func update_resources(coin: int, bread: int, grain: int, timber: int, stone: int) -> void:
	if label_coin != null:
		label_coin.text = "🪙 Coin: %d" % coin
	if label_bread != null:
		label_bread.text = "🍞 Bread: %d" % bread
	if label_grain != null:
		label_grain.text = "🌾 Grain: %d" % grain
	if label_timber != null:
		label_timber.text = "🪵 Timber: %d" % timber
	if label_stone != null:
		label_stone.text = "🪨 Stone: %d" % stone

func update_population(total: int, fed: int, hungry: int, at_risk: int) -> void:
	if label_population != null:
		if hungry == 0 and at_risk == 0:
			label_population.text = "👥 Pop: %d (Fed)" % total
			label_population.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
		else:
			label_population.text = "👥 Pop: %d (%d Hungry, %d Starving!)" % [total, hungry, at_risk]
			label_population.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)

func update_economy(tax_name: String, approval_val: float) -> void:
	if label_approval != null:
		var app_int: int = int(roundf(approval_val))
		label_approval.text = "👑 Approval: %d%%" % app_int
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
		btn_tax.text = "⚖ Tax: %s (%s)" % [tax_name, rate_str]

func show_building_details(building: BuildingState, def_info: Dictionary) -> void:
	if building == null:
		panel_inspector.visible = false
		return
		
	panel_inspector.visible = true
	label_inspector_title.text = "🏛 %s" % def_info.get("display_name", str(building.definition_id))
	
	# Status & Block Reasons
	if building.current_block_reason == &"":
		label_inspector_status.text = "Status: 🟢 Active & Operating"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_GREEN_OK)
	elif building.current_block_reason == &"MISSING_INPUTS":
		label_inspector_status.text = "Status: 🔴 BLOCKED (Missing Inputs!)"
		label_inspector_status.add_theme_color_override("font_color", UITheme.COLOR_RED_ALERT)
	elif building.current_block_reason == &"OUTPUT_FULL":
		label_inspector_status.text = "Status: 🟡 BLOCKED (Storage Full)"
		label_inspector_status.add_theme_color_override("font_color", Color.ORANGE)
	elif building.current_block_reason == &"NO_WORKERS":
		label_inspector_status.text = "Status: ⚪ Unstaffed (No Workers)"
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
	var max_slots: int = def_info.get("worker_slots", 0)
	label_inspector_workers.text = "Assigned Workers: %d / %d" % [building.assigned_workers, max_slots]
	
	# Inventory items
	var total_stored: int = building.inventory.get_total_quantity()
	var cap: int = building.inventory.capacity
	var inv_text: String = "Physical Storage (%d / %d):\n" % [total_stored, cap]
	if building.inventory.quantities.is_empty():
		inv_text += "  (Empty)\n"
	else:
		for res_id in building.inventory.quantities:
			var qty: int = building.inventory.quantities[res_id]
			var icon_str: String = "📦"
			if res_id == &"coin":
				icon_str = "🪙"
			elif res_id == &"bread":
				icon_str = "🍞"
			elif res_id == &"grain":
				icon_str = "🌾"
			elif res_id == &"timber":
				icon_str = "🪵"
			elif res_id == &"stone":
				icon_str = "🪨"
			inv_text += "  %s %s: %d\n" % [icon_str, str(res_id).capitalize(), qty]
			
	label_inspector_inv.text = inv_text
	
	if box_recruitment != null:
		box_recruitment.visible = (building.definition_id == &"barracks")
