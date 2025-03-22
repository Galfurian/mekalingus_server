extends Node

@onready var info_panel  = $VBoxContainer/HBoxContainer/InfoPanel
@onready var log_panel   = $VBoxContainer/LogPanel
@onready var action_menu = $ActionMenu

@onready var grid_drawer      = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/GridDrawer
@onready var mek_drawer       = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/MekDrawer
@onready var grid_container   = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer
@onready var scroll_view      = $VBoxContainer/HBoxContainer/GridMap/ScrollView

var game_map: GameMap
var grid_size: int
var sector_size: int

func _ready():
	grid_container.on_cell_selected.connect(_on_cell_selected)
	scroll_view.scrolled.connect(_on_map_scrolled)

func clear():
	grid_container.clear()
	grid_drawer.clear()
	mek_drawer.clear()
	info_panel.clear()
	log_panel.clear()

func setup(p_game_map: GameMap, p_grid_size: int = 50, p_sector_size: int = 10):
	game_map    = p_game_map
	grid_size   = p_grid_size
	sector_size = p_sector_size
	grid_container.setup(p_game_map, p_grid_size, p_sector_size)
	grid_drawer.setup(p_game_map, p_grid_size, p_sector_size)
	mek_drawer.setup(p_game_map, p_grid_size, p_sector_size)
	info_panel.setup(p_game_map)
	log_panel.setup(p_game_map)

func _on_cell_selected(cell_position: Vector2i):
	"""Handles cell selection and updates the UnitInfoPanel."""
	# Get the entity at the given position.
	var entity = game_map.get_entity_at(cell_position)
	if entity:
		# Send the entity to the info panel.
		info_panel.set_entity(entity)
		# Get the visible cells.
		if is_instance_of(entity.entity, Mek):
			grid_drawer.clear_selected_cells()
			var visible_cells = game_map.get_visible_tiles(cell_position)
			for visible_cell in visible_cells:
				grid_drawer.select_cell(visible_cell)

func _input(_event):
	if Input.is_key_pressed(KEY_ESCAPE):
		info_panel.clear()
		grid_drawer.clear_selected_cells()


func _on_map_scrolled(scroll_up: bool):
	if not game_map:
		return
	# Store previous grid size before updating.
	var old_grid_size = grid_size
	# Get the size of the scroll viewport (i.e., visible area)
	var visible_size = scroll_view.get_size()
	# Full number of tiles that need to be visible, including sector borders
	var total_tiles_x = game_map.map_width + sector_size * 2
	var total_tiles_y = game_map.map_height + sector_size * 2
	# Compute the minimum grid size that would fit the entire map (including sectors)
	var min_grid_size_x = visible_size.x / total_tiles_x
	var min_grid_size_y = visible_size.y / total_tiles_y
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y)) # Prevent grid from being too small
	# Compute the maximum grid size for deep zoom in
	var max_grid_size_x = visible_size.x / 5  # e.g., show only ~5 tiles max when zoomed in
	var max_grid_size_y = visible_size.y / 5
	var max_grid_size = min(max_grid_size_x, max_grid_size_y)
	# Adjust the grid size within allowed range
	if scroll_up and grid_size < max_grid_size:
		grid_size += 2
	elif not scroll_up and grid_size > min_grid_size:
		grid_size -= 2
	else:
		return  # No change needed
	# Get mouse position inside the ScrollContainer.
	var mouse_pos = scroll_view.get_local_mouse_position()
	# Store previous scroll positions.
	var old_scroll_h = scroll_view.scroll_horizontal
	var old_scroll_v = scroll_view.scroll_vertical
	# Apply the new zoom level to the map.
	setup(game_map, grid_size)
	# Adjust scrolling to keep the zoom centered on the mouse position.
	var scale_factor = float(grid_size) / float(old_grid_size)
	scroll_view.scroll_horizontal = int(old_scroll_h * scale_factor + mouse_pos.x * (scale_factor - 1))
	scroll_view.scroll_vertical = int(old_scroll_v * scale_factor + mouse_pos.y * (scale_factor - 1))
