class_name RTSCamera
extends Camera2D

@export var pan_speed: float = 600.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.15

var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_cam: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0
		
	if move_vec != Vector2.ZERO:
		position += move_vec.normalized() * (pan_speed / zoom.x) * delta
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at_point(mb.position, 1.0 + zoom_speed)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at_point(mb.position, 1.0 - zoom_speed)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse = mb.position
				_pan_start_cam = position
			else:
				_is_panning = false
	elif event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var offset: Vector2 = (mm.position - _pan_start_mouse) / zoom
		position = _pan_start_cam - offset
		_clamp_position()

func zoom_at_point(screen_pos: Vector2, factor: float) -> void:
	var old_zoom: Vector2 = zoom
	var new_zoom: Vector2 = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	if new_zoom == old_zoom:
		return
	zoom = new_zoom
	_clamp_position()

func _clamp_position() -> void:
	var tile_size: float = 16.0
	var map_w: float = 96.0 * tile_size
	var map_h: float = 96.0 * tile_size
	position.x = clampf(position.x, 0.0, map_w)
	position.y = clampf(position.y, 0.0, map_h)
