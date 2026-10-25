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

var label_resources: Label = null
var label_population: Label = null
var label_approval: Label = null
var btn_tax: Button = null
var label_speed: Label = null
var label_raid_warning: Label = null
var panel_inspector: PanelContainer = null
var label_inspector_title: Label = null
var label_inspector_status: Label = null
var label_inspector_inv: Label = null
var label_inspector_workers: Label = null
var box_recruitment: VBoxContainer = null

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	# Top bar panel
	var top_panel: Panel = Panel.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 40)
	add_child(top_panel)
	
	var top_box: HBoxContainer = HBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_box.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_box)
	
	# Resource counts
	label_resources = Label.new()
	label_resources.text = "Coin: 50 | Bread: 10 | Grain: 0 | Timber: 20 | Stone: 10"
	top_box.add_child(label_resources)
	
	# Population status
	label_population = Label.new()
	label_population.text = "Pop: 10 | Fed: 10 | Hungry: 0"
	top_box.add_child(label_population)
	
	# Approval and Tax
	label_approval = Label.new()
	label_approval.text = "Approval: 60%"
	top_box.add_child(label_approval)
	
	btn_tax = Button.new()
	btn_tax.text = "Tax: Normal"
	btn_tax.pressed.connect(func(): tax_level_cycled.emit())
	top_box.add_child(btn_tax)
	
	# Speed controls
	var btn_pause: Button = Button.new()
	btn_pause.text = "⏸ Pause"
	btn_pause.pressed.connect(func(): speed_changed.emit(0.0))
	top_box.add_child(btn_pause)
	
	var btn_1x: Button = Button.new()
	btn_1x.text = "▶ 1x"
	btn_1x.pressed.connect(func(): speed_changed.emit(1.0))
	top_box.add_child(btn_1x)
	
	var btn_2x: Button = Button.new()
	btn_2x.text = "⏩ 2x"
	btn_2x.pressed.connect(func(): speed_changed.emit(2.0))
	top_box.add_child(btn_2x)
	
	var btn_3x: Button = Button.new()
	btn_3x.text = "⏭ 3x"
	btn_3x.pressed.connect(func(): speed_changed.emit(3.0))
	top_box.add_child(btn_3x)
	
	var btn_overlay: Button = Button.new()
	btn_overlay.text = "🔍 Overlay"
	btn_overlay.pressed.connect(func(): toggle_overlay_requested.emit())
	top_box.add_child(btn_overlay)
	
	var btn_save: Button = Button.new()
	btn_save.text = "💾 Save"
	btn_save.pressed.connect(func(): save_game_requested.emit())
	top_box.add_child(btn_save)
	
	var btn_load: Button = Button.new()
	btn_load.text = "📂 Load"
	btn_load.pressed.connect(func(): load_game_requested.emit())
	top_box.add_child(btn_load)
	
	# Raid Warning Banner
	label_raid_warning = Label.new()
	label_raid_warning.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label_raid_warning.offset_top = 45
	label_raid_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_raid_warning.text = "⚠ RAID WARNING: RAIDERS DETECTED!"
	label_raid_warning.add_theme_color_override("font_color", Color.RED)
	label_raid_warning.visible = false
	add_child(label_raid_warning)
	
	# Bottom Build Bar
	var bottom_panel: Panel = Panel.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.custom_minimum_size = Vector2(0, 50)
	add_child(bottom_panel)
	
	var bottom_box: HBoxContainer = HBoxContainer.new()
	bottom_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_box.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_box)
	
	var build_options: Array[Dictionary] = [
		{"id": &"house", "label": "House (4T)"},
		{"id": &"farm", "label": "Farm (5T)"},
		{"id": &"woodcutter", "label": "Woodcutter (2T)"},
		{"id": &"quarry", "label": "Quarry (6T)"},
		{"id": &"bakery", "label": "Bakery (4T 4S)"},
		{"id": &"storehouse", "label": "Storehouse (8T 4S)"},
		{"id": &"barracks", "label": "Barracks (10T 8S)"},
		{"id": &"road", "label": "Road"}
	]
	
	for opt in build_options:
		var btn: Button = Button.new()
		btn.text = opt["label"]
		var build_id: StringName = opt["id"]
		btn.pressed.connect(func(): build_selected.emit(build_id))
		bottom_box.add_child(btn)
		
	# Side Inspector Panel
	panel_inspector = PanelContainer.new()
	panel_inspector.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel_inspector.offset_left = -260
	panel_inspector.offset_top = 50
	panel_inspector.offset_right = -10
	panel_inspector.offset_bottom = 260
	panel_inspector.visible = false
	add_child(panel_inspector)
	
	var insp_box: VBoxContainer = VBoxContainer.new()
	insp_box.add_theme_constant_override("separation", 6)
	panel_inspector.add_child(insp_box)
	
	label_inspector_title = Label.new()
	label_inspector_title.text = "Building Name"
	insp_box.add_child(label_inspector_title)
	
	label_inspector_status = Label.new()
	label_inspector_status.text = "Status: OK"
	insp_box.add_child(label_inspector_status)
	
	var worker_box: HBoxContainer = HBoxContainer.new()
	label_inspector_workers = Label.new()
	label_inspector_workers.text = "Workers: 1/2"
	worker_box.add_child(label_inspector_workers)
	
	var btn_worker_minus: Button = Button.new()
	btn_worker_minus.text = " - "
	btn_worker_minus.pressed.connect(func(): worker_assignment_changed.emit(-1))
	worker_box.add_child(btn_worker_minus)
	
	var btn_worker_plus: Button = Button.new()
	btn_worker_plus.text = " + "
	btn_worker_plus.pressed.connect(func(): worker_assignment_changed.emit(1))
	worker_box.add_child(btn_worker_plus)
	insp_box.add_child(worker_box)
	
	label_inspector_inv = Label.new()
	label_inspector_inv.text = "Inventory:\n - None"
	insp_box.add_child(label_inspector_inv)
	
	# Barracks Recruitment Box
	box_recruitment = VBoxContainer.new()
	box_recruitment.visible = false
	insp_box.add_child(box_recruitment)
	
	var btn_spearman: Button = Button.new()
	btn_spearman.text = "Recruit Spearman (15 Coin)"
	btn_spearman.pressed.connect(func(): recruit_unit_requested.emit(&"spearman"))
	box_recruitment.add_child(btn_spearman)
	
	var btn_archer: Button = Button.new()
	btn_archer.text = "Recruit Archer (20 Coin)"
	btn_archer.pressed.connect(func(): recruit_unit_requested.emit(&"archer"))
	box_recruitment.add_child(btn_archer)

func update_resources(coin: int, bread: int, grain: int, timber: int, stone: int) -> void:
	if label_resources != null:
		label_resources.text = "Coin: %d | Bread: %d | Grain: %d | Timber: %d | Stone: %d" % [coin, bread, grain, timber, stone]

func update_population(total: int, fed: int, hungry: int, at_risk: int) -> void:
	if label_population != null:
		label_population.text = "Pop: %d | Fed: %d | Hungry: %d | At-Risk: %d" % [total, fed, hungry, at_risk]

func update_economy(tax_name: String, approval_val: float) -> void:
	if label_approval != null:
		label_approval.text = "Approval: %d%%" % int(roundf(approval_val))
	if btn_tax != null:
		btn_tax.text = "Tax: %s" % tax_name

func show_building_details(building: BuildingState, def_info: Dictionary) -> void:
	if building == null:
		panel_inspector.visible = false
		return
		
	panel_inspector.visible = true
	label_inspector_title.text = def_info.get("display_name", str(building.definition_id))
	
	var status_text: String = "Status: Active"
	if building.current_block_reason != &"":
		status_text = "Status: BLOCKED (%s)" % str(building.current_block_reason)
	label_inspector_status.text = status_text
	
	var max_slots: int = def_info.get("worker_slots", 0)
	label_inspector_workers.text = "Workers: %d / %d" % [building.assigned_workers, max_slots]
	
	var inv_text: String = "Inventory (%d/%d):\n" % [building.inventory.get_total_quantity(), building.inventory.capacity]
	if building.inventory.quantities.is_empty():
		inv_text += " (Empty)"
	else:
		for res_id in building.inventory.quantities:
			inv_text += " - %s: %d\n" % [str(res_id), building.inventory.quantities[res_id]]
	label_inspector_inv.text = inv_text
	
	if box_recruitment != null:
		box_recruitment.visible = (building.definition_id == &"barracks")

func show_raid_warning(seconds_left: float) -> void:
	if label_raid_warning != null:
		label_raid_warning.visible = true
		label_raid_warning.text = "⚠ RAID WARNING: RAIDERS ARRIVING IN %d SECONDS!" % int(ceilf(seconds_left))

func hide_raid_warning() -> void:
	if label_raid_warning != null:
		label_raid_warning.visible = false
