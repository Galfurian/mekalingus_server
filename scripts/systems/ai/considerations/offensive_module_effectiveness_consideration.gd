class_name OffensiveModuleEffectivenessConsideration
extends AIConsideration

const NORMALIZATION_SCALE: float = 120.0


func _init() -> void:
	consideration_name = "offensive_module_effectiveness"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["item", "module", "source", "target"])


func get_normalized_input(context: Dictionary) -> float:
	var item: Item = context.get("item", null)
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	if not item:
		push_error("Missing item for OffensiveModuleEffectivenessConsideration.")
		return 0.0
	if not module:
		push_error("Missing module for OffensiveModuleEffectivenessConsideration.")
		return 0.0
	if not source:
		push_error("Missing source for OffensiveModuleEffectivenessConsideration.")
		return 0.0
	if not target:
		push_error("Missing target for OffensiveModuleEffectivenessConsideration.")
		return 0.0
	if source.owner == target.owner:
		return 0.0
	if _is_module_in_cooldown(source, item, module):
		return 0.0
	# Calculate the total power of the module's offensive effects.
	var total_power: float = _get_offensive_module_total_power(module)

	# Compute the score as a ratio of the total power to the normalization scale.
	var score = total_power / NORMALIZATION_SCALE

	# Normalize so that:
	# - 0.0 means no offensive power (total_power = 0)
	# - 1.0 means maximum offensive power (total_power >= NORMALIZATION_SCALE)
	var normalized_score = clampf(score, 0.0, 1.0)

	# _add_thought(
	# 	source,
	# 	(
	# 		"Offensive module effectiveness: %.2f (total power: %.2f, score: %.2f -> normalized: %.2f)"
	# 		% [normalized_score, total_power, score, normalized_score]
	# 	)
	# )

	return normalized_score


## Utility function to calculate the total power of a module's offensive effects without needing the
## full context, useful for testing or other evaluations.
func _get_offensive_module_total_power(module: ItemModule) -> float:
	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if effect.is_offensive():
			total_power += effect.evaluate_effect_power(module.repeats)
	return total_power


func _is_module_in_cooldown(source: MapCombatEntity, item: Item, module: ItemModule) -> bool:
	assert(source and source.combatant and item and module)
	if not source.combatant.cooldown_manager:
		return false
	return source.combatant.cooldown_manager.get_remaining_cooldown(item, module) > 0
