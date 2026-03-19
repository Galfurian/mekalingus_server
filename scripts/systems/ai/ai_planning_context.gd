class_name AIPlanningContext
extends RefCounted

var source: MapCombatEntity
var game_map: GameMap
var turn_context: RefCounted = null


func _init(p_source: MapCombatEntity, p_game_map, p_turn_context: RefCounted = null) -> void:
	source = p_source
	game_map = p_game_map
	turn_context = p_turn_context


func get_enemies() -> Array[MapCombatEntity]:
	# Get the sensor range of the source unit.
	var sensor_range: int = source.combatant.get_sensor_range()
	# Return enemies within the sensor range using the turn context if available, otherwise fall back
	# to the game map.
	return turn_context.get_enemies(source, source.position, sensor_range)


func get_allies() -> Array[MapCombatEntity]:
	# Get the sensor range of the source unit.
	var sensor_range: int = source.combatant.get_sensor_range()
	# Return allies within the sensor range using the turn context if available, otherwise fall back
	# to the game map.
	return turn_context.get_allies(source, source.position, sensor_range)


func get_allies_with_self() -> Array[MapCombatEntity]:
	# Get the allies using the existing method and include the source unit itself in the returned
	# array.
	var allies: Array[MapCombatEntity] = get_allies()
	allies.append(source)
	return allies


func get_offensive_modules() -> Array[EquippedModule]:
	return AIUtils.find_matching_modules(source.combatant, true, false, false)


func get_utility_modules() -> Array[EquippedModule]:
	return AIUtils.find_matching_modules(source.combatant, false, false, false)


func get_reachable_tiles() -> Array[Vector2i]:
	return AIPathfinder.get_reachable_tiles(game_map, source.position, source.combatant.speed)


func get_squad_entities() -> Array[MapCombatEntity]:
	return game_map.get_owned_combat_entities(source.owner)


func get_squad_center(fallback: Vector2i) -> Vector2i:
	var entities: Array[MapCombatEntity] = get_squad_entities()
	if entities.is_empty():
		return fallback
	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y
	var squad_center: Vector2i = Vector2i(
		int(round(float(sum_x) / entities.size())),
		int(round(float(sum_y) / entities.size())),
	)
	return squad_center


func get_threat(tile: Vector2i) -> float:
	var enemy_modules_cache: Dictionary = {}
	var sensor_range: int = source.combatant.get_sensor_range()
	var enemies = AIUnitQueries.get_enemies_in_range(game_map, source, tile, sensor_range)
	for enemy: MapCombatEntity in enemies:
		enemy_modules_cache[enemy.combatant.uuid] = _get_enemy_offensive_modules(enemy)
	var threat_score: float = AIThreatEvaluator.get_threat_level_from_enemy_cache(
		tile, enemies, enemy_modules_cache
	)
	return threat_score


func _get_enemy_offensive_modules(enemy: MapCombatEntity) -> Array[EquippedModule]:
	return AIUtils.find_matching_modules(enemy.combatant, true, false, false)
