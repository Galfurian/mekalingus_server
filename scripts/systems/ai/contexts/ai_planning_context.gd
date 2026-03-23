class_name AIPlanningContext
extends RefCounted

# ============================================================================
# DATA
# ============================================================================

# The turn context that holds shared data and caches for the entire turn.
var turn_context: AITurnContext
# The source unit for which the AI plan is being generated.
var source: MapCombatEntity

# ============================================================================
# PUBLIC METHODS
# ============================================================================


func _init(p_turn_context: AITurnContext, p_source: MapCombatEntity) -> void:
	assert(p_turn_context, "AIPlanningContext requires a valid AITurnContext reference.")
	assert(p_source, "AIPlanningContext requires a valid source unit.")
	turn_context = p_turn_context
	source = p_source


func clear() -> void:
	"""
	Clears the planning context's internal state and caches.
	"""
	source = null


func get_game_map() -> GameMap:
	"""
	Returns the GameMap instance from the turn context.
	"""
	return turn_context.game_map


func get_allies(
	include_self: bool = false,
	unit: MapCombatEntity = null,
	position: Vector2i = Vector2i(-1, -1),
) -> Array[MapCombatEntity]:
	"""
	Returns an array of allied MapCombatEntity instances within the game map.
	"""
	unit = unit if unit else source
	position = position if position != Vector2i(-1, -1) else source.position
	return turn_context.get_allies(unit, position, include_self)


func get_enemies(
	unit: MapCombatEntity = null, position: Vector2i = Vector2i(-1, -1)
) -> Array[MapCombatEntity]:
	"""
	Returns an array of enemy MapCombatEntity instances within the game map.
	"""
	unit = unit if unit else source
	position = position if position != Vector2i(-1, -1) else source.position
	return turn_context.get_enemies(unit, position)


func get_reachable_tiles(
	unit: MapCombatEntity = null, position: Vector2i = Vector2i(-1, -1)
) -> Array[Vector2i]:
	"""
	Returns an array of reachable tile positions (Vector2i) for the given unit and position.
	"""
	unit = unit if unit else source
	position = position if position != Vector2i(-1, -1) else source.position
	return turn_context.get_reachable_tiles(unit, position)


func get_squad_entities(
	unit: MapCombatEntity = null,
) -> Array[MapCombatEntity]:
	"""
	Returns an array of MapCombatEntity instances that belong to the same squad as the given unit.
	"""
	unit = unit if unit else source
	return turn_context.get_squad_entities(unit)


func get_squad_center(
	unit: MapCombatEntity = null,
) -> Vector2i:
	"""
	Returns the center position (Vector2i) of the squad that the given unit belongs to.
	"""
	unit = unit if unit else source
	return turn_context.get_squad_center(unit)


func has_line_of_sight(
	from_tile: Vector2i,
	to_tile: Vector2i,
) -> bool:
	"""
	Returns true if there is line of sight between the given tile positions, false otherwise.
	"""
	return turn_context.has_line_of_sight(from_tile, to_tile)


func get_path(
	start: Vector2i,
	end: Vector2i,
) -> Array[Vector2i]:
	"""
	Returns an array of tile positions (Vector2i) representing the path from start to end.
	"""
	return turn_context.get_path(start, end)


func get_tile_threat_score(
	unit: MapCombatEntity = null,
	position: Vector2i = Vector2i(-1, -1),
) -> float:
	"""
	Returns the threat score for the given tile position based on nearby enemies and their
	capabilities.
	"""
	unit = unit if unit else source
	position = position if position != Vector2i(-1, -1) else source.position
	return turn_context.get_tile_threat_score(unit, position)


func get_unit_threat_score(
	unit: MapCombatEntity = null,
) -> float:
	"""
	Returns the threat score for the given unit.
	"""
	unit = unit if unit else source
	return turn_context.get_unit_threat_score(unit)


func get_unit_offensive_modules(
	unit: MapCombatEntity = null,
) -> Array[EquippedModule]:
	"""
	Returns an array of offensive EquippedModule instances for the given unit.
	"""
	unit = unit if unit else source
	return turn_context.get_unit_offensive_modules(unit)


func get_unit_utility_modules(
	unit: MapCombatEntity = null,
) -> Array[EquippedModule]:
	"""
	Returns an array of utility EquippedModule instances for the given unit.
	"""
	unit = unit if unit else source
	return turn_context.get_unit_utility_modules(unit)
