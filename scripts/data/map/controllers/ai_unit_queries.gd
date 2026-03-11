class_name AIUnitQueries
extends RefCounted


static func get_all_units(game_map: GameMap) -> Array[MapMek]:
	"""
	Returns all units in the game map.
	"""
	var units: Array[MapMek] = []
	for unit: MapMek in game_map.player_units.values():
		units.append(unit)
	for unit: MapMek in game_map.npc_units.values():
		units.append(unit)
	return units


static func get_units_in_range(
	game_map: GameMap,
	source: MapMek,
	position: Vector2i,
	radius: int,
	include_allies: bool = true,
	include_enemies: bool = true,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all units within the specified range of a position.
	"""
	var units_in_range: Array[MapMek] = []
	for entity in get_all_units(game_map):
		if entity == source:
			continue
		if entity in exclude_units:
			continue
		if position.distance_to(entity.position) > radius:
			continue
		if include_allies and not game_map.is_enemy_of(source, entity):
			units_in_range.append(entity)
		elif include_enemies and game_map.is_enemy_of(source, entity):
			units_in_range.append(entity)
	return units_in_range


static func get_enemies_in_range(
	game_map: GameMap,
	source: MapMek,
	radius: int,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all enemy units within a specified range of the source unit.
	"""
	return get_units_in_range(game_map, source, source.position, radius, false, true, exclude_units)


static func get_allies_in_range(
	game_map: GameMap,
	source: MapMek,
	radius: int,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all ally units within a specified range of the source unit.
	"""
	return get_units_in_range(game_map, source, source.position, radius, true, false, exclude_units)


static func get_most_vulnerable_enemy(
	game_map: GameMap,
	source: MapMek,
	max_distance: int
) -> MapMek:
	"""
	Returns the enemy with the lowest combined survivability ratio within range.
	"""
	var weakest: MapMek = null
	var lowest_score := INF

	for enemy in get_units_in_range(game_map, source, source.position, max_distance, false, true):
		var current_total = float(enemy.mek.health + enemy.mek.armor + enemy.mek.shield)
		var max_total = float(enemy.mek.max_health + enemy.mek.max_armor + enemy.mek.max_shield)
		if max_total <= 0:
			continue

		var ratio: float = current_total / max_total
		if ratio < lowest_score:
			lowest_score = ratio
			weakest = enemy

	return weakest