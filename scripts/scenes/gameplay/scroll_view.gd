extends ScrollContainer

signal zoom_requested(scroll_up: bool, mouse_pos: Vector2)

const DRAG_THRESHOLD: float = 5.0
const WHEEL_SCROLL_STEP: int = 30

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_scroll: Vector2 = Vector2.ZERO

func _ready():
	set_mouse_filter(Control.MOUSE_FILTER_PASS)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag()
		else:
			_is_dragging = false
		return

	if not event.pressed:
		return

	if event.ctrl_pressed:
		if _emit_zoom_request(event):
			accept_event()
		return

	if event.shift_pressed:
		if _apply_shift_scroll(event):
			accept_event()
		return

	if _apply_vertical_scroll(event):
		accept_event()


func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not _is_dragging:
		return

	var current_pos: Vector2 = get_local_mouse_position()
	var delta: Vector2 = current_pos - _drag_start_pos
	if delta.length() <= DRAG_THRESHOLD:
		return

	scroll_horizontal = int(_drag_start_scroll.x - delta.x)
	scroll_vertical = int(_drag_start_scroll.y - delta.y)


func _begin_drag() -> void:
	_is_dragging = true
	_drag_start_pos = get_local_mouse_position()
	_drag_start_scroll = Vector2(scroll_horizontal, scroll_vertical)


func _emit_zoom_request(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_requested.emit(true, event.position)
		return true

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_requested.emit(false, event.position)
		return true

	return false


func _apply_shift_scroll(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_horizontal -= WHEEL_SCROLL_STEP
		return true

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_horizontal += WHEEL_SCROLL_STEP
		return true

	return false


func _apply_vertical_scroll(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_vertical -= WHEEL_SCROLL_STEP
		return true

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_vertical += WHEEL_SCROLL_STEP
		return true

	return false