extends Node

const PLAYER_TEMPLATE_FILE = "res://data/player_template.json"
const MEK_TEMPLATES_FOLDER = "res://data/mek_templates"
const ITEM_TEMPLATES_FOLDER = "res://data/item_templates"
const BIOMES_FILE = "res://data/biomes.json"

# =============================================================================
# PROPERTIES
# =============================================================================

# The default player template.
var player_template: PlayerTemplate
# Stores all the mek templates.
var mek_templates: Dictionary
# Dictionary to store loaded item templates.
var item_templates: Dictionary
# List of biome data.
var biomes: Dictionary

# =============================================================================
# GENERAL
# =============================================================================


func log_message(msg: String):
	"""Logs a message to the game server."""
	GameServer.log_message(msg)


func load_all() -> bool:
	"""Loads all templates and data."""
	if not load_player_template():
		return false
	if not load_mek_templates():
		return false
	if not load_item_templates():
		return false
	if not load_biomes():
		return false
	return true


func clear_all():
	"""Clears all templates and data."""
	player_template.clear()
	mek_templates.clear()
	item_templates.clear()
	biomes.clear()


# =============================================================================
# GETTERS
# =============================================================================


func get_mek_template(mek_id: String) -> MekTemplate:
	"""Retrieves a mek template by ID."""
	return mek_templates.get(mek_id, null)


func get_item_template(item_id: String) -> ItemTemplate:
	"""Retrieves an item template by ID."""
	return item_templates.get(item_id, null)


func get_biome(biome: String) -> Dictionary:
	"""Returns the data for a biome."""
	return biomes.get(biome.to_lower(), null)


# =============================================================================
# PLAYER
# =============================================================================


func load_player_template() -> bool:
	"""Loads the default player."""
	if not FileAccess.file_exists(PLAYER_TEMPLATE_FILE):
		log_message("Error: Player template file missing: " + PLAYER_TEMPLATE_FILE)
		return false
	# Open the file.
	var file = FileAccess.open(PLAYER_TEMPLATE_FILE, FileAccess.READ)
	if not file:
		log_message("Error: Failed to open file '" + PLAYER_TEMPLATE_FILE + "'.")
		return false
	# Read the data.
	var data = JSON.parse_string(file.get_as_text())
	if not data:
		log_message("Failed to parse data file '" + PLAYER_TEMPLATE_FILE + "'.")
		return false
	# Initialize the game data.
	player_template = PlayerTemplate.new(data)
	# Now we can close the file.
	file.close()
	log_message("Loaded default player.")
	return true


# =============================================================================
# MEK
# =============================================================================


func load_mek_templates():
	"""Loads mek templates from multiple JSON files in the MEK_TEMPLATES_FOLDER."""
	if not DirAccess.dir_exists_absolute(MEK_TEMPLATES_FOLDER):
		log_message("Error: Mek templates folder missing: " + MEK_TEMPLATES_FOLDER)
		return false
	# Open the directory.
	var dir = DirAccess.open(MEK_TEMPLATES_FOLDER)
	if not dir:
		log_message("Error: Failed to access mek templates folder.")
		return false
	log_message("Loading mek templates...")
	# Clear the existing data.
	mek_templates.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".json"):
			continue
		var file_path = MEK_TEMPLATES_FOLDER + "/" + file_name
		# Open the file.
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			log_message("Error: Failed to open file '" + file_path + "'.")
			return false
		# Get the file content.
		var content = file.get_as_text()
		# Parse the data.
		var data = JSON.parse_string(content)
		if not data:
			log_message("Failed to parse data file '" + file_path + "'.")
			return false
		# Now we can close the file.
		file.close()
		# Load the data.
		var counter = 0
		for mek_id in data:
			mek_templates[mek_id] = MekTemplate.new(mek_id, data[mek_id])
			counter += 1
		log_message("    Loaded " + str(counter) + ' meks from "' + file_path + '".')
		# Move to the next file.
		file_name = dir.get_next()
	log_message("Loaded " + str(mek_templates.size()) + " meks.")
	return !mek_templates.is_empty()


# =============================================================================
# ITEM LOADING
# =============================================================================


func load_item_templates():
	"""Loads all item templates from multiple JSON files in ITEM_TEMPLATES_FOLDER."""
	if not DirAccess.dir_exists_absolute(ITEM_TEMPLATES_FOLDER):
		log_message("Error: Item templates folder missing: " + ITEM_TEMPLATES_FOLDER)
		return false
	var dir = DirAccess.open(ITEM_TEMPLATES_FOLDER)
	if not dir:
		log_message("Error: Unable to open item templates folder.")
		return false
	log_message("Loading item templates...")
	dir.list_dir_begin()
	item_templates.clear()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".json"):
			continue
		var file_path = ITEM_TEMPLATES_FOLDER + "/" + file_name
		# Open the file.
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			log_message("Error: Failed to open file '" + file_path + "'.")
			return false
		# Get the file content.
		var content = file.get_as_text()
		# Parse the data.
		var data = JSON.parse_string(content)
		if not data:
			log_message("Failed to parse data file '" + file_path + "'.")
			return false
		# Now we can close the file.
		file.close()
		# Load the data.
		var counter = 0
		for item_id in data:
			item_templates[item_id] = ItemTemplate.new(item_id, data[item_id])
			counter += 1
		log_message("    Loaded " + str(counter) + ' items from "' + file_path + '".')
		# Move to the next file.
		file_name = dir.get_next()
	log_message("Loaded " + str(item_templates.size()) + " items from multiple files.")
	return !item_templates.is_empty()


# =============================================================================
# BIOMES
# =============================================================================


func load_biomes() -> bool:
	"""Load biome data from a JSON file."""
	var file := FileAccess.open(BIOMES_FILE, FileAccess.READ)
	# Check if the file was opened.
	if not file:
		log_message("Error: Failed to open file '" + BIOMES_FILE + "'.")
		return false
	var counter = 0
	# Get the file content.
	var content = file.get_as_text()
	# Parse the data.
	var data = JSON.parse_string(content)
	# Check the data.
	if not data:
		log_message("Failed to parse data file '" + BIOMES_FILE + "'.")
		return false
	# Now we can close the file.
	file.close()
	# Load the data.
	for biome_name in data:
		biomes[biome_name.to_lower()] = data[biome_name]
		counter += 1
	log_message("    Loaded " + str(counter) + ' biomes from "' + BIOMES_FILE + '".')
	return true
