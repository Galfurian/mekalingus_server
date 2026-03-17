class_name AllyHealthConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		return 0.0

	var max_survivability: float = float(
		target.combatant.get_stat(Enums.StatType.MAX_HEALTH)
		+ target.combatant.get_stat(Enums.StatType.MAX_ARMOR)
		+ target.combatant.get_stat(Enums.StatType.MAX_SHIELD)
	)
	if max_survivability <= 0.0:
		return 0.0

	var current_survivability: float = float(
		target.combatant.get_stat(Enums.StatType.HEALTH)
		+ target.combatant.get_stat(Enums.StatType.ARMOR)
		+ target.combatant.get_stat(Enums.StatType.SHIELD)
	)
	return clampf(current_survivability / max_survivability, 0.0, 1.0)