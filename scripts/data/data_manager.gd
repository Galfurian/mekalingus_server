extends Node

const JsonStoreScript = preload("res://scripts/data/persistence/json_store.gd")

# =============================================================================
# DATA FOLDERS
# =============================================================================

# The folder where the game data is stored.
var game_folder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/My Games/mekalingus/"
# The folder where player data is stored.
var players_folder = game_folder + "players/"
# The folder where clans are stored.
var clans_folder = game_folder + "clans/"
# The folder where map data is stored.
var maps_folder = game_folder + "maps/"

# =============================================================================
# PROPERTIES
# =============================================================================

# Stores players [Player.player_uuid -> player]
var players: Dictionary[String, Player] = {}
# Stores clans [Clan.id -> Clan]
var clans: Dictionary[String, Clan] = {}
# Stores maps [Map.map_uuid -> Map]
var maps: Dictionary[String, GameMap] = {}

# =============================================================================
# GENERAL
# =============================================================================


func _ready():
	# Ensure players directory exists and load all players.
	initialize_players()
	# Ensure clans directory exists and load all clans.
	initialize_clans()
	# Ensure maps directory exists and load all maps.
	initilize_maps()


func clear_all():
	"""
	Clears all data.
	"""
	players.clear()
	clans.clear()
	maps.clear()


func save_all() -> bool:
	"""
	Saves all data.
	"""
	if not save_players():
		return false
	if not save_clans():
		return false
	if not save_maps():
		return false
	return true


func load_all() -> bool:
	"""
	Loads all data.
	"""
	if not load_players():
		return false
	if not load_clans():
		return false
	if not load_maps():
		return false
	return true


# =============================================================================
# PLAYER
# =============================================================================


func initialize_players():
	"""
	Initializes the players.
	"""
	if JsonStoreScript.ensure_directory(players_folder):
		GameServer.log_message("Created PLAYERS directory: " + players_folder)


func find_player_by_uuid(player_uuid: String) -> Player:
	"""
	Returns the player with the given player_uuid.
	"""
	return players.get(player_uuid, null)


func find_player_by_name(player_name: String) -> Player:
	"""
	Returns the player with the given player_name.
	"""
	for player_uuid in players:
		var player = players[player_uuid]
		if player_name == player.player_name:
			return player
	return null


func create_player(player_name: String, player_uuid: String) -> Player:
	"""
	Creates a new default player player.
	"""
	if find_player_by_name(player_name):
		GameServer.log_message("Player with given name already exists.")
		return null
	if find_player_by_uuid(player_uuid):
		GameServer.log_message("Player with given player_uuid already exists.")
		return null
	# Build the player.
	var player = TemplateManager.player_template.build_player(player_name, player_uuid)
	# Save the player.
	players[player.player_uuid] = player
	# Return the player.
	return player


func save_player(player: Player) -> bool:
	"""
	Saves a player's player to a file.
	"""
	if not player:
		return false

	var file_path = players_folder + player.player_name + ".json"
	if not JsonStoreScript.write_json_file(file_path, player.to_dict()):
		GameServer.log_message("Failed to save player: " + file_path)
		return false

	GameServer.log_message("Saved player: " + file_path)
	return true


func load_player(player_name: String) -> bool:
	"""Loads a player from a file."""
	var file_path = players_folder + player_name + ".json"
	var json_data = JsonStoreScript.read_json_file(file_path)
	if json_data == null:
		GameServer.log_message("Player does not exist: " + file_path)
		return false

	if not json_data is Dictionary:
		GameServer.log_message("Failed to load non-Dictionary player: " + file_path)
		return false

	var player = Player.new({})
	if not player.from_dict(json_data):
		GameServer.log_message("Failed to load player from data: " + file_path)
		return false

	players[player.player_uuid] = player
	GameServer.log_message("    Loaded player: " + file_path)
	return true


func delete_player(player_name: String) -> bool:
	"""
	Deletes a player from disk and memory.
	"""
	# Build the file path.
	var file_path = players_folder + player_name + ".json"
	if not FileAccess.file_exists(file_path):
		GameServer.log_message("Player does not exist: " + file_path)
		return false

	var player = find_player_by_name(player_name)
	if not player:
		GameServer.log_message("Player not loaded: " + player_name)
		return false

	GameServer.free_uuid(player.player_uuid)
	players.erase(player.player_uuid)
	if not JsonStoreScript.delete_file(file_path):
		GameServer.log_message("Failed to delete player: " + file_path)
		return false

	GameServer.log_message("Deleted player: " + file_path)
	return true


func save_players() -> bool:
	"""
	Saves all players to files.
	"""
	for player_uuid in players.keys():
		save_player(players[player_uuid])
	return true


func load_players():
	"""
	Loads all players from the players directory.
	"""
	var player_names = JsonStoreScript.list_json_basenames(players_folder)
	if player_names.is_empty() and not DirAccess.dir_exists_absolute(players_folder):
		GameServer.log_message("No players folder found, skipping load.")
		return false

	GameServer.log_message("Loading players...")
	for player_name in player_names:
		load_player(player_name)
	GameServer.log_message("Loaded " + str(players.size()) + " players.")
	return true


# =============================================================================
# CLAN
# =============================================================================


func initialize_clans():
	if JsonStoreScript.ensure_directory(clans_folder):
		GameServer.log_message("Created CLANS directory: " + clans_folder)
		TemplateManager.load_standard_clans()
		save_clans()


func save_clan(clan: Clan) -> bool:
	"""
	Saves a clan.
	"""
	if not clan:
		return false

	var file_path = clans_folder + clan.id + ".json"
	if not JsonStoreScript.write_json_file(file_path, clan.to_dict()):
		GameServer.log_message("Failed to save clan: " + file_path)
		return false

	GameServer.log_message("Saved clan: " + file_path)
	return true


func save_clans() -> bool:
	"""
	Saves all clans.
	"""
	for clan_id in clans.keys():
		save_clan(clans[clan_id])
	return true


func load_clan(file_path: String):
	"""
	Loads a clan.
	"""
	var data = JsonStoreScript.read_json_file(file_path)
	if data == null:
		GameServer.log_message("No map exists: " + file_path)
		return false
	if not data:
		GameServer.log_message("Failed to load map : " + file_path)
		return false
	var clan = Clan.from_dict(data)
	if not clan:
		GameServer.log_message("Failed to load clan from data.")
		return false
	if clan.id in clans:
		GameServer.log_message("Clan already exists: " + clan.id)
	else:
		clans[clan.id] = clan
	return true


func load_clans() -> bool:
	"""
	Loads the clans.
	"""
	var clan_names = JsonStoreScript.list_json_basenames(clans_folder)
	if clan_names.is_empty() and not DirAccess.dir_exists_absolute(clans_folder):
		GameServer.log_message("No clans folder found, skipping load.")
		return false

	GameServer.log_message("Loading clans...")
	for clan_name in clan_names:
		load_clan(clans_folder + clan_name + ".json")
	GameServer.log_message("Loaded " + str(clans.size()) + " clans.")
	return true


# =============================================================================
# MAP
# =============================================================================


func initilize_maps():
	"""
	Initializes the maps.
	"""
	if JsonStoreScript.ensure_directory(maps_folder):
		GameServer.log_message("Created MAPS directory: " + maps_folder)


func add_map(map: GameMap) -> bool:
	"""
	Adds a map.
	"""
	if map.map_uuid not in maps:
		maps[map.map_uuid] = map
		return true
	return false


func get_map(map_uuid: String) -> GameMap:
	"""
	Returns the map with the given map_uuid.
	"""
	return maps.get(map_uuid, null)


func save_map(map: GameMap) -> bool:
	"""Saves the current game map to a JSON file."""
	var file_path = maps_folder + map.map_uuid + ".json"
	if not JsonStoreScript.write_json_file(file_path, map.to_dict(), "    "):
		GameServer.log_message("Failed to open map file: " + file_path)
		return false

	GameServer.log_message("Saved map: " + file_path)
	return true


func save_maps() -> bool:
	"""
	Saves all maps to files.
	"""
	for map_uuid in maps.keys():
		save_map(maps[map_uuid])
	return true


func delete_map(map_uuid: String) -> bool:
	"""Deletes the saved game map file."""
	var file_path = maps_folder + map_uuid + ".json"
	if map_uuid in maps:
		maps.erase(map_uuid)
	if JsonStoreScript.delete_file(file_path):
		GameServer.log_message("Deleted map: " + file_path)
		return true

	GameServer.log_message("Failed to delete map: " + file_path)
	return false


func load_map(map_uuid: String) -> bool:
	"""Loads a saved game map from a JSON file."""
	var file_path = maps_folder + map_uuid + ".json"
	var data = JsonStoreScript.read_json_file(file_path)
	if data == null:
		GameServer.log_message("No map exists: " + file_path)
		return false
	if not data:
		GameServer.log_message("Failed to load map : " + file_path)
		return false

	var map = GameMap.from_dict(data)
	if not map:
		GameServer.log_message("Failed to load map from data: " + file_path)
		return false

	maps[map.map_uuid] = map
	GameServer.log_message("    Loaded map: " + file_path)
	return true


func reload_map(map_uuid: String) -> bool:
	"""Reloads a map from disk."""
	# Remove the map from memory.
	if map_uuid in maps:
		maps.erase(map_uuid)
	# Load the map from disk.
	if load_map(map_uuid):
		GameServer.log_message("Reloaded map: " + map_uuid)
		return true
	GameServer.log_message("Failed to reload map: " + map_uuid)
	return false


func load_maps():
	"""Loads all maps from the maps directory."""
	var map_uuids = JsonStoreScript.list_json_basenames(maps_folder)
	if map_uuids.is_empty() and not DirAccess.dir_exists_absolute(maps_folder):
		GameServer.log_message("No maps folder found, skipping load.")
		return false

	GameServer.log_message("Loading maps...")
	for map_uuid in map_uuids:
		load_map(map_uuid)
	GameServer.log_message("Loaded " + str(maps.size()) + " maps.")
	return true
