class_name TileThreatConsideration
extends AIConsideration

const DEFAULT_MAX_THREAT: float = 100.0


func _init() -> void:
	consideration_name = "tile_threat"
	allowed_phases = PackedInt32Array(
		[
			AIEvaluationContext.Phase.INTENT,
			AIEvaluationContext.Phase.TILE,
			AIEvaluationContext.Phase.TARGET,
		]
	)
	required_keys = PackedStringArray(["planning_context", "source"])


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	var source: MapCombatEntity = context.get("source", null)
	if not planning_context or not source:
		return 0.0

	var tile: Vector2i = context.get("tile", source.position)
	var threat: float = planning_context.get_tile_threat_score(source, tile)

	if DEFAULT_MAX_THREAT <= 0.0:
		return 0.0

	# Compute the threat score as a ratio of the tile threat to a predefined maximum threat level.
	var score = threat / DEFAULT_MAX_THREAT

	# Normalize so that:
	# - 0.0 means no threat (threat = 0)
	# - 1.0 means maximum threat (threat >= DEFAULT_MAX_THREAT)
	var normalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(source, "Tile threat: %.2f (%.2f -> %.2f)" % [threat, score, normalized_score])

	return normalized_score
