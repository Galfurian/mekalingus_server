extends Node

const PLAYER_TEMPLATE_FILE = "res://data/player_template.json"

const MEKS_FOLDER = "res://data/meks"
const ITEMS_FOLDER = "res://data/items"
const BIOMES_FOLDER = "res://data/biomes"

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
var biomes: Dictionary[String, Biome]
# Dictionary to store power stats per slot type.
var slot_power_stats: Dictionary[Enums.SlotType, Dictionary]
# Dictionary to store power stats per mek size.
var mek_power_stats: Dictionary[Enums.MekSize, Dictionary]

# =============================================================================
# GENERAL
# =============================================================================


func log_message(msg: String):
	"""
	Logs a message to the game server.
	"""
	GameServer.log_message(msg)


func load_all() -> bool:
	"""
	Loads all templates and data.
	"""
	if not load_player_template():
		return false
	if not load_mek_templates():
		return false
	if not load_item_templates():
		return false
	if not load_biomes():
		return false
	compute_item_power_stats_per_slot()
	compute_mek_power_stats_per_size()
	return true


func clear_all():
	"""
	Clears all templates and data.
	"""
	mek_power_stats.clear()
	slot_power_stats.clear()
	player_template.clear()
	mek_templates.clear()
	item_templates.clear()
	biomes.clear()


# =============================================================================
# GETTERS
# =============================================================================


func get_mek_template(mek_id: String) -> MekTemplate:
	"""
	Retrieves a mek template by ID.
	"""
	return mek_templates.get(mek_id, null)


func get_item_template(item_id: String) -> ItemTemplate:
	"""
	Retrieves an item template by ID.
	"""
	return item_templates.get(item_id, null)


func get_biome(biome_name: String) -> Biome:
	"""
	Returns the data for a biome.
	"""
	return biomes.get(biome_name.to_lower(), null)


# =============================================================================
# PLAYER
# =============================================================================


func load_player_template() -> bool:
	"""
	Loads the default player.
	"""
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


func compute_mek_power_stats_per_size() -> Dictionary:
	"""
	Computes power stats (min, max, avg) for each Mek size.
	"""
	mek_power_stats.clear()
	# Initialize grouping structure.
	var size_groups := {
		Enums.MekSize.LIGHT: [],
		Enums.MekSize.MEDIUM: [],
		Enums.MekSize.HEAVY: [],
		Enums.MekSize.COLOSSAL: []
	}
	# Gather power values by size.
	for mek_template in mek_templates.values():
		size_groups[mek_template.size].append(mek_template.evaluate_mek_template_power())
	# Compute stats per size group.
	for size_enum in size_groups.keys():
		var powers: Array = size_groups[size_enum]
		if powers.is_empty():
			continue
		var count: int = powers.size()
		var min_val: float = powers.min()
		var max_val: float = powers.max()
		var avg_val: float = powers.reduce(func(accum, val): return accum + val) / count
		mek_power_stats[size_enum] = {
			"count": count, "min": min_val, "max": max_val, "average": avg_val
		}
	return mek_power_stats


func load_mek_templates():
	"""
	Loads mek templates from multiple JSON files in the MEKS_FOLDER.
	"""
	if not DirAccess.dir_exists_absolute(MEKS_FOLDER):
		log_message("Error: Mek templates folder missing: " + MEKS_FOLDER)
		return false
	# Open the directory.
	var dir = DirAccess.open(MEKS_FOLDER)
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
		var file_path = MEKS_FOLDER + "/" + file_name
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


func compute_item_power_stats_per_slot():
	"""
	Computes power stats for each slot type.
	"""
	# Clear the previous stats.
	slot_power_stats.clear()
	# Dictionary to accumulate power values for each slot type (using enum as key)
	var slot_powers := {
		Enums.SlotType.SMALL: [],
		Enums.SlotType.MEDIUM: [],
		Enums.SlotType.LARGE: [],
		Enums.SlotType.UTILITY: []
	}
	# Gather powers grouped by slot type
	for item_template in item_templates.values():
		slot_powers[item_template.slot].append(item_template.evaluate_item_template_power())
	# Compute min, max, avg, count per slot enum value.
	for slot_enum in slot_powers.keys():
		var powers: Array = slot_powers[slot_enum]
		var count: int = powers.size()
		var min_val: float = powers.min()
		var max_val: float = powers.max()
		var avg_val: float = powers.reduce(func(accum, power): return accum + power) / count
		slot_power_stats[slot_enum] = {
			"count": count, "min": min_val, "max": max_val, "average": avg_val
		}
	return slot_power_stats


func load_item_templates():
	"""
	Loads all item templates from multiple JSON files in ITEMS_FOLDER.
	"""
	if not DirAccess.dir_exists_absolute(ITEMS_FOLDER):
		log_message("Error: Item templates folder missing: " + ITEMS_FOLDER)
		return false
	var dir = DirAccess.open(ITEMS_FOLDER)
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
		var file_path = ITEMS_FOLDER + "/" + file_name
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
	"""
	Load biome data from a JSON file.
	"""
	if not DirAccess.dir_exists_absolute(BIOMES_FOLDER):
		log_message("Error: Bioms folder missing: " + BIOMES_FOLDER)
		return false
	var dir = DirAccess.open(BIOMES_FOLDER)
	if not dir:
		log_message("Error: Unable to open biomes folder.")
		return false
	log_message("Loading biomes...")
	dir.list_dir_begin()
	biomes.clear()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(".json"):
			continue
		var file_path = BIOMES_FOLDER + "/" + file_name
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
		for biome_name in data:
			biomes[biome_name.to_lower()] = Biome.new(data[biome_name])
			counter += 1
		log_message("    Loaded " + str(counter) + ' biomes from "' + file_path + '".')
		# Move to the next file.
		file_name = dir.get_next()
	log_message("Loaded " + str(biomes.size()) + " biomes from multiple files.")
	return !biomes.is_empty()
