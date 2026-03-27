## Evaluates the health status of an ally target for AI decision-making.

class_name TargetSurvivabilityConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "target_survivability"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["target"])


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		push_error("Missing target entity for TargetSurvivabilityConsideration.")
		return 0.0

	var max_survivability: float = AIUtils.get_entity_max_survivability(target)
	if max_survivability <= 0.0:
		push_error("Target has non-positive max survivability, cannot normalize health.")
		return 0.0

	var current_durability: float = (
		float(target.combatant.health)
		+ float(target.combatant.armor)
		+ float(target.combatant.shield)
	)
	if current_durability < 0.0:
		push_error("Target has negative current durability, cannot normalize health.")
		return 0.0

	# Compute the survivability score as a ratio of current durability to max survivability.
	var score = current_durability / max_survivability

	# Normalize so that:
	# - 0.0 means no health (current_survivability = 0)
	# - 1.0 means full health (current_survivability = max_survivability)
	var normnalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	target,
	# 	(
	# 		"Target survivability: %d/%d (%.2f -> %.2f)"
	# 		% [current_survivability, max_survivability, score, normnalized_score]
	# 	)
	# )

	return normnalized_score
