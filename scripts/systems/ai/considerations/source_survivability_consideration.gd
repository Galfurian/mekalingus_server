## Evaluates the source entity’s durability to guide AI decisions for intent/tile/target phases.
## Returns a normalized survivability value in [0.0, 1.0], where 1.0 means full health.
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

	var max_durability: float = source.combatant.get_total_max_durability()
	if max_durability <= 0.0:
		push_error("source has non-positive max survivability, cannot normalize health.")
		return 0.0

	var current_durability: float = source.combatant.get_total_current_durability()
	if current_durability < 0.0:
		push_error("source has negative current durability, cannot normalize health.")
		return 0.0

	# Compute the survivability score as a ratio of current durability to max survivability.
	var score = current_durability / max_durability

	# Normalize so that:
	# - 0.0 means no health (current_survivability = 0)
	# - 1.0 means full health (current_survivability = max_durability)
	var normalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Source survivability: %d/%d (%.2f -> %.2f)"
	# 		% [current_survivability, max_durability, score, normalized_score]
	# 	)
	# )

	return normalized_score
