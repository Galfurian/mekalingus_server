## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
class_name LocalForceSuperioritConsideration
extends AIConsideration

## Maximum expected force ratio for normalization (values > 2.0 will be clamped to 1.0).
const MAX_FORCE_RATIO: float = 2.0

## Size scaling factors to balance unit class differences in force calculation.
## Prevents multiple light units from over-dominating against a single large unit.
const SIZE_SCALE_FACTORS: Dictionary = {
	Enums.EntitySize.LIGHT: 0.4,
	Enums.EntitySize.MEDIUM: 0.6,
	Enums.EntitySize.HEAVY: 0.8,
	Enums.EntitySize.COLOSSAL: 1.0,
}


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
		# Apply size scaling to balance the influence of different unit classes.
		var scaled_power: float = _get_size_scaling(enemy.combatant) * enemy_power
		# Accumulate scaled power into total enemy power.
		total_power += scaled_power
	return total_power


## Determines the appropriate scaling factor based on the [param entity]'s size class. This helps to
## balance the influence of different unit classes in the force superiority calculation, preventing
## multiple light units from overwhelming a single heavy unit.
static func _get_size_scaling(entity: CombatEntity) -> float:
	"""
	Returns the proper scaling factor for the given entity's size class.
	"""
	if entity is Mek:
		var mek: Mek = entity as Mek
		return SIZE_SCALE_FACTORS[mek.template.size]
	if entity is Structure:
		var structure: Structure = entity as Structure
		return SIZE_SCALE_FACTORS[structure.template.size]
	push_error("Unknown entity type for size scaling: " + str(entity))
	return 0.6
