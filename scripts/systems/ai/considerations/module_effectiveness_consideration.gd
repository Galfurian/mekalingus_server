class_name ModuleEffectivenessConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"


const NORMALIZATION_SCALE: float = 120.0


func get_normalized_input(context: Dictionary) -> float:
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	if not module or not source or not target:
		return 0.0
	if source.owner == target.owner:
		return 0.0

	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if effect.target != Enums.TargetType.ENEMY and effect.target != Enums.TargetType.AREA:
			continue
		total_power += effect.evaluate_effect_power(module.repeats)

	if total_power <= 0.0:
		return 0.0

	return clampf(total_power / NORMALIZATION_SCALE, 0.0, 1.0)
