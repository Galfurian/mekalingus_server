class_name TargetHealthConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		return 0.0
	var target_max_health: int = target.combatant.get_stat(Enums.StatType.MAX_HEALTH)
	if target_max_health <= 0:
		return 0.0
	var target_health: int = target.combatant.get_stat(Enums.StatType.HEALTH)
	return float(target_health) / float(target_max_health)
