extends ScrollContainer

# Define the signal
signal scrolled(scroll_up: bool, mouse_pos: Vector2)

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_scroll: Vector2 = Vector2.ZERO
var _drag_threshold: float = 5.0

func _ready():
	set_mouse_filter(Control.MOUSE_FILTER_PASS)

func _gui_input(event):
	# Left-click drag for panning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_start_pos = get_local_mouse_position()
			_drag_start_scroll = Vector2(scroll_horizontal, scroll_vertical)
			# Don't consume the event yet - let grid_container handle selection
		else:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var current_pos = get_local_mouse_position()
		var delta = current_pos - _drag_start_pos
		# Only treat as drag if movement exceeds threshold
		if delta.length() > _drag_threshold:
			scroll_horizontal = int(_drag_start_scroll.x - delta.x)
			scroll_vertical = int(_drag_start_scroll.y - delta.y)
	# CTRL + Scroll for Zoom
	elif event is InputEventMouseButton and Input.is_key_pressed(KEY_CTRL):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scrolled.emit(true, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scrolled.emit(false, event.position)
	# SHIFT + Scroll for Horizontal Scrolling
	elif event is InputEventMouseButton and Input.is_key_pressed(KEY_SHIFT):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_horizontal -= 30
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_horizontal += 30
	# Normal Scroll for Vertical Scrolling
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_vertical -= 30
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_vertical += 30