extends Node

const PLAYER_TEMPLATE_FILE = "res://data/player_template.json"
const MEK_TEMPLATES_FOLDER   = "res://data/mek_templates"
const ITEM_TEMPLATES_FOLDER  = "res://data/item_templates"

# =============================================================================
# PROPERTIES
# =============================================================================

# The default player template.
var player_template: PlayerTemplate
# Stores all the mek templates.
var mek_templates: Dictionary
# Dictionary to store loaded item templates.
var item_templates: Dictionary

# =============================================================================
# GENERAL
# =============================================================================

func log_message(msg: String):
	GameServer.log_message(msg)

func load_all() -> bool:
	if not load_player_template():
		return false
	if not load_mek_templates():
		return false
	if not load_item_templates():
		return false
	return true
	
func clear_all():
	player_template.clear()
	mek_templates.clear()
	item_templates.clear()

# =============================================================================
# PLAYER
# =============================================================================

func load_player_template() -> bool:
	"""Loads the default player."""
	if not FileAccess.file_exists(PLAYER_TEMPLATE_FILE):
		log_message("Error: Player template file missing: " + PLAYER_TEMPLATE_FILE)
		return false
	var file = FileAccess.open(PLAYER_TEMPLATE_FILE, FileAccess.READ)
	if file:
		# Read the data.
		var player_data = JSON.parse_string(file.get_as_text())
		# Initialize the game data.
		player_template = PlayerTemplate.new(player_data)
		file.close()
		log_message("Loaded default player.")
		return true
	return false

# =============================================================================
# MEK
# =============================================================================

func load_mek_templates():
	"""Loads mek templates from multiple JSON files in the MEK_TEMPLATES_FOLDER."""
	if not DirAccess.dir_exists_absolute(MEK_TEMPLATES_FOLDER):
		log_message("Error: Mek templates folder missing: " + MEK_TEMPLATES_FOLDER)
		return false
	var dir = DirAccess.open(MEK_TEMPLATES_FOLDER)
	if not dir:
		log_message("Error: Failed to access mek templates folder.")
		return false
	log_message("Loading mek templates...")
	mek_templates.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var counter   = 0
			var file_path = MEK_TEMPLATES_FOLDER + "/" + file_name
			var file      = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				var data = JSON.parse_string(content)
				file.close()
				
				for mek_id in data:
					mek_templates[mek_id] = MekTemplate.new(mek_id, data[mek_id])
					counter += 1
			log_message("    Loaded " + str(counter) + " meks from \"" + file_path + "\".")
		file_name = dir.get_next()
	log_message("Loaded " + str(mek_templates.size()) + " meks.")
	return !mek_templates.is_empty()


func get_mek_template(mek_id:String) -> MekTemplate:
	return mek_templates.get(mek_id, null)

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
	while file_name != "":
		if file_name.ends_with(".json"):
			var counter   = 0
			var file_path = ITEM_TEMPLATES_FOLDER + "/" + file_name
			var file      = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				var data = JSON.parse_string(content)
				file.close()
				for item_id in data:
					item_templates[item_id] = ItemTemplate.new(item_id, data[item_id])
					counter += 1
			log_message("    Loaded " + str(counter) + " items from \"" + file_path + "\".")
		file_name = dir.get_next()
	log_message("Loaded " + str(item_templates.size()) + " items from multiple files.")
	return !item_templates.is_empty()


func get_item_template(item_id: String) -> ItemTemplate:
	"""Retrieves an item template by ID."""
	return item_templates.get(item_id, null)

# =============================================================================
# LOGGING
# =============================================================================
