class_name AIPathfinder
extends RefCounted


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
	var reachable: Array[Vector2i] = []
	var start_id = game_map.position_to_astar_id(start)
	if not game_map.astar.has_point(start_id):
		return reachable

	var candidate_tiles = get_tiles_in_range(game_map, start, max_cost + 2)
	for tile in candidate_tiles:
		if tile == start:
			continue

		var id = game_map.position_to_astar_id(tile)
		if not game_map.astar.has_point(id):
			continue

		var path = game_map.astar.get_point_path(start_id, id, true)
		if path.size() < 2:
			continue

		var cost = get_path_cost(game_map, path)
		if cost <= max_cost:
			reachable.append(tile)
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

	for tile in get_reachable_tiles(game_map, source.position, max_movement):
		if game_map.is_occupied(tile):
			continue

		var distance = tile.distance_to(target.position)
		if distance < min_range or distance > max_range:
			continue

		if distance < shortest_distance:
			best_tile = tile
			shortest_distance = distance

	if best_tile != Vector2i.ZERO:
		return best_tile

	return find_furthest_progress_along_path(game_map, source.position, target.position, max_movement)


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

	for tile in get_reachable_tiles(game_map, source.position, max_movement):
		if game_map.is_occupied(tile):
			continue

		var distance = tile.distance_to(target.position)
		if distance < min_range or distance > max_range:
			continue

		var move_cost = get_path_cost(game_map, get_shortest_path(game_map, source.position, tile))
		var height_difference = game_map.get_tile_height(tile) - game_map.get_tile_height(target.position)
		var ideal_range = float(max_range)
		var range_penalty = abs(distance - ideal_range)
		var score = -move_cost - range_penalty + height_difference * 2.0
		if score > best_score:
			best_score = score
			best_tile = tile

	if best_tile != Vector2i.ZERO:
		return best_tile

	return find_furthest_progress_along_path(game_map, source.position, target.position, max_movement)


static func find_random_reachable_tile(game_map, start: Vector2i, max_cost: int) -> Vector2i:
	"""
	Returns a random unoccupied reachable tile.
	"""
	var tiles = get_reachable_tiles(game_map, start, max_cost)
	var valid_tiles = tiles.filter(func(tile): return not game_map.is_occupied(tile))
	if valid_tiles.is_empty():
		return Vector2i.ZERO
	return valid_tiles.pick_random()