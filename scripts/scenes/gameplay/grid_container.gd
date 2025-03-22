extends Control

@onready var grid_drawer      = $GridDrawer
@onready var mek_drawer       = $MekDrawer

var map_data: GameMap
var grid_size: int
var sector_size: int

# Define a signal for cell selection.
signal on_cell_selected(cell_position: Vector2i)

func setup(p_map_data: GameMap, p_grid_size: int = 50, p_sector_size: int = 10):
	map_data = p_map_data
	grid_size = p_grid_size
	sector_size = p_sector_size
	
	var width  = (map_data.map_width + sector_size * 2) * grid_size
	var height = (map_data.map_height + sector_size * 2) * grid_size
	
	# Set custom_minimum_size of GridContainer to match GridDrawer's bounds.
	custom_minimum_size = Vector2(width, height)

func clear():
	map_data  = null
	grid_size = 50
	sector_size = 10

func _gui_input(event):
	"""Detects left mouse clicks and emits the selected cell index."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		var local_mouse_pos = get_local_mouse_position()  # Get position relative to this Control
		var cell_x = int(local_mouse_pos.x / grid_size) - sector_size
		var cell_y = int(local_mouse_pos.y / grid_size) - sector_size
		
		var selected_cell = Vector2i(cell_x, cell_y)
		
		# Ensure the selected cell is within bounds
		if selected_cell.x >= 0 and selected_cell.x < map_data.map_width and \
		   selected_cell.y >= 0 and selected_cell.y < map_data.map_height:
			on_cell_selected.emit(selected_cell)
