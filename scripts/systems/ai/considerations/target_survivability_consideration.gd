## Evaluates the health status of an ally target for AI decision-making.

class_name TargetSurvivabilityConsideration
extends AIConsideration


func get_normalized_input(context: Dictionary) -> float:
	var target: MapCombatEntity = context.get("target", null)
	if not target:
		push_error("Missing `target` entity in context.")
		return 0.0

	var max_survivability: float = _get_entity_max_survivability(target)
	if max_survivability <= 0.0:
		push_error("Target has non-positive max survivability, cannot normalize health.")
		return 0.0

	var current_survivability: float = _get_entity_current_survivability(target)
	if current_survivability < 0.0:
		push_error("Target has negative current survivability, cannot normalize health.")
		return 0.0
	return clampf(current_survivability / max_survivability, 0.0, 1.0)


## Internal helper function to calculate the [param entity]'s maximum survivability for
## normalization. It sums the entity's max health, armor, and shield stats to determine the total
## survivability pool.
func _get_entity_max_survivability(entity: MapCombatEntity) -> float:
	var max_survivability: float = 0.0
	max_survivability += entity.combatant.get_stat(Enums.StatType.MAX_HEALTH)
	max_survivability += entity.combatant.get_stat(Enums.StatType.MAX_ARMOR)
	max_survivability += entity.combatant.get_stat(Enums.StatType.MAX_SHIELD)
	return max_survivability


## Internal helper function to calculate the [param entity]'s current survivability for
## normalization. It sums the entity's current health, armor, and shield stats to determine how much
## survivability they have left.
func _get_entity_current_survivability(entity: MapCombatEntity) -> float:
	var current_survivability: float = 0.0
	current_survivability += entity.combatant.get_stat(Enums.StatType.HEALTH)
	current_survivability += entity.combatant.get_stat(Enums.StatType.ARMOR)
	current_survivability += entity.combatant.get_stat(Enums.StatType.SHIELD)
	return current_survivability
