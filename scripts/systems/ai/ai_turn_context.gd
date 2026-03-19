class_name AITurnContext
extends RefCounted

var game_map
var _offensive_modules_by_unit: Dictionary = {}


func _init(p_game_map) -> void:
	game_map = p_game_map


func get_enemies(
	source: MapCombatEntity,
	position: Vector2i,
	radius: int,
) -> Array[MapCombatEntity]:
	return AIUnitQueries.get_enemies_in_range(game_map, source, position, radius)


func get_allies(
	source: MapCombatEntity,
	position: Vector2i,
	radius: int,
) -> Array[MapCombatEntity]:
	return AIUnitQueries.get_allies_in_range(game_map, source, position, radius)


func get_offensive_modules_for(unit: MapCombatEntity) -> Array[EquippedModule]:
	if not unit or not unit.combatant:
		return []

	var unit_key: String = unit.combatant.uuid
	if _offensive_modules_by_unit.has(unit_key):
		return _offensive_modules_by_unit[unit_key]

	var modules: Array[EquippedModule] = AIUtils.find_matching_modules(
		unit.combatant, true, false, false
	)
	_offensive_modules_by_unit[unit_key] = modules
	return modules
