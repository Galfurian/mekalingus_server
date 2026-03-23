class_name OffensiveModuleEffectivenessConsideration
extends AIConsideration

const NORMALIZATION_SCALE: float = 120.0


func _init() -> void:
	consideration_name = "offensive_module_effectiveness"
	allowed_phases = PackedInt32Array([AIEvaluationContext.Phase.TARGET])
	required_keys = PackedStringArray(["module", "source", "target"])


func get_normalized_input(context: Dictionary) -> float:
	var module: ItemModule = context.get("module", null)
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
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
	# Calculate the total power of the module's offensive effects.
	var total_power: float = _get_offensive_module_total_power(module)
	# Normalize the total power to a value between 0 and 1 based on the defined normalization scale.
	return clampf(total_power / NORMALIZATION_SCALE, 0.0, 1.0)


## Utility function to calculate the total power of a module's offensive effects without needing the
## full context, useful for testing or other evaluations.
func _get_offensive_module_total_power(module: ItemModule) -> float:
	var total_power: float = 0.0
	for effect: BaseEffect in module.effects:
		if effect.is_offensive():
			total_power += effect.evaluate_effect_power(module.repeats)
	return total_power
