class_name SelfHealthConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var source: MapCombatEntity = context.get("source", null)
	if not source:
		return 0.0

	var max_survivability: float = float(
		source.combatant.get_stat(Enums.StatType.MAX_HEALTH)
		+ source.combatant.get_stat(Enums.StatType.MAX_ARMOR)
		+ source.combatant.get_stat(Enums.StatType.MAX_SHIELD)
	)
	if max_survivability <= 0.0:
		return 0.0

	var current_survivability: float = float(
		source.combatant.get_stat(Enums.StatType.HEALTH)
		+ source.combatant.get_stat(Enums.StatType.ARMOR)
		+ source.combatant.get_stat(Enums.StatType.SHIELD)
	)
	return clampf(current_survivability / max_survivability, 0.0, 1.0)