class_name AIThreatEvaluator
extends RefCounted


static func get_threat_level(game_map, tile: Vector2i, source: MapCombatEntity) -> float:
	"""
	Estimates how dangerous it would be to stand on this tile.
	"""
	var sensor_range: int = source.combatant.get_sensor_range()
	var enemies = AIUnitQueries.get_enemies_in_range(
		game_map, source, source.position, sensor_range
	)
	var modules_cache: Dictionary = {}
	for enemy: MapCombatEntity in enemies:
		modules_cache[enemy.combatant.uuid] = AIUtils.find_matching_modules(
			enemy.combatant, true, false, false
		)

	return get_threat_level_from_enemy_cache(tile, enemies, modules_cache)


static func get_threat_level_from_enemy_cache(
	tile: Vector2i,
	enemies: Array[MapCombatEntity],
	enemy_modules_cache: Dictionary,
) -> float:
	var threat_score := 0.0

	for enemy: MapCombatEntity in enemies:
		if not enemy or enemy.combatant.is_dead():
			continue

		var range_modifier: int = enemy.combatant.range_modifier
		var modules = enemy_modules_cache.get(enemy.combatant.uuid, [])
		for equipped_module: EquippedModule in modules:
			var module_range: int = equipped_module.module.module_range + range_modifier
			var distance: float = tile.distance_to(enemy.position)
			if distance < 0 or distance > module_range:
				continue

			threat_score += _score_module_threat(equipped_module.module)

	return threat_score


static func _score_module_threat(module: ItemModule) -> float:
	var score := 0.0
	for effect: BaseEffect in module.effects:
		score += effect.get_threat_score()
	return score


static func can_reach_target_this_turn(
	game_map,
	source: MapCombatEntity,
	target: MapCombatEntity,
	range_min: int,
	range_max: int,
	max_movement: int,
) -> bool:
	"""
	Determines if the source can reach a tile from which it can attack the target this turn.
	"""
	var reachable_tiles: Array[Vector2i] = AIPathfinder.get_reachable_tiles(
		game_map, source.position, max_movement
	)
	for tile: Vector2i in reachable_tiles:
		if game_map.is_occupied(tile):
			continue

		var distance: float = tile.distance_to(target.position)
		if distance >= range_min and distance <= range_max:
			return true
	return false
