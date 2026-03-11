# This one represents an order to move a unit to a specific position.
class_name MoveOrder
extends Order

# =============================================================================
# PROPERTIES
# =============================================================================

# The unit that is moving.
var source
# The target position.
var destination: Vector2i

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source: MapEntity, p_destination: Vector2i) -> void:
	source = p_source
	destination = p_destination


func _add_log(game_map, message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.MOVEMENT, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(game_map) -> bool:
	var mek = source.mek
	if mek.is_dead():
		return false

	var start_pos = source.position

	var path = AIUtils.get_shortest_path(game_map, start_pos, destination)

	if path.is_empty() or path.size() <= 1:
		# No movement possible.
		_add_log(game_map, "%s could not move to %s (no valid path)" % [mek.get_chat_tag(), _format_pos_tag(destination)])
		return false

	var current_tile = start_pos
	var fallback_tile = start_pos
	var total_cost = 0
	var max_movement = mek.speed

	for i in range(1, path.size()):
		var tile = path[i]
		var cost = game_map.get_movement_cost(tile)
		if cost < 0:
			break
		if total_cost + cost > max_movement:
			break
		if game_map.can_move_to(tile):
			current_tile = tile
		else:
			current_tile = fallback_tile
			break
		total_cost += cost
		fallback_tile = tile

	# Update position.
	mek.tiles_moved_last_turn = start_pos.distance_to(current_tile)

	_add_log(game_map, "%s moved from %s to %s (%d tiles)" % [
		mek.get_chat_tag(),
		_format_pos_tag(start_pos),
		_format_pos_tag(current_tile),
		mek.tiles_moved_last_turn])

	source.position = current_tile
	game_map.collect_pickup_at(current_tile, source)
	return true


func _to_string() -> String:
	var s = ""
	if is_instance_of(source.mek, Mek):
		s += source.combatant.get_mek_name()
	else:
		s += str(source.mek)
	s += " is moving"
	s += " from (" + str(source.position.x) + ", " + str(source.position.y) + ")"
	s += " to (" + str(destination.x) + ", " + str(destination.y) + ")"
	return s
