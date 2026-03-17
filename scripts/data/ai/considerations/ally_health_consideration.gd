class_name AllyHealthConsideration
extends "res://scripts/data/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		return 0.0

	var max_survivability: float = float(
		target.combatant.max_health + target.combatant.max_armor + target.combatant.max_shield
	)
	if max_survivability <= 0.0:
		return 0.0

	var current_survivability: float = float(
		target.combatant.health + target.combatant.armor + target.combatant.shield
	)
	return clampf(current_survivability / max_survivability, 0.0, 1.0)