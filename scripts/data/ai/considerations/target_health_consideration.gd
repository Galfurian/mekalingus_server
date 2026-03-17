class_name TargetHealthConsideration
extends "res://scripts/data/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		return 0.0
	if target.combatant.max_health <= 0:
		return 0.0
	return float(target.combatant.health) / float(target.combatant.max_health)
