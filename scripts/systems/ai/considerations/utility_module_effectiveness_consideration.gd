class_name UtilityModuleEffectivenessConsideration
extends AIConsideration

const NORMALIZATION_SCALE: float = 120.0
const MAX_EFFECT_PRIORITY: float = 16.0


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

	# Compute total power for this module’s effects, scaled by absolute utility priority.
	# This procedure is independent of other module options in the same item; it
	# estimates this module’s intrinsic usefulness for this target.
	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if not _can_effect_apply_to_target(effect, source, target):
			continue

		# Measure raw tool power and weight by contextual utility for this target.
		var raw_effect_power: float = effect.evaluate_effect_power(module.repeats)
		var effect_priority: int = effect.get_module_defensive_score(target)
		# Prefer clear utility signals over purely mechanical values.
		# Use 1.0 when no priority information is available.
		var effect_weight: float = 1.0
		if effect_priority > 0:
			effect_weight = clampf(float(effect_priority) / MAX_EFFECT_PRIORITY, 0.0, 1.0)
		# Slight soft minimum to avoid zeroing a valid effect that has no AI metadata.
		if effect_weight <= 0.0:
			effect_weight = 0.05
		total_power += raw_effect_power * effect_weight

	if total_power <= 0.0:
		return 0.0

	# Map total power into a bounded [0.0, 1.0] utility value in a smooth, diminishing return way.
	# This avoids linear saturation and keeps extreme values bounded without hard cutoffs.
	# Mathematically: logistic-like scaling using exponential decay.
	# - 0 power => 0.0
	# - ~NORMALIZATION_SCALE ~~ 0.63 (1 - e^-1)
	# - very high power ~~ 1.0
	var normalized_score: float = 1.0 - exp(-total_power / NORMALIZATION_SCALE)
	# Defend against potential numerical edge cases.
	normalized_score = clampf(normalized_score, 0.0, 1.0)

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
