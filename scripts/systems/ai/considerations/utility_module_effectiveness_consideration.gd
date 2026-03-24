class_name UtilityModuleEffectivenessConsideration
extends AIConsideration

const NORMALIZATION_SCALE: float = 120.0


func _init() -> void:
	consideration_name = "utility_module_effectiveness"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["item", "module", "source", "target"])


func get_normalized_input(context: Dictionary) -> float:
	var item: Item = context.get("item", null)
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	if not item or not module or not source or not target:
		return 0.0
	if _is_module_in_cooldown(source, item, module):
		return 0.0

	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if not _can_effect_apply_to_target(effect, source, target):
			continue
		total_power += effect.evaluate_effect_power(module.repeats)

	if total_power <= 0.0:
		return 0.0

	# Compute the score as a ratio of the total power to the normalization scale.
	var score = total_power / NORMALIZATION_SCALE

	# Normalize so that:
	# - 0.0 means no utility power (total_power = 0)
	# - 1.0 means maximum utility power (total_power >= NORMALIZATION_SCALE)
	var normalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Utility module effectiveness: %.2f (total power: %.2f, score: %.2f -> normalized: %.2f)"
	# 		% [normalized_score, total_power, score, normalized_score]
	# 	)
	# )

	return normalized_score


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


func _is_module_in_cooldown(source: MapCombatEntity, item: Item, module: ItemModule) -> bool:
	assert(source and source.combatant and item and module)
	if not source.combatant.cooldown_manager:
		return false
	return source.combatant.cooldown_manager.get_remaining_cooldown(item, module) > 0
