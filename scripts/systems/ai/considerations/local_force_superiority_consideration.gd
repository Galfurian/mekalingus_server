## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
class_name LocalForceSuperioritConsideration
extends AIConsideration

## Maximum expected force ratio for normalization (values > 2.0 will be clamped to 1.0).
const MAX_FORCE_RATIO: float = 2.0


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	if not planning_context:
		push_error("Missing `planning_context` in context.")
		return 0.0
	var source: MapCombatEntity = context.get("source", null)
	if not source:
		push_error("Missing `source` entity in context.")
		return 0.0

	# Get force superiority ratio (enemy_power / source_power)
	# Result > 1.0 means enemies are stronger; < 1.0 means source is stronger
	var force_ratio: float = _get_local_force_superiority(source, planning_context)

	# Normalize so that:
	# - force_ratio 0.0 (no enemies) → input 0.0 (no pressure)
	# - force_ratio 1.0 (equal) → input 0.5 (moderate pressure)
	# - force_ratio 2.0+ (2x enemies) → input 1.0 (maximum pressure)
	return clampf(force_ratio / MAX_FORCE_RATIO, 0.0, 1.0)


## Internal helper functions for force superiority calculation. It takes the [param source] entity
## and [param planning_context] to access visible enemies and their combat power.
static func _get_local_force_superiority(
	source: MapCombatEntity,
	planning_context: AIPlanningContext,
) -> float:
	# Compute source combat power using the CombatPowerEvaluator.
	var source_power: float = CombatPowerEvaluator.evaluate(source.combatant)
	# Compute total nearby enemy power, scaled by size class.
	var nearby_enemy_power: float = _get_nearby_enemy_power(planning_context)
	# Calculate and return the force superiority ratio (enemy_power / source_power).
	return nearby_enemy_power / source_power


## Calculates the total scaled combat power of visible enemies in the local area. Takes
## [planning_context] to access visible enemies and their combat power.
static func _get_nearby_enemy_power(planning_context: AIPlanningContext) -> float:
	var total_power: float = 0.0
	# Iterate the visible enemies and sum their scaled combat power.
	for enemy in planning_context.get_enemies():
		# Get enemy combat power using the CombatPowerEvaluator.
		var enemy_power: float = CombatPowerEvaluator.evaluate(enemy.combatant)
		# Get the size scaling factor for this enemy to balance unit class differences.
		var scaling_factor: float = AIForceScaling.get_entity_size_scale(enemy.combatant)
		# Accumulate scaled power into total enemy power.
		total_power += scaling_factor * enemy_power
	return total_power
