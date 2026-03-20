## Evaluates the health status of an ally target for AI decision-making.

class_name TargetSurvivabilityConsideration
extends AIConsideration


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		push_error("Missing `target` entity in context.")
		return 0.0

	var max_survivability: float = AIUtils.get_entity_max_survivability(target)
	if max_survivability <= 0.0:
		push_error("Target has non-positive max survivability, cannot normalize health.")
		return 0.0

	var current_survivability: float = AIUtils.get_entity_current_survivability(target)
	if current_survivability < 0.0:
		push_error("Target has negative current survivability, cannot normalize health.")
		return 0.0
	return clampf(current_survivability / max_survivability, 0.0, 1.0)
