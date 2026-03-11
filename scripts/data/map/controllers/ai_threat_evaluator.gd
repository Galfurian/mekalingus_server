class_name AIThreatEvaluator
extends RefCounted

static func get_threat_level(game_map, tile: Vector2i, source: MapCombatEntity) -> float:
	"""
	Estimates how dangerous it would be to stand on this tile.
	"""
	var threat_score := 0.0
	for enemy in AIUnitQueries.get_enemies_in_range(game_map, source, 9999):
		var range_modifier = enemy.combatant.range_modifier
		for equipped_module in AIUtils.find_matching_modules(enemy.combatant, true, false, false):
			var module_range = equipped_module.module.module_range + range_modifier
			var distance = tile.distance_to(enemy.position)
			if distance < 0 or distance > module_range:
				continue

			for effect in equipped_module.module.effects:
				if effect.type == Enums.EffectType.DAMAGE:
					threat_score += float(effect.amount)
				elif effect.type == Enums.EffectType.DAMAGE_OVER_TIME:
					threat_score += float(effect.amount * effect.duration) * 0.5
				else:
					threat_score += 2.0
	return threat_score


static func can_reach_target_this_turn(
	game_map,
	source: MapCombatEntity,
	target: MapCombatEntity,
	range_min: int,
	range_max: int,
	max_movement: int
) -> bool:
	"""
	Determines if the source can reach a tile from which it can attack the target this turn.
	"""
	var reachable_tiles = AIPathfinder.get_reachable_tiles(game_map, source.position, max_movement)
	for tile in reachable_tiles:
		if game_map.is_occupied(tile):
			continue

		var distance = tile.distance_to(target.position)
		if distance >= range_min and distance <= range_max:
			return true
	return false