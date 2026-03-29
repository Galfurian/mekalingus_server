## Utility consideration for evaluating module effectiveness on an enemy target.
## Uses per-effect offensive/defensive module score (0..1) rather than a hardcoded constant scale.
## Output is the mean normalized score across applicable effects, in the range [0.0, 1.0].
class_name UtilityModuleEffectivenessConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "utility_module_effectiveness"
	allowed_phases = PackedInt32Array(
		[
			AIEvaluationContext.Phase.TARGET,
			AIEvaluationContext.Phase.MODULE,
		]
	)
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
	# Calculate the average normalized offensive/defensive score across applicable effects.
	var score: float = _get_utility_module_total_power(module, source, target)
	# Normalize the score to the range [0.0, 1.0] and return it.
	return clampf(score, 0.0, 1.0)


func _get_utility_module_total_power(
	module: ItemModule,
	source: MapCombatEntity,
	target: MapCombatEntity,
) -> float:
	var total_score: float = 0.0
	var effect_count: int = 0

	for effect: BaseEffect in module.effects:
		if not _can_effect_apply_to_target(effect, source, target):
			continue

		var effect_priority: float = 0.0
		if effect.is_offensive():
			effect_priority = effect.get_module_offensive_score(target)
		elif effect.is_defensive():
			effect_priority = effect.get_module_defensive_score(target)
		else:
			effect_priority = max(
				effect.get_module_offensive_score(target),
				effect.get_module_defensive_score(target),
			)

		effect_priority = clampf(effect_priority, 0.0, 1.0)

		total_score += effect_priority
		effect_count += 1

	if effect_count == 0:
		return 0.0

	return total_score / float(effect_count)


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
