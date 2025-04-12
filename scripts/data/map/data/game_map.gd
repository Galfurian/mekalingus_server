# This script contains the GameMap class, which represents a single game map.
# It stores terrain data, entities, and provides functions for pathfinding,
# entity management, and AI control.
class_name GameMap
extends Node

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
var combat_rules: CombatRules = CombatRules.new()
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
var npc_units: Dictionary[String, MapMek]
# Stores all active Player units by UUID.
var player_units: Dictionary[String, MapMek]
# The combat log.
var combat_logger: MapLogger = MapLogger.new()
# The chat log.
var chat_logger: MapLogger = MapLogger.new()
# AStar2D graph.
var astar: AStar2D = AStar2D.new()
# The AI controller for managing enemy actions.
var ai_controller: AIController = AIController.new(self)
# The turn manager.
var turn_manager: TurnManager = TurnManager.new(self)

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
	combat_rules.set_game_mode(p_game_mode)
	combat_logger.set_combat_preset()
	chat_logger.set_chat_preset()


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
	combat_logger.clear()
	chat_logger.clear()
	# Clear the turn manager.
	turn_manager.clear()


# =============================================================================
# TERRAIN FUNCTIONS
# =============================================================================


func position_to_astar_id(pos: Vector2i) -> int:
	"""
	Converts a 2D position to a unique AStar2D ID using a row-major formula.
	"""
	return int(pos.y) * int(map_width) + int(pos.x)


func astar_id_to_position(id: int) -> Vector2i:
	"""
	Converts an AStar2D ID back to its corresponding 2D tile position.
	"""
	var x: int = int(id % map_width)
	var y: int = int(id / float(map_width))
	return Vector2i(x, y)


func is_in_bounds(arg1, arg2 = null) -> bool:
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
	if is_in_bounds(arg1, arg2):
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
				astar.add_point(position_to_astar_id(pos), pos)
	# Step 2: Connect neighboring walkable tiles (4-directional).
	for y in range(map_height):
		for x in range(map_width):
			var current_pos = Vector2i(x, y)
			var current_id = position_to_astar_id(current_pos)
			if not astar.has_point(current_id):
				continue
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor = current_pos + dir
				# Skip if out of bounds or not walkable
				if not is_in_bounds(neighbor):
					continue
				# Get the neighbor's AStar ID and check if it's a valid point.
				var neighbor_id = position_to_astar_id(neighbor)
				if not astar.has_point(neighbor_id):
					continue
				# Connect the points if they are not already connected.
				if not astar.are_points_connected(current_id, neighbor_id):
					var cost = float(get_movement_cost(neighbor))
					astar.connect_points(current_id, neighbor_id)
					astar.set_point_weight_scale(neighbor_id, cost)


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
	if is_in_bounds(position):
		for entity in npc_units.values():
			if position == entity.position:
				return entity
		for entity in player_units.values():
			if position == entity.position:
				return entity
	return null


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
# ENEMY SPAWNING
# =============================================================================

const MIN_SQUAD_SIZE: int = 1
const MAX_SQUAD_SIZE: int = 4
const MAX_SQUADS: int = 6 # Upper limit per map


func _get_enemy_squad_count(difficulty: int) -> int:
	"""Returns the number of enemy squads based on difficulty and map size."""
	var map_factor = (map_width * map_height) / ((map_width + map_height) * 3.0)
	var base_squads = 1 + int(((difficulty + 1) * 0.75) + map_factor)
	return clamp(base_squads, 1, MAX_SQUADS)


func _find_valid_spawn_positions() -> Array[Vector2i]:
	"""Finds valid positions for spawning entities based on the height map."""
	var valid_positions: Array[Vector2i] = []
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			if can_move_to(pos):
				valid_positions.append(pos)
	return valid_positions


func spawn_enemies_on_map(difficulty: int) -> void:
	var spawn_points: Array[Vector2i] = _find_valid_spawn_positions()
	if spawn_points.is_empty():
		push_error("No valid spawn points found.")
		return

	var squad_count: int = _get_enemy_squad_count(difficulty)

	# Shuffle clans so we don’t end up with the same ones each time
	var clans = DataManager.clans.values().duplicate()
	clans.shuffle()

	for i in range(min(squad_count, clans.size())):
		var clan: Clan = clans[i]
		if not clan:
			continue

		var squad_size = randi_range(MIN_SQUAD_SIZE, MAX_SQUAD_SIZE)

		for j in range(squad_size):
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

			npc_units[mek.uuid] = MapMek.new(spawn_pos, NPCOwned.new("Squad_%d" % i, clan), mek)


# =============================================================================
# FORMATTING
# =============================================================================

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
	
	# Create the map instance.
	var map = GameMap.new(data["map_uuid"], biome, data["map_width"], data["map_height"], data["map_difficulty"])

	# Load the map data.
	map.terrain_data = Utils.deserialize_matrix(data["terrain_data"])
	
	# Load the NPC units.
	map.npc_units.clear()
	for unit_uuid in data["npc_units"]:
		var unit: MapMek = MapMek.from_dict(data["npc_units"][unit_uuid])
		if unit:
			map.npc_units[unit.mek.uuid] = unit
		else:
			push_error("Failed to load NPC unit data.")
			return null

	# Load the loggers.
	map.combat_logger = MapLogger.from_dict(data.get("combat_logger", {}))
	map.chat_logger = MapLogger.from_dict(data.get("chat_logger", {}))

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
		"combat_logger": combat_logger.to_dict(),
		"chat_logger": chat_logger.to_dict(),
	}
