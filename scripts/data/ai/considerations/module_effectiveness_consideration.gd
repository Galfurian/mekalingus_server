class_name ModuleEffectivenessConsideration
extends "res://scripts/data/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var module = context.get("module", null)
	var target: MapCombatEntity = context.get("target", null)
	if not module or not target:
		return 0.0

	var score: float = AIUtils.score_offensive_module_on_target(module, target)
	var normalized: float = score / 100.0
	return clampf(normalized, 0.0, 1.0)
