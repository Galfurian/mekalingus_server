# This script contains the GameMap class, which represents a single game map.
# It stores terrain data, entities, and provides functions for pathfinding,
# entity management, and AI control.
class_name GameMap
extends Node

# =====================================
# STATIC INFORMATION
# =====================================

# Map unique identifier.
var map_uuid: String
# Map width.
var map_width: int
# Map height.
var map_height: int
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
var npc_units: Dictionary
# Stores all active Player units by UUID.
var player_units: Dictionary
# Stores all structures on the map by UUID.
var structures: Dictionary
# Stores all pickups on the map by UUID.
var pickups: Dictionary
# The combat log.
var combat_logger: MapLogger = MapLogger.new()
# The chat log.
var chat_logger: MapLogger = MapLogger.new()
# AStar2D graph.
var astar: AStar2D = AStar2D.new()
# The AI controller for managing enemy actions.
var ai_controller
# The turn manager.
var turn_manager
# The directive planner.
var directive_planner
# Per-owner squad directives.
var owner_directives: Dictionary = {}

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================


func _init(
	p_map_uuid: String,
	p_map_biome: Biome,
	p_map_width: int = 50,
	p_map_height: int = 50,
	p_game_mode: Enums.GameMode = Enums.GameMode.FFA
) -> void:
	map_uuid = p_map_uuid
	map_width = p_map_width
	map_height = p_map_height
	map_biome = p_map_biome
	combat_rules.set_game_mode(p_game_mode)
	combat_logger.set_combat_preset()
	chat_logger.set_chat_preset()
	ai_controller = AIController.new(self)
	turn_manager = TurnManager.new(self)
	directive_planner = DirectivePlanner.new(self)


func generate_map() -> void:
	"""Generates a new map with random terrain data."""
	# Instantiate the map generator.
	var map_generator = MapGenerator.new(map_width, map_height, map_biome)
	# Generate the terrain data.
	terrain_data = map_generator.generate(map_biome)
	# Update the AStar graph.
	update_astar()


func clear() -> void:
	"""Clears the map data."""
	# Clear the map data.
	terrain_data.clear()
	# Clear the AStar graph.
	astar.clear()
	# Clear the entity lists.
	npc_units.clear()
	player_units.clear()
	structures.clear()
	pickups.clear()
	# Clear the logs.
	combat_logger.clear()
	chat_logger.clear()
	# Clear AI and turn systems.
	ai_controller.clear()
	turn_manager.clear()
	owner_directives.clear()


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
			return int(terrain_data[arg1.y][arg1.x])
		if typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
			return int(terrain_data[arg2][arg1])
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
	return get_blocking_entity_at(position) != null


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


func is_tile_blocked_for_pathfinding(position: Vector2i) -> bool:
	"""
	Returns true when a static blocking entity occupies the tile.
	"""
	if not is_in_bounds(position):
		return true

	for structure in structures.values():
		if structure and structure.active and structure.blocking and structure.position == position:
			return true

	for pickup in pickups.values():
		if pickup and pickup.active and pickup.blocking and pickup.position == position:
			return true

	return false


func update_astar() -> void:
	"""
	Rebuilds the AStar2D graph based on current walkable map tiles.
	"""
	MapAStarBuilder.rebuild(self)


# =============================================================================
# ENTITIES FUNCTIONS
# =============================================================================


func _filter_dead_unit(_key: String, unit: MapEntity) -> bool:
	"""
	Checks if the unit is dead.
	"""
	return unit.combatant.is_dead()


func is_npc(entity: MapEntity) -> bool:
	"""
	Returns true if the entity belongs to the npc_units dictionary (i.e., NPC).
	"""
	return npc_units.has(entity.combatant.uuid)


func is_player(entity: MapEntity) -> bool:
	"""
	Returns true if the entity belongs to the player_units dictionary (i.e., Player).
	"""
	return player_units.has(entity.combatant.uuid)


func is_enemy_of(me1: MapEntity, me2: MapEntity) -> bool:
	"""
	Determines if two meks are enemies using CombatRules and clan-based ownership.
	"""
	if me1 == me2:
		return false
	return can_owners_attack(me1.owner, me2.owner)


func can_owners_attack(owner1: EntityOwner, owner2: EntityOwner) -> bool:
	"""
	Determines if two owners are hostile under current combat rules.
	"""
	if not owner1 or not owner2:
		return false
	return combat_rules.can_attack(owner1, owner2)


func get_entity_at(position: Vector2i) -> MapEntity:
	"""Returns the entity in the given position."""
	if is_in_bounds(position):
		for entity in npc_units.values():
			if position == entity.position:
				return entity
		for entity in player_units.values():
			if position == entity.position:
				return entity
		for entity in structures.values():
			if entity and entity.active and position == entity.position:
				return entity
		for entity in pickups.values():
			if entity and entity.active and position == entity.position:
				return entity
	return null


func get_blocking_entity_at(position: Vector2i) -> MapEntity:
	"""Returns a movement-blocking entity at the given position, if any."""
	if not is_in_bounds(position):
		return null

	for entity in npc_units.values():
		if position == entity.position:
			return entity

	for entity in player_units.values():
		if position == entity.position:
			return entity

	for entity in structures.values():
		if entity and entity.active and entity.blocking and position == entity.position:
			return entity

	for entity in pickups.values():
		if entity and entity.active and entity.blocking and position == entity.position:
			return entity

	return null


func get_entity(uuid: String) -> MapEntity:
	"""
	Returns an entity for a given UUID key (or combat UUID for combat entities).
	"""
	if player_units.has(uuid):
		return player_units[uuid]
	if npc_units.has(uuid):
		return npc_units[uuid]
	if structures.has(uuid):
		return structures[uuid]
	if pickups.has(uuid):
		return pickups[uuid]

	for structure: MapStructure in structures.values():
		if structure and structure.combatant and structure.combatant.uuid == uuid:
			return structure

	return null


func collect_pickup_at(position: Vector2i, collector: MapEntity) -> MapPickup:
	"""
	Collects and removes an active pickup at the given position.
	Returns the collected pickup, or null if none was present.
	"""
	if not is_in_bounds(position) or not collector:
		return null

	for pickup_uuid in pickups.keys():
		var pickup: MapPickup = pickups[pickup_uuid]
		if not pickup or not pickup.active:
			continue
		if pickup.position != position:
			continue

		pickup.active = false
		pickups.erase(pickup_uuid)

		var item_label: String = "Unknown Item"
		if pickup.item_data.has("item_id"):
			item_label = str(pickup.item_data["item_id"])

		combat_logger.add_log(
			Enums.LogType.SYSTEM,
			"%s collected pickup: %s" % [collector.combatant.get_chat_tag(), item_label]
		)
		return pickup

	return null


func remove_entity(uuid: String) -> MapEntity:
	"""
	Removes an entity by UUID key (or combat UUID for structures) and returns it.
	"""
	var entity: MapEntity = null
	if player_units.has(uuid):
		entity = player_units[uuid]
		player_units.erase(uuid)
		return entity
	if npc_units.has(uuid):
		entity = npc_units[uuid]
		npc_units.erase(uuid)
		return entity
	if structures.has(uuid):
		entity = structures[uuid]
		structures.erase(uuid)
		return entity
	if pickups.has(uuid):
		entity = pickups[uuid]
		pickups.erase(uuid)
		return entity

	for structure_uuid in structures.keys():
		var structure: MapStructure = structures[structure_uuid]
		if structure and structure.combatant and structure.combatant.uuid == uuid:
			entity = structure
			structures.erase(structure_uuid)
			return entity

	for pickup_uuid in pickups.keys():
		var pickup: MapPickup = pickups[pickup_uuid]
		if pickup and str(pickup.item_data.get("uuid", "")) == uuid:
			entity = pickup
			pickups.erase(pickup_uuid)
			return entity

	return entity


func remove_map_entity(entity: MapEntity) -> bool:
	"""
	Removes an entity instance from the map collections.
	"""
	if not entity:
		return false

	for unit_uuid in player_units.keys():
		if player_units[unit_uuid] == entity:
			player_units.erase(unit_uuid)
			return true

	for unit_uuid in npc_units.keys():
		if npc_units[unit_uuid] == entity:
			npc_units.erase(unit_uuid)
			return true

	for structure_uuid in structures.keys():
		if structures[structure_uuid] == entity:
			structures.erase(structure_uuid)
			return true

	for pickup_uuid in pickups.keys():
		if pickups[pickup_uuid] == entity:
			pickups.erase(pickup_uuid)
			return true

	return false


func get_all_combat_entities() -> Array[MapCombatEntity]:
	var entities: Array[MapCombatEntity] = []
	for entity in npc_units.values():
		if entity and entity.combatant and entity.combatant.is_alive():
			entities.append(entity)
	for entity in player_units.values():
		if entity and entity.combatant and entity.combatant.is_alive():
			entities.append(entity)
	return entities


func has_hostile_pairs() -> bool:
	"""
	Returns true if at least one pair of living combat entities can attack each other.
	"""
	var alive_entities: Array[MapCombatEntity] = []
	for unit: MapCombatEntity in player_units.values():
		if unit and unit.combatant and unit.combatant.is_alive():
			alive_entities.append(unit)
	for unit: MapCombatEntity in npc_units.values():
		if unit and unit.combatant and unit.combatant.is_alive():
			alive_entities.append(unit)
	for structure: MapStructure in structures.values():
		if structure and structure.is_alive():
			alive_entities.append(structure)
	for i in range(alive_entities.size()):
		for j in range(i + 1, alive_entities.size()):
			if is_enemy_of(alive_entities[i], alive_entities[j]):
				return true
	return false


func remove_destroyed_units() -> void:
	"""
	Checks for destroyed units and removes them from the game map.
	"""
	# Erase the dead units from the game map.
	Utils.erase(player_units, Utils.filter(player_units, _filter_dead_unit))
	Utils.erase(npc_units, Utils.filter(npc_units, _filter_dead_unit))
	Utils.erase(structures, Utils.filter(structures, _filter_dead_unit))


func get_owner_key(p_owner: EntityOwner) -> String:
	if not p_owner:
		return ""
	if is_instance_of(p_owner, PlayerOwned):
		return "player:%s" % p_owner.player.player_uuid
	if is_instance_of(p_owner, NPCOwned):
		return "npc:%s|%s" % [p_owner.npc_name, p_owner.clan.id]
	return ""


func get_owner_label(p_owner: EntityOwner) -> String:
	if is_instance_of(p_owner, PlayerOwned):
		return "Player: %s" % p_owner.player.player_name
	if is_instance_of(p_owner, NPCOwned):
		return "NPC: %s" % p_owner.npc_name
	return "No Owner"


func get_owner_by_key(owner_key: String) -> EntityOwner:
	if owner_key.is_empty():
		return null

	for unit: MapCombatEntity in npc_units.values():
		if unit and unit.owner and get_owner_key(unit.owner) == owner_key:
			return unit.owner
	for unit: MapCombatEntity in player_units.values():
		if unit and unit.owner and get_owner_key(unit.owner) == owner_key:
			return unit.owner
	for structure: MapStructure in structures.values():
		if structure and structure.owner and get_owner_key(structure.owner) == owner_key:
			return structure.owner

	return null


func get_owner_label_by_key(owner_key: String) -> String:
	var found_owner: EntityOwner = get_owner_by_key(owner_key)
	if not found_owner:
		return owner_key
	return get_owner_label(found_owner)


func get_owner_keys(include_players: bool = true) -> Array[String]:
	var keys: Dictionary[String, bool] = {}
	for entity in npc_units.values():
		if not entity or not entity.owner:
			continue
		keys[get_owner_key(entity.owner)] = true
	for entity in structures.values():
		if not entity or not entity.owner:
			continue
		keys[get_owner_key(entity.owner)] = true
	if include_players:
		for entity in player_units.values():
			if not entity or not entity.owner:
				continue
			keys[get_owner_key(entity.owner)] = true

	var owner_keys: Array[String] = []
	for owner_key in keys.keys():
		if owner_key.is_empty():
			continue
		owner_keys.append(owner_key)
	owner_keys.sort()
	return owner_keys


func get_owned_combat_entities(p_owner: EntityOwner) -> Array[MapCombatEntity]:
	return get_owned_combat_entities_by_key(get_owner_key(p_owner))


func get_owned_combat_entities_by_key(owner_key: String) -> Array[MapCombatEntity]:
	var entities: Array[MapCombatEntity] = []
	if owner_key.is_empty():
		return entities

	for unit: MapCombatEntity in npc_units.values():
		if unit and unit.active and get_owner_key(unit.owner) == owner_key:
			entities.append(unit)
	for unit: MapCombatEntity in player_units.values():
		if unit and unit.active and get_owner_key(unit.owner) == owner_key:
			entities.append(unit)
	for structure: MapStructure in structures.values():
		if structure and structure.active and get_owner_key(structure.owner) == owner_key:
			entities.append(structure)

	return entities


# =============================================================================
# FORMATTING
# =============================================================================


static func format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


# =============================================================================
# SAVE & LOAD
# =============================================================================


static func from_dict(data: Dictionary) -> GameMap:
	"""Loads map data from a dictionary."""
	if not data.has_all(["map_uuid", "map_biome"]):
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
	var map = GameMap.new(data["map_uuid"], biome, data["map_width"], data["map_height"])

	# Load the map data.
	map.terrain_data = Utils.deserialize_matrix(data["terrain_data"])

	# Load the NPC units.
	map.npc_units.clear()
	for unit_uuid in data.get("npc_units", {}):
		var unit := MapMek.from_dict(data.get("npc_units", {})[unit_uuid]) as MapMek
		if unit:
			map.npc_units[unit.combatant.uuid] = unit
		else:
			push_error("Failed to load NPC unit data: %s" % unit_uuid)
			return null

	# Load the player units.
	map.player_units.clear()
	for unit_uuid in data.get("player_units", {}):
		var player_unit := MapMek.from_dict(data["player_units"][unit_uuid]) as MapMek
		if player_unit:
			map.player_units[player_unit.combatant.uuid] = player_unit
		else:
			push_error("Failed to load player unit data.")
			return null

	# Load the structures.
	map.structures.clear()
	for struct_uuid in data.get("structures", {}):
		var structure = MapStructure.from_dict(data.get("structures", {})[struct_uuid])
		if structure:
			map.structures[struct_uuid] = structure
		else:
			push_error("Failed to load structure data.")
			return null

	# Load the pickups.
	map.pickups.clear()
	for pickup_uuid in data.get("pickups", {}):
		var pickup = MapPickup.from_dict(data.get("pickups", {})[pickup_uuid])
		if pickup:
			map.pickups[pickup_uuid] = pickup
		else:
			push_error("Failed to load pickup data.")
			return null

	# Load the loggers.
	map.combat_logger = MapLogger.from_dict(data.get("combat_logger", {}))
	map.chat_logger = MapLogger.from_dict(data.get("chat_logger", {}))

	# Load squad directives.
	map.owner_directives.clear()
	for owner_key in data.get("owner_directives", {}):
		var directive_data: Dictionary = data["owner_directives"][owner_key]
		map.owner_directives[owner_key] = NpcDirectiveState.from_dict(directive_data)

	# Update the AStar graph.
	map.update_astar()

	return map


func to_dict() -> Dictionary:
	"""Converts the map data into a dictionary for saving."""
	var serialized_directives: Dictionary = {}
	for owner_key in owner_directives.keys():
		var state: RefCounted = owner_directives[owner_key]
		if state:
			serialized_directives[owner_key] = state.to_dict()

	return {
		"map_uuid": map_uuid,
		"map_width": map_width,
		"map_height": map_height,
		"map_biome": map_biome.biome_name,
		"terrain_data": Utils.serialize_matrix(terrain_data, map_width, map_height),
		"npc_units": Utils.serialize_dict_of_objects(npc_units),
		"player_units": Utils.serialize_dict_of_objects(player_units),
		"structures": Utils.serialize_dict_of_objects(structures),
		"pickups": Utils.serialize_dict_of_objects(pickups),
		"combat_logger": combat_logger.to_dict(),
		"chat_logger": chat_logger.to_dict(),
		"owner_directives": serialized_directives,
	}
