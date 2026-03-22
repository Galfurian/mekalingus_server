## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
class_name LocalForceSuperioritConsideration
extends AIConsideration


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	if not planning_context:
		push_error("Missing `planning_context` in context.")
		return 0.0
	# Get the source threat level.
	var source_threat: float = planning_context.get_unit_threat_score()
	# Get the nearby enemy combat power, scaled by unit size.
	var enemy_threat_level: float = planning_context.get_tile_threat_score()
	# Calculate and return the force superiority ratio (enemy_power / source_power).
	var force_ratio: float = enemy_threat_level / source_threat
	# Normalize so that:
	# - 0.0 means no nearby enemy threat (enemy_power = 0)
	# - 0.5 means equal power (enemy_power = source_power)
	# - 1.0 means enemy power is higher than source power (enemy_power >= source_power)
	return clampf(force_ratio, 0.0, 1.0)
