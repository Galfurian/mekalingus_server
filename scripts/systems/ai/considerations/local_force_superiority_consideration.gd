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

	# Calculate force ratio (enemy_power / source_power).
	var force_ratio: float = enemy_threat_level / source_threat

	# Only count disadvantage as retreat pressure.
	# - <= 1.0 means parity or better, no pressure from force ratio.
	# - >= FORCE_RATIO_MAX maps to full pressure.
	if force_ratio <= 1.0:
		return 0.0

	# Normalize the disadvantage ratio to the range [0, 1] for scoring.
	var normalized_disadvantage: float = (force_ratio - 1.0) / (FORCE_RATIO_MAX - 1.0)

	# Clamp the normalized disadvantage to the range [0, 1] so that values above FORCE_RATIO_MAX are
	# treated as maximum disadvantage.
	var clamped_disadvantage = clampf(normalized_disadvantage, 0.0, 1.0)

	# Clamp to [0, 1] so that values above FORCE_RATIO_MAX are treated as maximum disadvantage.
	_add_thought(
		source,
		(
			"Local force superiority: %.2f (enemy threat: %.2f, source threat: %.2f, force ratio: %.2f -> %.2f -> %.2f)"
			% [
				clamped_disadvantage,
				enemy_threat_level,
				source_threat,
				force_ratio,
				normalized_disadvantage,
				clamped_disadvantage,
			]
		)
	)

	return clamped_disadvantage
