class_name UtilityModuleEffectivenessConsideration
extends AIConsideration


const NORMALIZATION_SCALE: float = 120.0


func _init() -> void:
	consideration_name = "utility_module_effectiveness"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["module", "source", "target"])


func get_normalized_input(context: Dictionary) -> float:
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	if not module or not source or not target:
		return 0.0

	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if not _can_effect_apply_to_target(effect, source, target):
			continue
		total_power += effect.evaluate_effect_power(module.repeats)

	if total_power <= 0.0:
		return 0.0

	return clampf(total_power / NORMALIZATION_SCALE, 0.0, 1.0)


func _can_effect_apply_to_target(
	effect: BaseEffect,
	source: MapCombatEntity,
	target: MapCombatEntity,
) -> bool:
	match effect.target:
		Enums.TargetType.SELF:
			return target == source
		Enums.TargetType.ALLY:
			return target.owner == source.owner and target != source
		Enums.TargetType.ENEMY:
			return target.owner != source.owner
		Enums.TargetType.AREA:
			return true
		_:
			return false