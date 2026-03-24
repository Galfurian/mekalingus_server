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

	# Compute direction away from enemy centroid
	var away_from_enemy: Vector2 = source_pos - enemy_centroid
	var tile_direction: Vector2 = tile_pos - enemy_centroid

	# Dot product: high when tile moves in direction away from enemies
	var dot_product: float = away_from_enemy.dot(tile_direction)

	# Compute the score as a ratio of the dot product to a normalization factor.
	var score: float = minf(1.0, maxf(0.0, dot_product / 1_000.0))

	# Normalize so that:
	# - 0.0 means tile is in the same direction as the enemy centroid (dot_product <= 0)
	# - 1.0 means tile is in the opposite direction from the enemy centroid (dot_product >= 1_000)
	var normalized_score = clampf(score, 0.0, 1.0)

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
