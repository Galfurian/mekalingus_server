extends Node

@onready var info_panel = $VBoxContainer/HBoxContainer/InfoPanel
@onready var action_menu = $ActionMenu

@onready var grid_drawer = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/GridDrawer
@onready var mek_drawer = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer/MekDrawer
@onready var grid_container = $VBoxContainer/HBoxContainer/GridMap/ScrollView/GridContainer
@onready var scroll_view = $VBoxContainer/HBoxContainer/GridMap/ScrollView

@onready var log_panel = $VBoxContainer/LogPanel
@onready var combat_log = $VBoxContainer/LogPanel/TabContainer/CombatLog/ScrollContainer/CombatLog

# The current game map.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The size of sectors.
var sector_size: int
# The currently selected entity.
var selected_entity: MapEntity


func _ready():
	"""Initializes the map HUD."""
	grid_container.on_cell_selected.connect(_on_cell_selected)
	combat_log.meta_clicked.connect(_on_log_meta_clicked)
	scroll_view.scrolled.connect(_on_map_scrolled)


func clear():
	"""Clears the map HUD."""
	if game_map:
		game_map.on_round_end.disconnect(_on_round_end)
	game_map = null
	grid_size = 50
	sector_size = 10
	selected_entity = null
	# Clear the sub-components.
	grid_container.clear()
	grid_drawer.clear()
	mek_drawer.clear()
	info_panel.clear()
	log_panel.clear()


func setup(p_game_map: GameMap, p_grid_size: int = 50, p_sector_size: int = 10):
	"""Sets up the map HUD with the given game map and grid size."""
	clear()
	# Initialize the new state.
	game_map = p_game_map
	grid_size = p_grid_size
	sector_size = p_sector_size
	grid_container.setup(p_game_map, p_grid_size, p_sector_size)
	grid_drawer.setup(p_game_map, p_grid_size, p_sector_size)
	mek_drawer.setup(p_game_map, p_grid_size, p_sector_size)
	info_panel.setup(p_game_map)
	log_panel.setup(p_game_map)
	if not game_map.on_round_end.is_connected(_on_round_end):
		game_map.on_round_end.connect(_on_round_end)


func center_on(position: Vector2i) -> void:
	"""Centers the scroll view on the given tile position."""
	if not scroll_view or not game_map:
		return
	# Convert tile coordinates to pixel coordinates.
	var tile_pixel_pos = (position + Vector2i(sector_size, sector_size)) * grid_size
	# Get the size of the scroll viewport (i.e., the visible area).
	var viewport_size = scroll_view.get_size()
	# Center position = move the scroll so the position is in the center of the screen.
	var scroll_x = tile_pixel_pos.x - (viewport_size.x / 2.) + (grid_size / 2.)
	var scroll_y = tile_pixel_pos.y - (viewport_size.y / 2.) + (grid_size / 2.)
	# Clamp scrolling within map bounds.
	var max_scroll_x = (
		game_map.map_width * grid_size + sector_size * 2 * grid_size - viewport_size.x
	)
	var max_scroll_y = (
		game_map.map_height * grid_size + sector_size * 2 * grid_size - viewport_size.y
	)
	scroll_view.scroll_horizontal = clamp(scroll_x, 0, max_scroll_x)
	scroll_view.scroll_vertical = clamp(scroll_y, 0, max_scroll_y)


func zoom_out():
	"""Zooms out the map view."""
	if not game_map or not scroll_view:
		return
	var visible_size = scroll_view.get_size()
	var total_tiles_x = game_map.map_width
	var total_tiles_y = game_map.map_height
	# Compute the minimum grid size to fit the whole map.
	var min_grid_size_x = visible_size.x / total_tiles_x
	var min_grid_size_y = visible_size.y / total_tiles_y
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y))
	# Round to an even number for consistency.
	grid_size = int(floor(min_grid_size / 2.0)) * 2
	setup(game_map, grid_size)
	# Center the view on the map.
	center_on(Vector2(game_map.map_width / 2.0, game_map.map_height / 2.0))


func _on_round_end() -> void:
	"""Handles the end of a round."""
	if selected_entity:
		center_on(selected_entity.position)


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
		if entity and is_instance_of(entity.entity, Mek):
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
		if entity and is_instance_of(entity.entity, Mek):
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
	game_map.add_log(
		Enums.LogType.SYSTEM,
		(
			"Cell(position: %s, %s, walkable: %s)"
			% [
				str(cell_position),
				str(game_map.map_biome.get_level(game_map.get_tile_id(cell_position))),
				str(game_map.is_walkable(cell_position))
			]
		)
	)


func _on_map_scrolled(scroll_up: bool):
	"""Handles map scrolling and zooming."""
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
	# Prevent grid from being too small.
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y))
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
	scroll_view.scroll_horizontal = int(
		old_scroll_h * scale_factor + mouse_pos.x * (scale_factor - 1)
	)
	scroll_view.scroll_vertical = int(
		old_scroll_v * scale_factor + mouse_pos.y * (scale_factor - 1)
	)
