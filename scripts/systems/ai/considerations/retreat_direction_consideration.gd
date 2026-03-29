class_name RetreatDirectionConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "retreat_direction"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TILE])
	required_keys = PackedStringArray(["planning_context", "source", "tile"])


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context")
	if not planning_context:
		return 0.0

	var source: MapCombatEntity = context.get("source")
	if not source:
		return 0.0

	var tile: Vector2i = context.get("tile")
	if tile == Vector2i.ZERO:
		return 0.0

	var enemy_centroid: Vector2 = _get_known_enemy_centroid(source, planning_context)
	var source_pos: Vector2 = source.position
	var tile_pos: Vector2 = tile

	# Compute normalized directions away from the enemy centroid.
	var away_from_enemy: Vector2 = source_pos - enemy_centroid
	var tile_direction: Vector2 = tile_pos - enemy_centroid
	if away_from_enemy.length_squared() <= 0.0 or tile_direction.length_squared() <= 0.0:
		return 0.0
	away_from_enemy = away_from_enemy.normalized()
	tile_direction = tile_direction.normalized()

	# Dot product: 1.0 means aligned away from enemies, -1.0 means toward enemies.
	var dot_product: float = away_from_enemy.dot(tile_direction)

	# Map [-1.0, 1.0] to [0.0, 1.0].
	var normalized_score = clampf((dot_product + 1.0) / 2.0, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Retreat direction: %.2f (dot product: %.2f, score: %.2f -> normalized: %.2f)"
	# 		% [normalized_score, dot_product, score, normalized_score]
	# 	)
	# )

	return normalized_score


func _get_known_enemy_centroid(
	source: MapCombatEntity,
	planning_context: AIPlanningContext,
) -> Vector2:
	var enemies: Array[MapCombatEntity] = planning_context.get_enemies()

	if enemies.is_empty():
		# Fall back to last known centroid
		return source.combatant.last_enemy_centroid

	# Compute centroid of visible enemies
	var centroid: Vector2i = Vector2i.ZERO
	for enemy: MapCombatEntity in enemies:
		centroid += enemy.position
	centroid /= enemies.size()

	# Update persistent memory
	source.combatant.last_enemy_centroid = centroid

	return centroid
