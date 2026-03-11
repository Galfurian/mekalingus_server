class_name EnemySpawner
extends RefCounted

const MIN_SQUAD_SIZE: int = 1
const MAX_SQUAD_SIZE: int = 4
const MAX_SQUADS: int = 6


static func spawn_enemies_on_map(game_map, difficulty: int) -> void:
	var spawn_points = _find_valid_spawn_positions(game_map)
	if spawn_points.is_empty():
		push_error("No valid spawn points found.")
		return

	var squad_count = _get_enemy_squad_count(game_map, difficulty)
	var clans = DataManager.clans.values().duplicate()
	clans.shuffle()

	for i in range(min(squad_count, clans.size())):
		var clan: Clan = clans[i]
		if not clan:
			continue

		var avg_size = _get_squad_size(difficulty)
		var squad_size = randi_range(avg_size - 1, avg_size + 1)
		squad_size = clamp(squad_size, MIN_SQUAD_SIZE, MAX_SQUAD_SIZE)

		for _j in range(squad_size):
			if spawn_points.is_empty():
				push_error("Out of spawn points while spawning squad #%d" % i)
				return

			var role: Enums.MekRole = clan.preferred_roles.pick_random()
			var mek = LoadoutGenerator.generate_mek(difficulty, role)
			if not mek:
				push_error("Failed to generate Mek for clan %s" % clan.clan_name)
				continue

			var spawn_pos = spawn_points.pick_random()
			spawn_points.erase(spawn_pos)

			var npc_name := NameGenerator.random_full_name()
			game_map.npc_units[mek.uuid] = MapCombatEntity.new(spawn_pos, NPCOwned.new(npc_name, clan), mek)


static func _get_enemy_squad_count(game_map, difficulty: int) -> int:
	"""
	Returns the number of enemy squads based on difficulty and map size.
	"""
	var map_factor = (game_map.map_width * game_map.map_height) / ((game_map.map_width + game_map.map_height) * 3.0)
	var base_squads = 1 + int(((difficulty + 1) * 0.25) + map_factor)
	return clamp(base_squads, 1, MAX_SQUADS)


static func _get_squad_size(difficulty: int) -> int:
	"""
	Returns the size of each enemy squad based on difficulty.
	"""
	var base_size = MIN_SQUAD_SIZE + int((difficulty / 5.0) * (MAX_SQUAD_SIZE - MIN_SQUAD_SIZE))
	return clamp(base_size, MIN_SQUAD_SIZE, MAX_SQUAD_SIZE)


static func _find_valid_spawn_positions(game_map) -> Array[Vector2i]:
	"""
	Finds valid positions for spawning entities based on map walkability.
	"""
	var valid_positions: Array[Vector2i] = []
	for x in range(game_map.map_width):
		for y in range(game_map.map_height):
			var pos = Vector2i(x, y)
			if game_map.can_move_to(pos):
				valid_positions.append(pos)
	return valid_positions