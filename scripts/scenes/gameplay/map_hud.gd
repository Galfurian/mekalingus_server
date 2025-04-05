extends Node

# The size of sectors.
const SECTOR_SIZE: int = 10

# The current game map.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The currently selected entity.
var selected_entity: MapEntity

@onready var action_menu = $ActionMenu
@onready var scroll_view = $VBoxContainer/HBoxContainer/GridMap/ScrollView
@onready var grid_container = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer
@onready var grid_drawer = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/GridDrawer
@onready var mek_drawer = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/MekDrawer
@onready var time_of_day_overlay = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/TimeOfDayOverlay
@onready var combat_log = $VBoxContainer/LogPanel/TabContainer/CombatLog/ScrollContainer/CombatLog
@onready var info_panel = $VBoxContainer/HBoxContainer/InfoPanel
@onready var log_panel = $VBoxContainer/LogPanel

@onready var time_label = $VBoxContainer/HBoxContainer/GridMap/TimeLabel

func _ready():
	"""Initializes the map HUD."""
	grid_container.on_cell_selected.connect(_on_cell_selected)
	combat_log.meta_clicked.connect(_on_log_meta_clicked)
	scroll_view.scrolled.connect(_on_map_scrolled)


func setup(p_game_map: GameMap, p_grid_size: int = 50):
	"""Sets up the map HUD with the given game map and grid size."""
	clear()
	# Set the variables.
	game_map = p_game_map
	grid_size = p_grid_size
	# Initialize all components with the chosen grid size
	time_of_day_overlay.setup(p_game_map, grid_size, SECTOR_SIZE)
	grid_container.setup(p_game_map, grid_size, SECTOR_SIZE)
	grid_drawer.setup(p_game_map, grid_size, SECTOR_SIZE)
	mek_drawer.setup(p_game_map, grid_size, SECTOR_SIZE)
	info_panel.setup(p_game_map)
	log_panel.setup(p_game_map)
	# Connect signals once.
	if game_map and not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	# Update the time of day based on the current turn.
	_update_time_of_day()
	# Center the view on the map.
	zoom_out()


func clear():
	"""Clears the map HUD."""
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	game_map = null
	selected_entity = null
	# Clear the sub-components.
	time_of_day_overlay.clear()
	grid_container.clear()
	grid_drawer.clear()
	mek_drawer.clear()
	info_panel.clear()
	log_panel.clear()


func redraw(p_grid_size: int):
	"""Redraws the map HUD with a new grid size."""
	if not game_map:
		return
	# Update the grid size.
	grid_size = p_grid_size
	# Re-setup all components with the new grid size.
	time_of_day_overlay.setup(game_map, grid_size, SECTOR_SIZE)
	grid_container.setup(game_map, grid_size, SECTOR_SIZE)
	grid_drawer.setup(game_map, grid_size, SECTOR_SIZE)
	mek_drawer.setup(game_map, grid_size, SECTOR_SIZE)


func center_on(position: Vector2i) -> void:
	"""Centers the scroll view on the given tile position."""
	if not game_map:
		return
	# Convert tile coordinates to pixel coordinates.
	var tile_pixel_pos = (position + Vector2i(SECTOR_SIZE, SECTOR_SIZE)) * grid_size
	# Get the size of the scroll viewport (i.e., the visible area).
	var visible_size = scroll_view.get_size()
	# Center position = move the scroll so the position is in the center of the screen.
	var scroll_x = tile_pixel_pos.x - (visible_size.x / 2.) + (grid_size / 2.)
	var scroll_y = tile_pixel_pos.y - (visible_size.y / 2.) + (grid_size / 2.)
	# Compute the maximum scroll limits to prevent scrolling out of bounds.
	var max_scroll_x = (game_map.map_width + SECTOR_SIZE * 2) * grid_size - visible_size.x
	var max_scroll_y = (game_map.map_height + SECTOR_SIZE * 2) * grid_size - visible_size.y
	# Apply clamped scrolling.
	scroll_view.scroll_horizontal = clamp(scroll_x, 0, max_scroll_x)
	scroll_view.scroll_vertical = clamp(scroll_y, 0, max_scroll_y)


func zoom_out():
	"""Zooms out the map view."""
	if not game_map:
		return
	# Get the size of the scroll viewport (i.e., the visible area).
	var visible_size = scroll_view.get_size()
	# Compute the minimum grid size to fit the whole map.
	var min_grid_size_x = visible_size.x / (game_map.map_width + SECTOR_SIZE * 2)
	var min_grid_size_y = visible_size.y / (game_map.map_height + SECTOR_SIZE * 2)
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y))
	# Round to an even number for consistency.
	grid_size = int(floor(min_grid_size / 2.0)) * 2
	# Redraw the map with the new grid size.
	redraw(grid_size)


func _on_turn_ended(_turn_number: int):
	# Called when the turn ends
	if selected_entity:
		center_on(selected_entity.position)
	# Update the time of day based on the current turn.
	_update_time_of_day()


func _update_time_of_day() -> void:
	if not game_map:
		return
	print("Update time of day based on map: ", game_map.map_uuid)
	# Get the current time of day from the game map.
	var time_of_day = game_map.turn_manager.get_time_of_day()
	# Convert to HH:MM style time (e.g., 0.25 = 06:00)
	var hours = int(time_of_day * 24.0)
	var minutes = int(int(time_of_day * 1440) % 60)
	# Update the label
	time_label.text = "%02d:%02d" % [hours, minutes]


func _on_log_meta_clicked(meta: String) -> void:
	"""Handles meta clicks in the combat log."""
	# Handle item link: item:<mek_uuid>:<item_uuid>
	if meta.begins_with("item:"):
		var parts = meta.substr(5).split(":")
		if parts.size() != 2:
			printerr("Invalid item meta format: ", meta)
			return
		var mek_uuid = parts[0]
		var item_uuid = parts[1]
		var entity = game_map.get_entity(mek_uuid)
		if entity and is_instance_of(entity, MapMek):
			selected_entity = entity
			center_on(entity.position)
			info_panel.set_entity(entity)
			info_panel.select_item_by_uuid(item_uuid)
			grid_drawer.set_selected_entity(entity)
		else:
			printerr("Could not find valid Mek entity for item link: ", meta)
	# Handle Mek link: mek:<mek_uuid>
	elif meta.begins_with("mek:"):
		var mek_uuid = meta.substr(4)
		var entity = game_map.get_entity(mek_uuid)
		if entity and is_instance_of(entity, MapMek):
			selected_entity = entity
			center_on(entity.position)
			info_panel.set_entity(entity)
			grid_drawer.set_selected_entity(entity)
		else:
			printerr("Could not find valid Mek entity for mek link: ", meta)
	elif meta.begins_with("pos:"):
		var coord_text = meta.substr(4)
		var coords = coord_text.split(",")
		if coords.size() != 2:
			printerr("Invalid position meta format: ", meta)
			return
		var x = int(coords[0])
		var y = int(coords[1])
		var target_pos = Vector2i(x, y)
		if game_map.in_bounds(target_pos):
			center_on(target_pos)
		else:
			printerr("Position out of bounds: ", target_pos)
	else:
		printerr("Unknown meta clicked: ", meta)


func _on_cell_selected(cell_position: Vector2i):
	"""Handles cell selection and updates the UnitInfoPanel."""
	# Get the entity at the given position.
	var entity = game_map.get_entity_at(cell_position)
	if entity:
		selected_entity = entity
		center_on(entity.position)
		info_panel.set_entity(entity)
		grid_drawer.set_selected_entity(entity)


func _on_map_scrolled(scroll_up: bool):
	"""Handles map scrolling and zooming."""
	if not game_map:
		return
	# Store previous grid size before updating.
	var old_grid_size = grid_size
	# Get the size of the scroll viewport (i.e., visible area)
	var visible_size = scroll_view.get_size()
	# Full number of tiles that need to be visible, including sector borders
	var total_tiles_x = game_map.map_width + SECTOR_SIZE * 2
	var total_tiles_y = game_map.map_height + SECTOR_SIZE * 2
	# Compute the minimum grid size that would fit the entire map (including sectors)
	var min_grid_size_x = visible_size.x / total_tiles_x
	var min_grid_size_y = visible_size.y / total_tiles_y
	# Prevent grid from being too small.
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y))
	# Compute the maximum grid size for deep zoom in
	var max_grid_size_x = visible_size.x / 5 # e.g., show only ~5 tiles max when zoomed in
	var max_grid_size_y = visible_size.y / 5
	var max_grid_size = min(max_grid_size_x, max_grid_size_y)
	# Adjust the grid size within allowed range
	if scroll_up and grid_size < max_grid_size:
		grid_size += 2
	elif not scroll_up and grid_size > min_grid_size:
		grid_size -= 2
	else:
		return # No change needed
	# Get mouse position inside the ScrollContainer.
	var mouse_pos = scroll_view.get_local_mouse_position()
	# Store previous scroll positions.
	var old_scroll_h = scroll_view.scroll_horizontal
	var old_scroll_v = scroll_view.scroll_vertical
	# Apply the new zoom level to the map.
	redraw(grid_size)
	# Adjust scrolling to keep the zoom centered on the mouse position.
	var scale_factor = float(grid_size) / float(old_grid_size)
	scroll_view.scroll_horizontal = int(
		old_scroll_h * scale_factor + mouse_pos.x * (scale_factor - 1)
	)
	scroll_view.scroll_vertical = int(
		old_scroll_v * scale_factor + mouse_pos.y * (scale_factor - 1)
	)
