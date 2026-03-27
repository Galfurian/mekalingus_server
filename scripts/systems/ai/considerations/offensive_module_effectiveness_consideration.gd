class_name OffensiveModuleEffectivenessConsideration
extends AIConsideration

const NORMALIZATION_SCALE: float = 120.0


func _init() -> void:
	consideration_name = "offensive_module_effectiveness"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["item", "module", "source", "target"])


func get_normalized_input(context: Dictionary) -> float:
	var result: float = 0.0
	var item: Item = context.get("item", null)
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)

	var can_evaluate: bool = true

	if not item:
		push_error("Missing item for OffensiveModuleEffectivenessConsideration.")
		can_evaluate = false
	if not module:
		push_error("Missing module for OffensiveModuleEffectivenessConsideration.")
		can_evaluate = false
	if not source:
		push_error("Missing source for OffensiveModuleEffectivenessConsideration.")
		can_evaluate = false
	if not target:
		push_error("Missing target for OffensiveModuleEffectivenessConsideration.")
		can_evaluate = false
	if can_evaluate and source.owner == target.owner:
		can_evaluate = false
	if can_evaluate and _is_module_in_cooldown(source, item, module):
		can_evaluate = false

	if can_evaluate:
		# Calculate the average normalized offensive score across applicable effects.
		result = _get_offensive_module_total_power(module, target)
		result = clampf(result, 0.0, 1.0)

	return result


## Utility function to calculate the total power of a module's offensive effects without needing the
## full context, useful for testing or other evaluations.
func _get_offensive_module_total_power(module: ItemModule, target: MapCombatEntity) -> float:
	var total_score: float = 0.0
	var count: int = 0
	for effect: BaseEffect in module.effects:
		if not effect.is_offensive():
			continue

		var effect_score: float = effect.get_module_offensive_score(target)
		effect_score = clampf(effect_score, 0.0, 1.0)
		total_score += effect_score
		count += 1

	if count == 0:
		return 0.0

	return total_score / float(count)


func _is_module_in_cooldown(source: MapCombatEntity, item: Item, module: ItemModule) -> bool:
	assert(source and source.combatant and item and module)
	if not source.combatant.cooldown_manager:
		return false
	return source.combatant.cooldown_manager.get_remaining_cooldown(item, module) > 0
