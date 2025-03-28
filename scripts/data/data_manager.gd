extends Node

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
	var dir = DirAccess.open(players_folder)
	if not dir or not dir.dir_exists(players_folder):
		# Create a new DirAccess instance.
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(players_folder)
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
	if player:
		# Build the file path.
		var file_path = players_folder + player.player_name + ".json"
		# Open the file.
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			GameServer.log_message("Failed to open player file: " + file_path)
			return false
		# Transform the player data to JSON.
		var json_data = JSON.stringify(player.to_dict())
		# Save the player to the file.
		if not file.store_string(json_data):
			GameServer.log_message("Failed to save player: " + file_path)
			return false
		# Close the file.
		file.close()
		GameServer.log_message("Saved player: " + file_path)
	return false


func load_player(player_name: String) -> bool:
	"""Loads a player from a file."""
	# Build the file path.
	var file_path = players_folder + player_name + ".json"
	# Check if the file exists.
	if not FileAccess.file_exists(file_path):
		GameServer.log_message("Player does not exist: " + file_path)
		return false
	# Open the file.
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		GameServer.log_message("Failed to open player file: " + file_path)
		return false
	# Parse the JSON data.
	var json_data = JSON.parse_string(file.get_as_text())
	# Close the file.
	file.close()
	# Check if the data is a Dictionary.
	if not json_data is Dictionary:
		GameServer.log_message("Failed to load non-Dictionary player: " + file_path)
		return false
	# Load the player from the data.
	var player = Player.new({})
	if not player.from_dict(json_data):
		GameServer.log_message("Failed to load player from data: " + file_path)
		return false
	# Add the player to the players dictionary.
	players[player.player_uuid] = player
	GameServer.log_message("    Loaded player: " + file_path)
	return true


func delete_player(player_name: String) -> bool:
	"""
	Deletes a player from disk and memory.
	"""
	# Build the file path.
	var file_path = players_folder + player_name + ".json"
	# Check if the file exists before deleting.
	if not FileAccess.file_exists(file_path):
		GameServer.log_message("Player does not exist: " + file_path)
		return false
	# Check that the player is currently loaded.
	var player = find_player_by_name(player_name)
	if not player:
		GameServer.log_message("Player not loaded: " + player_name)
		return false
	# Free up the UUID.
	GameServer.free_uuid(player.player_uuid)
	# Delete the player.
	players.erase(player.player_uuid)
	# Delete the file.
	if DirAccess.remove_absolute(file_path) != OK:
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
	# Try to open the players directory.
	var dir = DirAccess.open(players_folder)
	if not dir or not dir.dir_exists(players_folder):
		GameServer.log_message("No players folder found, skipping load.")
		return false
	GameServer.log_message("Loading players...")
	# Start listing the directory.
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		# Skip non-JSON files.
		if not file_name.ends_with(".json"):
			continue
		# Load the player.
		load_player(file_name.get_basename())
		# Move to the next file.
		file_name = dir.get_next()
	GameServer.log_message("Loaded " + str(players.size()) + " players.")
	return true


# =============================================================================
# CLAN
# =============================================================================


func initialize_clans():
	var dir = DirAccess.open(clans_folder)
	if not dir or not dir.dir_exists(clans_folder):
		# Create a new DirAccess instance.
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(clans_folder)
			GameServer.log_message("Created CLANS directory: " + clans_folder)
			TemplateManager.load_standard_clans()
			save_clans()


func save_clan(clan: Clan) -> bool:
	"""
	Saves a clan.
	"""
	if clan:
		# Build the file path.
		var file_path = clans_folder + clan.id + ".json"
		# Open the file.
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			GameServer.log_message("Failed to open clan file: " + file_path)
			return false
		# Transform the clan data to JSON.
		var json_data = JSON.stringify(clan.to_dict())
		# Save the clan to the file.
		if not file.store_string(json_data):
			GameServer.log_message("Failed to save clan: " + file_path)
			return false
		# Close the file.
		file.close()
		GameServer.log_message("Saved clan: " + file_path)
	return false


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
	if not FileAccess.file_exists(file_path):
		GameServer.log_message("No map exists: " + file_path)
		return false
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_string)
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
	# First, load the custom clans, which might replace default ones.
	var dir = DirAccess.open(clans_folder)
	if not dir or not dir.dir_exists(clans_folder):
		GameServer.log_message("No clans folder found, skipping load.")
		return false
	dir.list_dir_begin()
	GameServer.log_message("Loading clans...")
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			load_clan(clans_folder + file_name)
		file_name = dir.get_next()
	GameServer.log_message("Loaded " + str(clans.size()) + " clans.")
	return true


# =============================================================================
# MAP
# =============================================================================


func initilize_maps():
	"""
	Initializes the maps.
	"""
	var dir = DirAccess.open(maps_folder)
	if not dir or not dir.dir_exists(maps_folder):
		# Create a new DirAccess instance.
		dir = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(maps_folder)
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
	# Build the file path.
	var file_path = maps_folder + map.map_uuid + ".json"
	# Open the file.
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		GameServer.log_message("Failed to open map file: " + file_path)
		return false
	# Get the JSON data.
	var json_data = JSON.stringify(map.to_dict(), "    ")
	# Save the map to the file.
	file.store_string(json_data)
	# Close the file.
	file.close()
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
	# Remove map from memory if it was loaded.
	if map_uuid in maps:
		maps.erase(map_uuid)
	# Remove the file.
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		GameServer.log_message("Deleted map: " + file_path)
		return true
	GameServer.log_message("Failed to delete map: " + file_path)
	return false


func load_map(map_uuid: String) -> bool:
	"""Loads a saved game map from a JSON file."""
	var file_path = maps_folder + map_uuid + ".json"
	if not FileAccess.file_exists(file_path):
		GameServer.log_message("No map exists: " + file_path)
		return false
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_string)
	if not data:
		GameServer.log_message("Failed to load map : " + file_path)
		return false
	# Load the data into the Map instance.
	var map = GameMap.from_dict(data)
	maps[map.map_uuid] = map
	GameServer.log_message("    Loaded map: " + file_path)
	return true


func load_maps():
	"""Loads all maps from the maps directory."""
	var dir = DirAccess.open(maps_folder)
	if not dir or not dir.dir_exists(maps_folder):
		GameServer.log_message("No maps folder found, skipping load.")
		return false
	dir.list_dir_begin()
	GameServer.log_message("Loading maps...")
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			load_map(file_name.get_basename())
		file_name = dir.get_next()
	GameServer.log_message("Loaded " + str(maps.size()) + " maps.")
	return true
