## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
class_name LocalForceSuperioritConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"

## Maximum expected force ratio for normalization (values > 2.0 will be clamped to 1.0).
const MAX_FORCE_RATIO: float = 2.0

const LOCAL_SCAN_RADIUS: int = 8

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
	var source: MapCombatEntity = context.get("source", null)

	if not planning_context or not source:
		return 0.0

	# Get force superiority ratio (enemy_power / source_power)
	# Result > 1.0 means enemies are stronger; < 1.0 means source is stronger
	var force_ratio: float = _get_local_force_superiority(source, planning_context)

	# Normalize so that:
	# - force_ratio 0.0 (no enemies) → input 0.0 (no pressure)
	# - force_ratio 1.0 (equal) → input 0.5 (moderate pressure)
	# - force_ratio 2.0+ (2x enemies) → input 1.0 (maximum pressure)
	return clampf(force_ratio / MAX_FORCE_RATIO, 0.0, 1.0)


## Evaluate local force superiority ratio (nearby_power / source_power).
## Returns value > 1.0 if enemies are locally superior, < 1.0 if source is superior.
static func _get_local_force_superiority(
	source: MapCombatEntity,
	context: AIPlanningContext,
) -> float:
	if not source or not source.combatant:
		return 0.0

	var source_power: float = CombatPowerEvaluator.evaluate(source.combatant)
	if source_power <= 0.0:
		return 1.0  # Avoid division by zero; treat zero-power as overwhelmed

	var nearby_enemy_power: float = _get_nearby_enemy_power(source, context)
	return nearby_enemy_power / source_power


## Get aggregated combat power of nearby enemies within LOCAL_SCAN_RADIUS,
## applying size-class scaling to each enemy.
static func _get_nearby_enemy_power(
	source: MapCombatEntity,
	context: AIPlanningContext,
) -> float:
	if not source or not context:
		return 0.0

	var total_power: float = 0.0
	var visible_enemies: Array = context.get_visible_enemies()

	for enemy in visible_enemies:
		if not enemy or not enemy.combatant:
			continue

		var distance: int = source.position.distance_to(enemy.position)
		if distance > LOCAL_SCAN_RADIUS:
			continue

		# Get enemy power and apply size-class scaling
		var enemy_power: float = CombatPowerEvaluator.evaluate(enemy.combatant)
		var scaled_power: float = _apply_size_scaling(enemy, enemy_power)
		total_power += scaled_power

	return total_power


## Apply unit-size scaling to combat power to prevent multiple light units
## from artificially inflating threat against a single large unit.
static func _apply_size_scaling(entity: MapCombatEntity, power: float) -> float:
	if not entity or not entity.combatant:
		return power

	# Try to get size from mek template
	var size: int = Enums.EntitySize.MEDIUM  # Default fallback
	if entity.combatant is Mek:
		var mek: Mek = entity.combatant as Mek
		if mek and mek.template:
			size = mek.template.size

	var scale_factor: float = SIZE_SCALE_FACTORS.get(size, 0.6)
	return power * scale_factor
