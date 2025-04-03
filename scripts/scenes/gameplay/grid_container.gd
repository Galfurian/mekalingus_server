extends Control

# Define a signal for cell selection.
signal on_cell_selected(cell_position: Vector2i)

# References to the GameMap.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The sector size (in tiles).
var sector_size: int


func setup(p_game_map: GameMap, p_grid_size: int, p_sector_size: int):
	clear()
	game_map = p_game_map
	grid_size = p_grid_size
	sector_size = p_sector_size
	var tile_width = game_map.map_width + sector_size * 2
	var tile_height = game_map.map_height + sector_size * 2
	custom_minimum_size = Vector2(tile_width * grid_size, tile_height * grid_size)


func clear():
	game_map = null
	grid_size = 0
	sector_size = 0


func _gui_input(event):
	"""Detects left mouse clicks and emits the selected cell index."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Get position relative to this Control.
		var local_mouse_pos = get_local_mouse_position()
		# Compute the selected cell based on the local mouse position.
		var selected_cell = Vector2i(
			int(local_mouse_pos.x / grid_size) - sector_size,
			int(local_mouse_pos.y / grid_size) - sector_size
		)
		# Ensure the selected cell is within bounds.
		if (
			selected_cell.x >= 0
			and selected_cell.x < game_map.map_width
			and selected_cell.y >= 0
			and selected_cell.y < game_map.map_height
		):
			on_cell_selected.emit(selected_cell)
