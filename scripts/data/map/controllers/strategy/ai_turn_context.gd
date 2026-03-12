class_name AITurnContext
extends RefCounted


var game_map
var _all_units: Array[MapCombatEntity] = []
var _range_query_cache: Dictionary = {}
var _offensive_modules_by_unit: Dictionary = {}


func _init(p_game_map) -> void:
	game_map = p_game_map
	_all_units = AIUnitQueries.get_all_units(game_map)


func get_visible_enemies(source: MapCombatEntity, radius: int) -> Array[MapCombatEntity]:
	return _query_units(source, radius, false, true)


func get_all_enemies(source: MapCombatEntity, radius: int) -> Array[MapCombatEntity]:
	return _query_units(source, radius, false, true)


func get_allies(source: MapCombatEntity, radius: int) -> Array[MapCombatEntity]:
	return _query_units(source, radius, true, false)


func get_offensive_modules_for(unit: MapCombatEntity) -> Array[EquippedModule]:
	if not unit or not unit.combatant:
		return []

	var unit_key: String = unit.combatant.uuid
	if _offensive_modules_by_unit.has(unit_key):
		return _offensive_modules_by_unit[unit_key]

	var modules: Array[EquippedModule] = AIUtils.find_matching_modules(
		unit.combatant,
		true,
		false,
		false
	)
	_offensive_modules_by_unit[unit_key] = modules
	return modules


func _query_units(
	source: MapCombatEntity,
	radius: int,
	include_allies: bool,
	include_enemies: bool
) -> Array[MapCombatEntity]:
	var cache_key: String = _query_key(source, radius, include_allies, include_enemies)
	if _range_query_cache.has(cache_key):
		return _range_query_cache[cache_key]

	var result: Array[MapCombatEntity] = []
	for entity: MapCombatEntity in _all_units:
		if entity == source:
			continue
		if source.position.distance_to(entity.position) > radius:
			continue
		if include_allies and not game_map.is_enemy_of(source, entity):
			result.append(entity)
		elif include_enemies and game_map.is_enemy_of(source, entity):
			result.append(entity)

	_range_query_cache[cache_key] = result
	return result


func _query_key(
	source: MapCombatEntity,
	radius: int,
	include_allies: bool,
	include_enemies: bool
) -> String:
	return "%s|%d|%s|%s" % [
		source.combatant.uuid,
		radius,
		str(include_allies),
		str(include_enemies),
	]
