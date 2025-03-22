extends ScrollContainer

# Define the signal
signal scrolled(scroll_up: bool)

func _gui_input(event):
	# CTRL + Scroll for Zoom
	if event is InputEventMouseButton and Input.is_key_pressed(KEY_CTRL):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scrolled.emit(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scrolled.emit(false)
		accept_event()
	# SHIFT + Scroll for Horizontal Scrolling
	elif event is InputEventMouseButton and Input.is_key_pressed(KEY_SHIFT):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_horizontal -= 30
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_horizontal += 30
		accept_event()
	# Normal Scroll for Vertical Scrolling
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_vertical -= 30
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_vertical += 30
		accept_event()
