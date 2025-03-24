extends Node2D

var game_map: GameMap
var grid_size: int
var sector_size: int

var selected_entity: MapEntity
var selected_cells: Dictionary

func setup(p_game_map: GameMap, p_grid_size: int = 50, p_sector_size: int = 10):
	game_map    = p_game_map
	grid_size   = p_grid_size
	sector_size = p_sector_size
	if not game_map.on_round_end.is_connected(queue_redraw):
		game_map.on_round_end.connect(queue_redraw)
	queue_redraw()

func clear() -> void:
	game_map.on_round_end.disconnect(queue_redraw)
	game_map  = null
	grid_size = 50
	selected_cells.clear()
	selected_entity = null
	queue_redraw()

func set_selected_entity(entity: MapEntity):
	"""Adds a highlighted cell at the given position."""
	selected_entity = entity
	queue_redraw()
	
func deselect_entity():
	if selected_entity:
		selected_entity = null
		queue_redraw()

func select_cell(grid_position: Vector2i, color: Color = Color(1, 1, 1, 0.1)):
	"""Adds a highlighted cell at the given position."""
	selected_cells[grid_position] = color
	queue_redraw()

func deselect_cell(grid_position: Vector2i):
	"""Removes a highlighted cell from the grid."""
	if grid_position in selected_cells:
		selected_cells.erase(grid_position)
		queue_redraw()

func clear_selected_cells():
	"""Removes all selected cells."""
	selected_cells.clear()
	queue_redraw()

func get_draw_offset() -> Vector2:
	# Offset by one sector in each direction
	return Vector2(sector_size * grid_size, sector_size * grid_size)

func to_grid_position(map_position: Vector2) -> Vector2:
	# Offset by one sector in each direction
	return Vector2(map_position.x * grid_size, map_position.y * grid_size) + get_draw_offset()

func _draw():
	if not game_map:
		return

	var offset = get_draw_offset()
	var major_grid_color = Color(0.4, 0.4, 0.4, 0.5)
	var minor_grid_color = Color(0.2, 0.2, 0.2, 0.5)
	var major_grid_size = 3
	var minor_grid_size = 1

	# Draw actual map tiles (with offset applied).
	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			var tile_pos  = Vector2(x * grid_size, y * grid_size) + offset
			var tile_size = Vector2(grid_size, grid_size)
			draw_rect(Rect2(tile_pos, tile_size), game_map.get_tile_color(x, y), true)
#
	# Draw grid overlay (including extended grid lines).
	for x in range(game_map.map_width + sector_size + sector_size):
		var start = Vector2(x * grid_size, 0)
		var end   = Vector2(x * grid_size, (game_map.map_height + sector_size * 2) * grid_size)
		if (x % sector_size) == 0:
			draw_line(start, end, major_grid_color, major_grid_size)
		else:
			draw_line(start, end, minor_grid_color, minor_grid_size)
#
	for y in range(game_map.map_height + sector_size + sector_size):
		var start = Vector2(0, y * grid_size)
		var end   = Vector2((game_map.map_width + sector_size * 2) * grid_size, y * grid_size)
		if (y % sector_size) == 0:
			draw_line(start, end, major_grid_color, major_grid_size)
		else:
			draw_line(start, end, minor_grid_color, minor_grid_size)
#
	# Draw highlight boxes around selected cells (with offset)
	for cell_position in selected_cells.keys():
		var box_color = selected_cells[cell_position]
		var tile_pos  = Vector2(cell_position.x * grid_size, cell_position.y * grid_size) + offset
		var tile_size = Vector2(grid_size, grid_size)
		draw_rect(Rect2(tile_pos, tile_size), box_color, true)
		
	if selected_entity and is_instance_of(selected_entity.entity, Mek):
		var detection_range = game_map.DEFAULT_DETECTION_RANGE
		var center = selected_entity.position
		for y in range(game_map.map_height):
			for x in range(game_map.map_width):
				var tile = Vector2i(x, y)
				if tile.distance_to(center) > detection_range:
					var tile_pos = Vector2((x + sector_size) * grid_size, (y + sector_size) * grid_size)
					var tile_size = Vector2(grid_size, grid_size)
					var dim_color = Color(0, 0, 0, 0.5)
					draw_rect(Rect2(tile_pos, tile_size), dim_color, true)
