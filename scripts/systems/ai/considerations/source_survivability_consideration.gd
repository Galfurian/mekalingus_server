class_name SourceSurvivabilityConsideration
extends AIConsideration


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

	# For retreat, a lower current survivability should increase urgency.
	# Source survivability = 0.0 (full health)
	# Source survivability = 1.0 (dead or no health)
	return clampf(1.0 - (current_survivability / max_survivability), 0.0, 1.0)
