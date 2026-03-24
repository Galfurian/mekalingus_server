class_name TargetDistanceConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "target_distance"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["source", "target", "max_distance"])


func get_normalized_input(context: Dictionary) -> float:
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	var max_distance: float = float(context.get("max_distance", 1.0))
	if not source:
		push_error("Missing source entity for TargetDistanceConsideration.")
		return 0.0
	if not target:
		push_error("Missing target entity for TargetDistanceConsideration.")
		return 0.0
	if max_distance <= 0.0:
		return 0.0

	# Get the Manhattan distance between the source and target positions.
	var distance: float = _manhattan_distance(source.position, target.position)

	# Get the score as a ratio of the distance to the maximum distance, and clamp it to the range
	# [0, 1].
	var score = distance / max_distance

	# Normalize so that:
	# - 0.0 means the target is at the same position as the source (distance = 0)
	# - 1.0 means the target is at or beyond the maximum distance (distance >= max_distance)
	var normalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Target distance: %.2f (distance: %.2f, max_distance: %.2f, score: %.2f -> normalized: %.2f)"
	# 		% [distance, distance, max_distance, score, normalized_score]
	# 	)
	# )

	return normalized_score


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
