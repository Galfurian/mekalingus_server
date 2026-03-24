class_name SourceSurvivabilityConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "source_survivability"
	allowed_phases = PackedInt32Array(
		[
			AIEvaluationContext.Phase.INTENT,
			AIEvaluationContext.Phase.TILE,
			AIEvaluationContext.Phase.TARGET,
		]
	)
	required_keys = PackedStringArray(["source"])


func get_normalized_input(context: Dictionary) -> float:
	var source: MapCombatEntity = context.get("source", null)
	if not source:
		push_error("Missing source entity for SourceSurvivabilityConsideration.")
		return 0.0

	var max_survivability: float = AIUtils.get_entity_max_survivability(source)
	if max_survivability <= 0.0:
		push_error("source has non-positive max survivability, cannot normalize health.")
		return 0.0

	var current_survivability: float = AIUtils.get_entity_current_survivability(source)
	if current_survivability < 0.0:
		push_error("source has negative current survivability, cannot normalize health.")
		return 0.0

	# Compute the survivability score as a ratio of current to max survivability.
	var score = current_survivability / max_survivability

	# Normalize so that:
	# - 0.0 means no health (current_survivability = 0)
	# - 1.0 means full health (current_survivability = max_survivability)
	var normnalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Source survivability: %d/%d (%.2f -> %.2f)"
	# 		% [current_survivability, max_survivability, score, normnalized_score]
	# 	)
	# )

	return normnalized_score
