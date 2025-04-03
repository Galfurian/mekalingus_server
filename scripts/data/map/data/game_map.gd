# This script contains the GameMap class, which represents a single game map.
# It stores terrain data, entities, and provides functions for pathfinding,
# entity management, and AI control.
class_name GameMap
extends Node

# Emits whenever a new log entry is added to the log.
signal on_log_added(log_entry: LogEntry)

# =============================================================================
# PROPERTIES
# =============================================================================

const DEFAULT_DETECTION_RANGE = 10

# =====================================
# STATIC INFORMATION
# =====================================

# Map unique identifier.
var map_uuid: String
# Map width.
var map_width: int
# Map height.
var map_height: int
# The map difficulty level.
var map_difficulty: int
# The type of game mode.
var combat_rules: CombatRules
# Map terrain data, an array of integers that identify the type of terrain.
var terrain_data: Array
# Map biome.
var map_biome: Biome

# =====================================
# DYNAMIC INFORMATION
# =====================================

# If true the map allows PVP.
var is_pvp_enabled: bool = false
# If true the map allows PVP.
var is_free_for_all_enabled: bool = true
# Stores all active NPC units by UUID.
var npc_units: Dictionary
# Stores all active Player units by UUID.
var player_units: Dictionary
# The combat log.
var combat_logs: Array[LogEntry]
# The chat log.
var chat_logs: Array[LogEntry]
# AStar2D graph.
var astar: AStar2D
# The current log indentation level.
var log_indent_level = 0
# The turn manager.
var turn_manager: TurnManager

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================


func _init(
	p_map_uuid: String,
	p_map_biome: Biome,
	p_map_width: int = 50,
	p_map_height: int = 50,
	p_map_difficulty: int = 0,
	p_game_mode: Enums.GameMode = Enums.GameMode.FFA
) -> void:
	map_uuid = p_map_uuid
	map_width = p_map_width
	map_height = p_map_height
	map_biome = p_map_biome
	map_difficulty = p_map_difficulty
	combat_rules = CombatRules.new(p_game_mode)
	# Instantiate the AStar2D graph.
	astar = AStar2D.new()
	# Instantiate the turn manager.
	turn_manager = TurnManager.new(self)


func _finalize():
	print("GameMap is being freed.")


func _exit_tree():
	print("GameMap is exiting the scene tree.")


func generate_map() -> void:
	"""Generates a new map with random terrain data."""
	# Instantiate the map generator.
	var map_generator = MapGenerator.new(map_width, map_height, map_biome)
	# Generate the terrain data.
	terrain_data = map_generator.generate(map_biome)
	# Update the AStar graph.
	update_astar()
	# Spawn enemies on the map.
	spawn_enemies_on_map(map_difficulty)


func clear() -> void:
	"""Clears the map data."""
	# Clear the map data.
	terrain_data.clear()
	# Clear the AStar graph.
	astar.clear()
	# Clear the entity lists.
	npc_units.clear()
	player_units.clear()
	# Clear the logs.
	combat_logs.clear()
	chat_logs.clear()
	# Clear the turn manager.
	turn_manager.clear()
	turn_manager.queue_free()


# =============================================================================
# TERRAIN FUNCTIONS
# =============================================================================


func _position_to_astar_id(pos: Vector2i) -> int:
	"""
	Converts a 2D position to a unique AStar2D ID using a row-major formula.
	"""
	return int(pos.y) * int(map_width) + int(pos.x)


func _astar_id_to_position(id: int) -> Vector2i:
	"""
	Converts an AStar2D ID back to its corresponding 2D tile position.
	"""
	var x: int = int(id % map_width)
	var y: int = int(id / float(map_width))
	return Vector2i(x, y)


func in_bounds(arg1, arg2 = null) -> bool:
	"""
	Checks if a given position is within the map bounds.
	"""
	if typeof(arg1) == TYPE_VECTOR2I:
		if arg1.x >= 0 and arg1.x < map_width and arg1.y >= 0 and arg1.y < map_height:
			return true
	elif typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
		if arg1 >= 0 and arg1 < map_width and arg2 >= 0 and arg2 < map_height:
			return true
	return false


func get_tile_id(arg1, arg2 = null) -> int:
	"""
	Returns the tile ID at the given position.
	"""
	if in_bounds(arg1, arg2):
		if typeof(arg1) == TYPE_VECTOR2I:
			return int(terrain_data[arg1.x][arg1.y])
		if typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
			return int(terrain_data[arg1][arg2])
	return -1


func get_tile_height(arg1, arg2 = null) -> int:
	"""
	Returns the height of the terrain at the given position.
	"""
	return map_biome.get_height(get_tile_id(arg1, arg2))


func get_tile_color(arg1, arg2 = null) -> Color:
	"""
	Returns the colors associated with the height map.
	"""
	return map_biome.get_color(get_tile_id(arg1, arg2))


func get_movement_cost(arg1, arg2 = null) -> int:
	"""
	Check if the height is walkable.
	"""
	return map_biome.get_movement_cost(get_tile_id(arg1, arg2))


func is_occupied(position: Vector2i) -> bool:
	"""
	Check if the place is occupied.
	"""
	return get_entity_at(position) != null


func is_walkable(position: Vector2i) -> bool:
	"""
	Check if the height is walkable.
	"""
	return get_movement_cost(position) >= 0


func can_move_to(position: Vector2i) -> bool:
	"""
	Check if the height is walkable.
	"""
	return is_walkable(position) and not is_occupied(position)


func get_tiles_in_range(position: Vector2i, max_range: int) -> Array[Vector2i]:
	"""
	Returns all tiles within a given range from a starting position.
	"""
	var visible: Array[Vector2i] = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var tile = position + Vector2i(dx, dy)
			if in_bounds(tile):
				if position.distance_to(tile) <= max_range:
					visible.append(tile)
	return visible


func update_astar() -> void:
	"""
	Rebuilds the AStar2D graph based on current walkable map tiles.
	"""
	astar.clear()
	# Step 1: Add all walkable tiles as AStar points.
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			# In terms of AStar we only focus on walkable tiles.
			if is_walkable(pos):
				# Add the point to the AStar graph.
				astar.add_point(_position_to_astar_id(pos), pos)
	# Step 2: Connect neighboring walkable tiles (4-directional).
	for y in range(map_height):
		for x in range(map_width):
			var current_pos = Vector2i(x, y)
			var current_id = _position_to_astar_id(current_pos)
			if not astar.has_point(current_id):
				continue
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor = current_pos + dir
				# Skip if out of bounds or not walkable
				if not in_bounds(neighbor):
					continue
				# Get the neighbor's AStar ID and check if it's a valid point.
				var neighbor_id = _position_to_astar_id(neighbor)
				if not astar.has_point(neighbor_id):
					continue
				# Connect the points if they are not already connected.
				if not astar.are_points_connected(current_id, neighbor_id):
					var cost = float(get_movement_cost(neighbor))
					astar.connect_points(current_id, neighbor_id)
					astar.set_point_weight_scale(neighbor_id, cost)


func get_shortest_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	"""
	Returns the shortest path between two tiles using AStar2D.
	"""
	# Get the AStar IDs for the start and end positions.
	var start_id = _position_to_astar_id(start)
	var end_id = _position_to_astar_id(end)
	# Check if the start and end points are valid.
	if not astar.has_point(start_id):
		GameServer.log_message("AStar does not have starting point %s, %d" % [str(start), start_id])
		return []
	if not astar.has_point(end_id):
		GameServer.log_message("AStar does not have ending point %s, %d" % [str(end), end_id])
		return []
	# Get the path from AStar.
	var path: PackedVector2Array = astar.get_point_path(start_id, end_id, true)
	# Convert the path to a regular array.
	var result: Array[Vector2i] = []
	for i in range(path.size()):
		result.append(Vector2i(path[i]))
	return result


func get_path_cost(path: PackedVector2Array) -> float:
	"""
	Compute the total cost of a path.
	"""
	var cost = 0.0
	for i in range(1, path.size()):
		cost += get_movement_cost(Vector2i(path[i]))
	return cost


func get_reachable_tiles(start: Vector2i, max_cost: int) -> Array[Vector2i]:
	"""
	Returns all reachable tiles from a starting position within a given cost.
	"""
	# Prepare the list of reachable tiles.
	var reachable: Array[Vector2i] = []
	# Get the AStar ID for the starting position.
	var start_id = _position_to_astar_id(start)
	# Check that the starting position is valid.
	if not astar.has_point(start_id):
		return reachable
	# Get all candidate tiles within the maximum cost + 2.
	var candidate_tiles = get_tiles_in_range(start, max_cost + 2)
	# Iterate over the candidate tiles.
	for tile in candidate_tiles:
		# Skip the starting tile.
		if tile != start:
			# Get the ID of the candidate tile.
			var id = _position_to_astar_id(tile)
			# Check that the candidate tile is valid.
			if astar.has_point(id):
				# Get the path to the candidate tile.
				var path = astar.get_point_path(start_id, id, true)
				# Check that the path is valid.
				if path.size() < 2:
					continue
				# Get the cost of the path.
				var cost = get_path_cost(path)
				# If the cost is within the maximum allowed, add the tile to the reachable list.
				if cost <= max_cost:
					reachable.append(tile)
	return reachable


# =============================================================================
# ENTITIES FUNCTIONS
# =============================================================================


func is_npc(entity: MapMek) -> bool:
	"""
	Returns true if the entity belongs to the npc_units dictionary (i.e., NPC).
	"""
	return npc_units.has(entity.mek.uuid)


func is_player(entity: MapMek) -> bool:
	"""
	Returns true if the entity belongs to the player_units dictionary (i.e., Player).
	"""
	return player_units.has(entity.mek.uuid)


func is_enemy_of(me1: MapMek, me2: MapMek) -> bool:
	"""
	Determines if two meks are enemies using CombatRules and clan-based ownership.
	"""
	if me1 == me2:
		return false
	if not me1.owner or not me2.owner:
		return false
	return combat_rules.can_attack(me1.owner, me2.owner)


func get_entity_at(position: Vector2i) -> MapEntity:
	"""Returns the entity in the given position."""
	if in_bounds(position):
		for entity in npc_units.values():
			if position == entity.position:
				return entity
		for entity in player_units.values():
			if position == entity.position:
				return entity
	return null


func get_units_in_range(
	source: MapMek,
	position: Vector2i,
	radius: int,
	include_allies: bool = true,
	include_enemies: bool = true,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all units within the specified range of a position.
	Parameters:
	- source: The unit doing the search (to determine ally/enemy).
	- position: The origin position for the search.
	- radius: The radius in tiles.
	- include_allies: Whether to include units on the same side as source.
	- include_enemies: Whether to include enemy units.
	- exclude_units: Optional list of units to ignore.
	"""
	var units_in_range: Array[MapMek] = []
	for entity in player_units.values() + npc_units.values():
		if entity == source:
			continue
		if entity in exclude_units:
			continue
		if position.distance_to(entity.position) > radius:
			continue
		if include_allies and not is_enemy_of(source, entity):
			units_in_range.append(entity)
		elif include_enemies and is_enemy_of(source, entity):
			units_in_range.append(entity)
	return units_in_range


func get_entity(uuid: String) -> MapMek:
	"""
	Returns the MapMek for a given UUID.
	"""
	if player_units.has(uuid):
		return player_units[uuid]
	if npc_units.has(uuid):
		return npc_units[uuid]
	return null


func remove_entity(uuid: String) -> MapMek:
	"""
	Removes an entity from the map and returns it.
	"""
	var entity = null
	if player_units.has(uuid):
		entity = player_units[uuid]
		player_units.erase(uuid)
	if npc_units.has(uuid):
		entity = npc_units[uuid]
		npc_units.erase(uuid)
	return entity


# =============================================================================
# LOGS
# =============================================================================


func increase_indent() -> void:
	log_indent_level += 1


func decrease_indent() -> void:
	log_indent_level = max(log_indent_level - 1, 0)


func get_indent() -> String:
	var indentation: String = ""
	for i in range(log_indent_level):
		indentation += "    "
	return indentation


func add_log(log_type: Enums.LogType, message: String, sender: String = "") -> void:
	var log_entry = LogEntry.new(log_type, get_indent() + message, sender)
	if log_type == Enums.LogType.CHAT:
		chat_logs.append(log_entry)
	else:
		combat_logs.append(log_entry)
	on_log_added.emit(log_entry)


func get_logs_by_type(log_type: Enums.LogType) -> Array[LogEntry]:
	if log_type == Enums.LogType.CHAT:
		return chat_logs
	return combat_logs.filter(func(log_entry): return log_entry.log_type == log_type)


# =============================================================================
# ENEMY SPAWNING
# =============================================================================


func _find_valid_spawn_positions() -> Array:
	"""Finds valid positions for spawning entities based on the height map."""
	var valid_positions = []
	for x in range(map_width):
		for y in range(map_height):
			var position = Vector2i(x, y)
			# Check if the height is walkable.
			if can_move_to(position):
				valid_positions.append(position)
	return valid_positions


func _get_enemy_count(difficulty: int) -> int:
	"""Determines the number of enemies to spawn based on difficulty and map size."""
	var base_count = 1 + int(((difficulty + 1) * (difficulty + 1)) / 3.0)
	var map_factor = (map_width * map_height) / ((map_width + map_height) * 3.0)
	return base_count + int(map_factor)


func spawn_enemies_on_map(difficulty: int) -> void:
	"""Places multiple enemies on the map based on difficulty level."""
	# Determine the number of enemies based on difficulty.
	var enemy_count = _get_enemy_count(difficulty)
	# Keep track of valid spawn locations on the map.
	var spawn_points = _find_valid_spawn_positions()
	# Spawn and place each enemy.
	for i in range(enemy_count):
		if spawn_points.is_empty():
			push_error("We ran out of spawn points.")
			return
		# Choose a random clan.
		var clan: Clan = DataManager.clans.values().pick_random()
		if not clan:
			push_error("Failed to pick a random clan.")
			return
		# Pick the role from the preferred roles of the clan.
		var role: Enums.MekRole = clan.preferred_roles.pick_random()
		# Generate the enemy.
		var mek = LoadoutGenerator.generate_mek(difficulty, role)
		if not mek:
			push_error("Failed to generate enemy.")
			return
		# Choose a random valid position.
		var spawn_point = spawn_points.pick_random()
		spawn_points.erase(spawn_point)
		# Place the enemy on the map.
		npc_units[mek.uuid] = MapMek.new(spawn_point, NPCOwned.new("Rookie", clan), mek)

# =============================================================================
# FORMATTING
# =============================================================================

static func format_item_tag(mek: Mek, item: Item, module: ItemModule) -> String:
	if not mek:
		return "<mek-null>"
	if not item:
		return "<item-null>"
	if not item:
		return "<module-null>"
	return "[url=item:%s:%s]%s[/url]" % [mek.uuid, item.uuid, module.module_name]


static func format_item_pair_tag(mek: Mek, item_module_pair: Dictionary) -> String:
	return format_item_tag(
		mek, item_module_pair.get("item", null), item_module_pair.get("module", null)
	)


static func format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# SAVE & LOAD
# =============================================================================


static func from_dict(data: Dictionary) -> GameMap:
	"""Loads map data from a dictionary."""
	if not data.has_all(["map_uuid", "map_biome", "map_difficulty"]):
		push_error("Invalid map data format!")
		return null
	if not data.has_all(["map_width", "map_height", "terrain_data"]):
		push_error("Invalid map data format!")
		return null
	# Get the map biome name.
	var biome_name = data["map_biome"]
	# Retrieve the actual biome.
	var biome = TemplateManager.get_biome(biome_name)
	if not biome:
		push_error("Invalid biome: " + biome_name)
		return null
	var map = GameMap.new(
		data["map_uuid"], biome, data["map_width"], data["map_height"], data["map_difficulty"]
	)
	map.terrain_data = Utils.deserialize_matrix(data["terrain_data"])
	map.npc_units = Utils.deserialize_dict_of_objects(
		data["npc_units"], func(mek_data): return MapMek.from_dict(mek_data)
	)
	map.combat_logs = LogEntry.decompress_logs_from_base64(data.get("combat_logs", {}))
	map.chat_logs = LogEntry.decompress_logs_from_base64(data.get("chat_logs", {}))

	# Update the AStar graph.
	map.update_astar()

	return map


func to_dict() -> Dictionary:
	"""Converts the map data into a dictionary for saving."""
	return {
		"map_uuid": map_uuid,
		"map_width": map_width,
		"map_height": map_height,
		"map_biome": map_biome.biome_name,
		"map_difficulty": map_difficulty,
		"terrain_data": Utils.serialize_matrix(terrain_data, map_width, map_height),
		"npc_units": Utils.serialize_dict_of_objects(npc_units),
		"combat_logs": LogEntry.compress_logs_to_base64(combat_logs),
		"chat_logs": LogEntry.compress_logs_to_base64(chat_logs)
	}
