## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
class_name LocalForceSuperioritConsideration
extends AIConsideration


const FORCE_RATIO_MAX: float = 2.0


func _init() -> void:
	consideration_name = "local_force_superiority"
	allowed_phases = PackedInt32Array(
		[
			AIEvaluationContext.Phase.INTENT,
			AIEvaluationContext.Phase.TILE,
		]
	)
	required_keys = PackedStringArray(["planning_context", "source", "tile"])


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	var source: MapCombatEntity = context.get("source", null)
	var tile: Vector2i = context.get("tile", Vector2i.ZERO)
	if not planning_context:
		push_error("Missing planning_context for LocalForceSuperioritConsideration.")
		return 0.0
	if not source:
		push_error("Missing source for LocalForceSuperioritConsideration.")
		return 0.0
	if tile == Vector2i.ZERO:
		tile = source.position

	# Get the source threat level.
	var source_threat: float = planning_context.get_unit_threat_score(source)
	# Get the nearby enemy combat power, scaled by unit size.
	var enemy_threat_level: float = planning_context.get_tile_threat_score(source, tile)
	if source_threat <= 0.0:
		return 0.0 if enemy_threat_level <= 0.0 else 1.0

	# Calculate and return the force superiority ratio (enemy_power / source_power).
	var force_ratio: float = enemy_threat_level / source_threat
	# Normalize so that:
	# - 0.0 means no nearby enemy threat (enemy_power = 0)
	# - 0.5 means equal power (enemy_power = source_power)
	# - 1.0 means enemy power is at least twice source power
	return clampf(force_ratio / FORCE_RATIO_MAX, 0.0, 1.0)
