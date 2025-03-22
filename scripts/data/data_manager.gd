extends Node

var GAME_FOLDER    = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/My Games/mekalingus/"
var PLAYERS_FOLDER = GAME_FOLDER + "players/"
var MAPS_FOLDER = GAME_FOLDER + "maps/"

# Stores players [Player.player_uuid -> player]
var players: Dictionary[String, Player] = {}
# Stores maps [Map.map_uuid -> Map]
var maps: Dictionary[String, GameMap] = {}

# =============================================================================
# GENERAL
# =============================================================================

func log_message(msg: String):
	GameServer.log_message(msg)

func _ready():
	# Ensure players directory exists and load all players.
	var dir = DirAccess.open(PLAYERS_FOLDER)
	if not dir or not dir.dir_exists(PLAYERS_FOLDER):
		# Create a new DirAccess instance.
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(PLAYERS_FOLDER)
			log_message("Created players directory: " + PLAYERS_FOLDER)
	# Ensure maps directory exists and load all maps.
	dir = DirAccess.open(MAPS_FOLDER)
	if not dir or not dir.dir_exists(MAPS_FOLDER):
		# Create a new DirAccess instance.
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(MAPS_FOLDER)
			log_message("Created MAPS directory: " + MAPS_FOLDER)

func clear_all():
	players.clear()

func save_all() -> bool:
	if not save_players():
		return false
	return true

func load_all() -> bool:
	if not load_players():
		return false
	if not load_maps():
		return false
	return true

# =============================================================================
# PLAYER
# =============================================================================

func find_player_by_uuid(player_uuid: String) -> Player:
	return players.get(player_uuid, null)

func find_player_by_name(player_name: String) -> Player:
	for player_uuid in players:
		var player = players[player_uuid]
		if player_name == player.player_name:
			return player
	return null

func create_player(player_name: String, player_uuid: String) -> Player:
	"""Creates a new default player player."""
	if find_player_by_name(player_name):
		log_message("Player with given name already exists.")
		return null
	if  find_player_by_uuid(player_uuid):
		log_message("Player with given player_uuid already exists.")
		return null
	var player = TemplateManager.player_template.build_player(player_name, player_uuid)
	players[player.player_uuid] = player
	return player

func save_player(player: Player) -> bool:
	"""Saves a player's player to a file."""
	if player:
		var file_path = PLAYERS_FOLDER + player.player_name + ".json"
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file.store_string(JSON.stringify(player.to_dict())):
			log_message("Saved player: " + file_path)
			return true
		log_message("Failed to save player: " + file_path)
	return false

func load_player(player_name: String) -> bool:
	"""Loads a player from a file."""
	var file_path = PLAYERS_FOLDER + player_name + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data is Dictionary:
			var player = Player.new({})
			if player.from_dict(json_data):
				players[player.player_uuid] = player
				log_message("    Loaded player: " + file_path)
				return true
			else:
				log_message("Failed to load player: " + file_path)
		else:
			log_message("Failed to load non-Dictionary player: " + file_path)
	return false

func delete_player(player_name: String) -> bool:
	"""Deletes a player from disk and memory."""
	var file_path = PLAYERS_FOLDER + player_name + ".json"
	# Check if the file exists before deleting
	if FileAccess.file_exists(file_path):
		log_message("Deleted player file: " + file_path)
		# Remove player from memory if it was loaded
		for player_uuid in players.keys():
			if players[player_uuid].player_name == player_name:
				# Free up the UUID.
				GameServer.free_uuid(player_uuid)
				# Delete the player.
				players.erase(player_uuid)
				log_message("Deleted player from memory: " + player_name)
				break
		var error = DirAccess.remove_absolute(file_path)
		if error != OK:
			log_message("Failed to delete player: " + file_path)
			return false
		return true
	log_message("Player does not exist: " + file_path)
	return false

func save_players() -> bool:
	for player_uuid in players.keys():
		save_player(players[player_uuid])
	return true
	
func load_players():
	"""Loads all players from the players directory."""
	var dir = DirAccess.open(PLAYERS_FOLDER)
	if not dir or not dir.dir_exists(PLAYERS_FOLDER):
		log_message("No players folder found, skipping load.")
		return false
	dir.list_dir_begin()
	log_message("Loading players...")
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			load_player(file_name.get_basename())
		file_name = dir.get_next()
	log_message("Loaded " + str(players.size()) + " players.")
	return true

# =============================================================================
# MAP
# =============================================================================

func add_map(map: GameMap) -> bool:
	"""Adds a map."""
	if map.map_uuid not in maps:
		maps[map.map_uuid] = map
		return true
	return false

func get_map(map_uuid: String) -> GameMap:
	"""Returns the map with the given map_uuid."""
	return maps.get(map_uuid, null)

func save_map(map: GameMap) -> bool:
	"""Saves the current game map to a JSON file."""
	var file_path = MAPS_FOLDER + map.map_uuid + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(map.to_dict(), "  "))
		file.close()
		log_message("Saved map: " + file_path)
		return true
	log_message("Failed to save map: " + file_path)
	return false
	
func delete_map(map_uuid: String) -> bool:
	"""Deletes the saved game map file."""
	var file_path = MAPS_FOLDER + map_uuid + ".json"
	# Remove map from memory if it was loaded.
	if map_uuid in maps:
		maps.erase(map_uuid)
	# Remove the file.
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		log_message("Deleted map: " + file_path)
		return true
	log_message("Failed to delete map: " + file_path)
	return false

func load_map(map_uuid: String) -> bool:
	"""Loads a saved game map from a JSON file."""
	var file_path = MAPS_FOLDER + map_uuid + ".json"
	if not FileAccess.file_exists(file_path):
		log_message("No map exists: " + file_path)
		return false
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_string)
	if not data:
		log_message("Failed to load map : " + file_path)
		return false
	# Load the data into the Map instance.
	var map = GameMap.from_dict(data)
	maps[map.map_uuid] = map
	log_message("    Loaded map: " + file_path)
	return true

func load_maps():
	"""Loads all maps from the maps directory."""
	var dir = DirAccess.open(MAPS_FOLDER)
	if not dir or not dir.dir_exists(MAPS_FOLDER):
		log_message("No maps folder found, skipping load.")
		return false
	dir.list_dir_begin()
	log_message("Loading maps...")
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			load_map(file_name.get_basename())
		file_name = dir.get_next()
	log_message("Loaded " + str(maps.size()) + " maps.")
	return true
