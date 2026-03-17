# This script defines the PlayerTemplate class, which is used to store the
# default Mek and Item templates assigned to new players.
class_name PlayerTemplate
extends Resource

# =============================================================================
# PROPERTIES
# =============================================================================

# Default Mek templates assigned to new players.
var meks: Array
# Default item templates assigned to new players.
var items: Array

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	"""
	Initializes the player template with provided data.
	"""
	if data:
		from_dict(data)


func clear():
	"""
	Clears the stored default Meks and Items.
	"""
	meks.clear()
	items.clear()


func build_player(player_name: String, player_uuid: String) -> Player:
	"""
	Creates a new Player instance with the default Meks and items.
	"""
	# Create a new player instance.
	var player = Player.new({})
	# Assign the player's name and UUID.
	player.player_name = player_name
	player.player_uuid = player_uuid
	# Assign the default Meks and items.
	for template_id in meks:
		# Create a new Mek instance with the template ID and a generated UUID.
		var mek = Mek.new({"mek_id": template_id, "uuid": GameServer.generate_uuid(), "items": {}})
		# Add the Mek to the player's Mek list.
		player.meks.append(mek)
	for template_id in items:
		# Create a new Item instance with the template ID and a generated UUID.
		var item = Item.new({"item_id": template_id, "uuid": GameServer.generate_uuid()})
		# Add the Item to the player's Item list.
		player.items.append(item)
	return player


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	"""
	Returns a string representation of the player template.
	"""
	return "PlayerTemplate: {meks: %s, items: %s}" % [meks, items]

func from_dict(data: Dictionary = {}) -> bool:
	"""
	Loads the default player configuration from a dictionary.
	"""
	if not data.has("meks") or not data.has("items"):
		GameServer.log_message("Invalid PlayerTemplate data: Missing required fields")
		return false
	# Load the default Meks and items.
	meks = data["meks"]
	items = data["items"]
	return true


func to_dict() -> Dictionary:
	"""
	Converts the player template to a dictionary.
	"""
	return {
		"meks": meks,
		"items": items,
	}
