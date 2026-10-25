class_name UITheme
extends RefCounted

# Colors
const COLOR_BG_DARK: Color = Color(0.055, 0.075, 0.065, 0.97)
const COLOR_BG_PANEL: Color = Color(0.085, 0.105, 0.09, 0.985)
const COLOR_BG_LIGHT: Color = Color(0.14, 0.17, 0.14, 0.98)
const COLOR_BORDER: Color = Color(0.32, 0.36, 0.28)
const COLOR_BORDER_GOLD: Color = Color(0.72, 0.56, 0.27)
const COLOR_ACCENT_GOLD: Color = Color(0.93, 0.76, 0.38)
const COLOR_RED_ALERT: Color = Color(0.85, 0.22, 0.22)
const COLOR_GREEN_OK: Color = Color(0.53, 0.78, 0.43)
const COLOR_TEXT_MUTED: Color = Color(0.65, 0.69, 0.61)

static func create_panel_style(bg: Color = COLOR_BG_DARK, border: Color = COLOR_BORDER, border_width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func create_button_style(bg: Color = COLOR_BG_LIGHT, border: Color = COLOR_BORDER, radius: int = 5) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func create_button_hover_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = create_button_style(Color(0.25, 0.28, 0.35), COLOR_BORDER_GOLD, 5)
	sb.border_color = COLOR_BORDER_GOLD
	sb.set_border_width_all(2)
	return sb

static func create_button_active_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = create_button_style(Color(0.30, 0.26, 0.15), COLOR_ACCENT_GOLD, 5)
	sb.border_color = COLOR_ACCENT_GOLD
	sb.set_border_width_all(2)
	return sb

static func apply_button_style(btn: Button, is_active: bool = false) -> void:
	btn.add_theme_stylebox_override("normal", create_button_active_style() if is_active else create_button_style())
	btn.add_theme_stylebox_override("hover", create_button_hover_style())
	btn.add_theme_stylebox_override("pressed", create_button_active_style())
	btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.focus_mode = Control.FOCUS_NONE
