# This overlay draws a rectangle over the game map and through a shader
# it simulates the time of day.

extends Node2D

# The current game map.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The outer scroll padding size (in tiles).
var padding_tiles: int

func setup(p_game_map: GameMap, p_grid_size: int, p_padding_tiles: int):
	"""
	Sets up the grid with the given parameters.
	"""
	# Clear the overlay.
	clear()
	# Set the game map and parameters.
	game_map = p_game_map
	grid_size = p_grid_size
	padding_tiles = p_padding_tiles
	# Connect the turn ended signal to update the shader.
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	# Upda the the time of day based on the current turn.
	_update_shader()
	# Set the shader parameters.
	queue_redraw()

func clear():
	"""
	Clears the grid and resets its parameters.
	"""
	# If connected, disconnect the turn ended signal.
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	# Clear all the parameters.
	game_map = null
	grid_size = 0
	padding_tiles = 0
	queue_redraw()

func _on_turn_ended(_turn_number: int) -> void:
	_update_shader()
	queue_redraw()


func _update_shader() -> void:
	# If we have a material set, update the shader parameter.
	if material and game_map:
		material.set_shader_parameter("time_of_day", game_map.turn_manager.get_time_of_day())

func _draw():
	var offset = _get_draw_offset()
	var size = _get_draw_size()
	# This just draws a full white rectangle (shader will color it)
	draw_rect(Rect2(offset, size), Color(1, 1, 1, 1), true)

func _get_draw_offset() -> Vector2:
	"""
	Returns the offset of the grid overlay due to the border sector.
	"""
	return Vector2(padding_tiles * grid_size, padding_tiles * grid_size)

func _get_draw_size() -> Vector2:
	"""
	Returns the size of the grid overlay.
	"""
	if not game_map:
		return Vector2.ZERO
	return Vector2(grid_size * game_map.map_width, grid_size * game_map.map_height)
