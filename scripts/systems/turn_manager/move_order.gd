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
	return MetaTag.pos_tag(pos)


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(game_map) -> bool:
	var mek: CombatEntity = source.combatant
	if mek.is_dead():
		return false
	var start_pos: Vector2i = source.position
	var path: Array[Vector2i] = AIPathfinder.get_shortest_path(game_map, start_pos, destination)
	if not _has_valid_path(path):
		_log_no_path(game_map, mek)
		return false

	var end_pos: Vector2i = _resolve_reachable_tile_on_path(game_map, path, mek.speed, start_pos)
	return _commit_movement(game_map, mek, start_pos, end_pos)


func _to_string() -> String:
	var s = ""
	if is_instance_of(source.combatant, Mek):
		s += source.combatant.get_mek_name()
	else:
		s += str(source.combatant)
	s += " is moving"
	s += " from (" + str(source.position.x) + ", " + str(source.position.y) + ")"
	s += " to (" + str(destination.x) + ", " + str(destination.y) + ")"
	return s


func _has_valid_path(path: Array[Vector2i]) -> bool:
	return not path.is_empty() and path.size() > 1


func _log_no_path(game_map, mek: CombatEntity) -> void:
	_add_log(
		game_map,
		(
			"%s could not move to %s (no valid path)"
			% [mek.get_chat_tag(), _format_pos_tag(destination)]
		),
	)


func _resolve_reachable_tile_on_path(
	game_map,
	path: Array[Vector2i],
	max_movement: int,
	start_pos: Vector2i,
) -> Vector2i:
	var current_tile: Vector2i = start_pos
	var fallback_tile: Vector2i = start_pos
	var total_cost := 0

	for i in range(1, path.size()):
		var tile: Vector2i = path[i]
		var cost: int = game_map.get_movement_cost(tile)
		if cost < 0:
			break
		if total_cost + cost > max_movement:
			break
		if game_map.can_move_to(tile):
			current_tile = tile
		else:
			# Preserve legacy fallback behavior when destination tile in path is occupied.
			current_tile = fallback_tile
			break
		total_cost += cost
		fallback_tile = tile

	return current_tile


func _commit_movement(
	game_map,
	mek: CombatEntity,
	start_pos: Vector2i,
	end_pos: Vector2i,
) -> bool:
	mek.tiles_moved_last_turn = int(start_pos.distance_to(end_pos))
	_add_log(
		game_map,
		(
			"%s moved from %s to %s (%d tiles)"
			% [
				mek.get_chat_tag(),
				_format_pos_tag(start_pos),
				_format_pos_tag(end_pos),
				mek.tiles_moved_last_turn,
			]
		),
	)

	source.position = end_pos
	game_map.collect_pickup_at(end_pos, source)
	return true
