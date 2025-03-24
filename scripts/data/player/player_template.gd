extends Resource

class_name PlayerTemplate

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
	"""Initializes the player template with provided data."""
	from_dict(data)

func clear():
	"""Clears the stored default Meks and Items."""
	meks.clear()
	items.clear()

func build_player(player_name: String, player_uuid: String) -> Player:
	"""Creates a new Player instance with the default Meks and items."""
	var player = Player.new({})
	player.player_name = player_name
	player.player_uuid = player_uuid
	
	for template_id in meks:
		player.meks.append(
			Mek.new({
				"mek_id": template_id,
				"uuid": GameServer.generate_uuid(),
				"items" : {}
			})
		)
	
	for template_id in items:
		player.items.append(Item.new({"item_id": template_id, "uuid": GameServer.generate_uuid()}))
	
	return player

# =============================================================================
# SERIALIZATION
# =============================================================================

func from_dict(data: Dictionary = {}) -> bool:
	"""Loads the default player configuration from a dictionary."""
	if not data.has("meks") or not data.has("items"):
		push_error("Invalid PlayerTemplate data: Missing required fields")
		return false
	
	meks = data["meks"]
	items = data["items"]
	
	return true

func to_dict() -> Dictionary:
	"""Converts the player template to a dictionary."""
	return {
		"meks": meks,
		"items": items,
	}
