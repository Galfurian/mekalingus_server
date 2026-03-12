class_name AIPathfinder
extends RefCounted

static var _reserved_tiles: Dictionary = {}


static func set_reserved_tiles(reserved_tiles: Dictionary) -> void:
	_reserved_tiles = reserved_tiles


static func normalize_position(vector: Vector2i) -> Vector2:
	"""
	Returns a normalized Vector2 version of a Vector2i.
	"""
	var length = sqrt(vector.x * vector.x + vector.y * vector.y)
	if length == 0:
		return Vector2.ZERO
	return Vector2(vector.x / length, vector.y / length)


static func round_position(vector: Vector2) -> Vector2i:
	"""
	Returns a Vector2i with each component rounded to the nearest integer.
	"""
	return Vector2i(round(vector.x), round(vector.y))


static func get_shortest_path(game_map, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	"""
	Returns the shortest path between two tiles using AStar2D.
	"""
	var start_id = game_map.position_to_astar_id(start)
	var end_id = game_map.position_to_astar_id(end)

	if not game_map.astar.has_point(start_id):
		GameServer.log_message("AStar does not have starting point %s, %d" % [str(start), start_id])
		return []
	if not game_map.astar.has_point(end_id):
		GameServer.log_message("AStar does not have ending point %s, %d" % [str(end), end_id])
		return []

	var path: PackedVector2Array = game_map.astar.get_point_path(start_id, end_id, true)
	var result: Array[Vector2i] = []
	for point in path:
		result.append(Vector2i(point))
	return result


static func get_path_cost(game_map, path) -> float:
	"""
	Compute the total cost of a path.
	"""
	var cost := 0.0
	for i in range(1, path.size()):
		cost += game_map.get_movement_cost(Vector2i(path[i]))
	return cost


static func get_tiles_in_range(game_map, position: Vector2i, max_range: int) -> Array[Vector2i]:
	"""
	Returns all tiles within a given range from a starting position.
	"""
	var visible: Array[Vector2i] = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var tile = position + Vector2i(dx, dy)
			if game_map.is_in_bounds(tile) and position.distance_to(tile) <= max_range:
				visible.append(tile)
	return visible


static func get_reachable_tiles(game_map, start: Vector2i, max_cost: int) -> Array[Vector2i]:
	"""
	Returns all reachable tiles from a starting position within a given cost.
	"""
	var reachable_with_cost: Array[Dictionary] = get_reachable_tiles_with_cost(game_map, start, max_cost)
	var reachable: Array[Vector2i] = []
	for entry: Dictionary in reachable_with_cost:
		reachable.append(entry.tile)
	return reachable


static func get_reachable_tiles_with_cost(
	game_map,
	start: Vector2i,
	max_cost: int
) -> Array[Dictionary]:
	"""
	Returns reachable tiles with their path cost using a single frontier traversal.
	"""
	var reachable: Array[Dictionary] = []
	var start_id = game_map.position_to_astar_id(start)
	if not game_map.astar.has_point(start_id):
		return reachable

	var frontier: Array[Dictionary] = [{ "id": start_id, "cost": 0.0 }]
	var best_cost_by_id: Dictionary = { start_id: 0.0 }

	while not frontier.is_empty():
		var current_index: int = 0
		for i in range(1, frontier.size()):
			if frontier[i].cost < frontier[current_index].cost:
				current_index = i

		var current: Dictionary = frontier[current_index]
		frontier.remove_at(current_index)

		var current_id: int = current.id
		var current_cost: float = current.cost

		for neighbor_id in game_map.astar.get_point_connections(current_id):
			var neighbor_tile: Vector2i = _astar_id_to_tile(game_map, neighbor_id)
			var movement_cost: float = game_map.get_movement_cost(neighbor_tile)
			if movement_cost < 0:
				continue

			var next_cost: float = current_cost + movement_cost
			if next_cost > max_cost:
				continue

			if best_cost_by_id.has(neighbor_id) and best_cost_by_id[neighbor_id] <= next_cost:
				continue

			best_cost_by_id[neighbor_id] = next_cost
			frontier.append({ "id": neighbor_id, "cost": next_cost })

	for id in best_cost_by_id.keys():
		if id == start_id:
			continue
		reachable.append({
			"tile": _astar_id_to_tile(game_map, id),
			"cost": best_cost_by_id[id],
		})

	return reachable


static func get_distance(game_map, from: Vector2i, to: Vector2i) -> float:
	"""
	Returns the pathing distance between two tiles on the game map.
	"""
	var path = get_shortest_path(game_map, from, to)
	if path.is_empty():
		return INF
	return get_path_cost(game_map, path)


static func find_furthest_progress_along_path(
	game_map,
	start: Vector2i,
	target: Vector2i,
	max_movement: int
) -> Vector2i:
	"""
	Returns the farthest tile along the path toward the target that the unit
	can safely move to this turn.
	"""
	var path = get_shortest_path(game_map, start, target)
	if path.size() <= 1:
		return start

	var total_cost := 0.0
	var fallback_tile = start
	for i in range(1, path.size()):
		var tile = path[i]
		if game_map.is_occupied(tile):
			break
		if _is_reserved_tile(tile, start):
			break

		var cost = game_map.get_movement_cost(tile)
		if cost < 0 or total_cost + cost > max_movement:
			break

		total_cost += cost
		fallback_tile = tile
	return fallback_tile


static func find_closest_reachable_tile(
	game_map,
	source,
	target,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	var best_tile := Vector2i.ZERO
	var shortest_distance := INF

	for entry: Dictionary in get_reachable_tiles_with_cost(game_map, source.position, max_movement):
		var tile: Vector2i = entry.tile
		if game_map.is_occupied(tile):
			continue
		if _is_reserved_tile(tile, source.position):
			continue

		var distance = tile.distance_to(target.position)
		if distance < min_range or distance > max_range:
			continue

		if distance < shortest_distance:
			best_tile = tile
			shortest_distance = distance

	if best_tile != Vector2i.ZERO:
		return best_tile

	return find_furthest_progress_along_path(
		game_map,
		source.position,
		target.position,
		max_movement
	)


static func find_best_attack_tile(
	game_map,
	source,
	target,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	var best_tile := Vector2i.ZERO
	var best_score := -INF
	var ideal_range := maxf(float(min_range), float(max_range) - 0.5)
	var enemies: Array[MapCombatEntity] = AIUnitQueries.get_enemies_in_range(
		game_map,
		source,
		AITuning.get_global_scan_radius(game_map)
	)
	var allies: Array[MapCombatEntity] = AIUnitQueries.get_allies_in_range(
		game_map,
		source,
		AITuning.get_global_scan_radius(game_map)
	)
	var enemy_modules_cache: Dictionary = {}
	for enemy: MapCombatEntity in enemies:
		enemy_modules_cache[enemy.combatant.uuid] = AIUtils.find_matching_modules(
			enemy.combatant,
			true,
			false,
			false
		)

	for entry: Dictionary in get_reachable_tiles_with_cost(game_map, source.position, max_movement):
		var tile: Vector2i = entry.tile
		var move_cost: float = entry.cost
		if game_map.is_occupied(tile):
			continue
		if _is_reserved_tile(tile, source.position):
			continue

		var distance = tile.distance_to(target.position)
		if distance < min_range or distance > max_range:
			continue

		var height_difference = game_map.get_tile_height(tile) - game_map.get_tile_height(target.position)
		var range_penalty = abs(distance - ideal_range)
		var threat: float = AIThreatEvaluator.get_threat_level_from_enemy_cache(
			tile,
			enemies,
			enemy_modules_cache
		)
		var adjacent_enemies: int = _count_adjacent_entities(enemies, tile)
		var adjacent_allies: int = _count_adjacent_entities(allies, tile)
		var contact_penalty: float = 0.0
		if distance <= 1.1 and max_range > 1:
			contact_penalty = AITuning.ATTACK_CONTACT_PENALTY

		var score = 0.0
		score += -range_penalty * AITuning.ATTACK_RANGE_WEIGHT
		score += -move_cost * AITuning.ATTACK_MOVE_COST_WEIGHT
		score += height_difference * AITuning.ATTACK_HEIGHT_WEIGHT
		score += -threat * AITuning.ATTACK_THREAT_WEIGHT
		score += -float(adjacent_enemies) * AITuning.ATTACK_ADJACENT_ENEMY_WEIGHT
		score += -float(max(0, adjacent_allies - 1)) * AITuning.ATTACK_ADJACENT_ALLY_WEIGHT
		score += -contact_penalty
		if score > best_score:
			best_score = score
			best_tile = tile

	if best_tile != Vector2i.ZERO:
		return best_tile

	# No suitable standoff tile available this turn: hold position instead of facehugging.
	return source.position


static func find_random_reachable_tile(game_map, start: Vector2i, max_cost: int) -> Vector2i:
	"""
	Returns a random unoccupied reachable tile.
	"""
	var tiles = get_reachable_tiles(game_map, start, max_cost)
	var valid_tiles = tiles.filter(func(tile): return not game_map.is_occupied(tile))
	if valid_tiles.is_empty():
		return Vector2i.ZERO
	return valid_tiles.pick_random()


static func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]


static func _is_reserved_tile(tile: Vector2i, source_tile: Vector2i) -> bool:
	if _reserved_tiles.is_empty():
		return false
	if tile == source_tile:
		return false
	return _reserved_tiles.has(_tile_key(tile))


static func _count_adjacent_entities(entities: Array[MapCombatEntity], tile: Vector2i) -> int:
	var count: int = 0
	for entity: MapCombatEntity in entities:
		if entity and entity.active and entity.position.distance_to(tile) <= 1.5:
			count += 1
	return count


static func _astar_id_to_tile(game_map, astar_id: int) -> Vector2i:
	return Vector2i(game_map.astar.get_point_position(astar_id))
