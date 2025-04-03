extends Node2D

# =============================================================================
# CONSTANTS
# =============================================================================

const MAJOR_GRID_COLOR = Color(0.4, 0.4, 0.4, 0.5)
const MINOR_GRID_COLOR = Color(0.2, 0.2, 0.2, 0.5)
const MAJOR_GRID_SIZE = 3
const MINOR_GRID_SIZE = 1

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var grid_size: int
var sector_size: int
var selected_entity: MapEntity

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func setup(p_game_map: GameMap, p_grid_size: int, p_sector_size: int):
	game_map = p_game_map
	grid_size = p_grid_size
	sector_size = p_sector_size
	if not game_map.turn_manager.turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.turn_ended.connect(_on_turn_ended)
	queue_redraw()


func clear() -> void:
	if game_map and game_map.turn_manager.turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.turn_ended.disconnect(_on_turn_ended)

	game_map = null
	grid_size = 0
	sector_size = 0
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


func get_draw_offset() -> Vector2:
	# Offset by one sector in each direction
	return Vector2(sector_size * grid_size, sector_size * grid_size)


func to_grid_position(map_position: Vector2) -> Vector2:
	# Offset by one sector in each direction
	return Vector2(map_position.x * grid_size, map_position.y * grid_size) + get_draw_offset()


func _on_turn_ended(_turn_number: int):
	# Called when the turn ends
	queue_redraw()


func _draw():
	if not game_map:
		return

	var offset = get_draw_offset()

	# Draw actual map tiles (with offset applied).
	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			# Compute the position with the offset
			var x_pos = x * grid_size + offset.x
			var y_pos = y * grid_size + offset.y
			draw_rect(
				Rect2(x_pos, y_pos, grid_size, grid_size), game_map.get_tile_color(x, y), true
			)

	# Draw grid overlay (including extended grid lines).
	for x in range(game_map.map_width + sector_size + sector_size):
		var start = Vector2(x * grid_size, 0)
		var end = Vector2(x * grid_size, (game_map.map_height + sector_size * 2) * grid_size)
		if (x % sector_size) == 0:
			draw_line(start, end, MAJOR_GRID_COLOR, MAJOR_GRID_SIZE)
		else:
			draw_line(start, end, MINOR_GRID_COLOR, MINOR_GRID_SIZE)
	for y in range(game_map.map_height + sector_size + sector_size):
		var start = Vector2(0, y * grid_size)
		var end = Vector2((game_map.map_width + sector_size * 2) * grid_size, y * grid_size)
		if (y % sector_size) == 0:
			draw_line(start, end, MAJOR_GRID_COLOR, MAJOR_GRID_SIZE)
		else:
			draw_line(start, end, MINOR_GRID_COLOR, MINOR_GRID_SIZE)
