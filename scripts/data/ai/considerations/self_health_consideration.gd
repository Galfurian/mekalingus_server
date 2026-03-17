class_name SelfHealthConsideration
extends "res://scripts/data/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var source: MapCombatEntity = context.get("source", null)
	if not source:
		return 0.0

	var max_survivability: float = float(
		source.combatant.max_health + source.combatant.max_armor + source.combatant.max_shield
	)
	if max_survivability <= 0.0:
		return 0.0

	var current_survivability: float = float(
		source.combatant.health + source.combatant.armor + source.combatant.shield
	)
	return clampf(current_survivability / max_survivability, 0.0, 1.0)