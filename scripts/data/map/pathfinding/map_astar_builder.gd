class_name MapAStarBuilder
extends RefCounted


static func rebuild(game_map: GameMap) -> void:
	"""
	Rebuilds the AStar2D graph based on current walkable map tiles.
	"""
	game_map.astar.clear()

	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			var pos = Vector2i(x, y)
			if game_map.is_walkable(pos) and not game_map.is_tile_blocked_for_pathfinding(pos):
				game_map.astar.add_point(game_map.position_to_astar_id(pos), pos)

	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			var current_pos = Vector2i(x, y)
			var current_id = game_map.position_to_astar_id(current_pos)
			if not game_map.astar.has_point(current_id):
				continue

			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor = current_pos + dir
				if not game_map.is_in_bounds(neighbor):
					continue

				var neighbor_id = game_map.position_to_astar_id(neighbor)
				if not game_map.astar.has_point(neighbor_id):
					continue

				if game_map.astar.are_points_connected(current_id, neighbor_id):
					continue

				var cost = float(game_map.get_movement_cost(neighbor))
				game_map.astar.connect_points(current_id, neighbor_id)
				game_map.astar.set_point_weight_scale(neighbor_id, cost)