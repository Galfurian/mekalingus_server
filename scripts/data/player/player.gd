# This script defines the Player class, which represents a player in the game.
# It contains the player's name, UUID, and collections of Mek and Item instances.
class_name Player
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# The player's name.
var player_name: String
# Unique identifier for the player.
var player_uuid: String
# List of owned Mek instances.
var meks: Array[Mek]
# List of owned item instances.
var items: Array[Item]

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	"""
	Initializes a Player instance from a dictionary.
	"""
	if !data.is_empty():
		from_dict(data)


# =============================================================================
# MEKS
# =============================================================================


func add_mek(mek: Mek):
	"""
	Adds a Mek to the player's collection.
	"""
	meks.append(mek)
	meks.sort_custom(Mek.compare_meks)


func remove_mek(mek: Mek) -> bool:
	"""
	Removes a Mek from the player's collection.
	"""
	if mek in meks:
		meks.erase(mek)
		meks.sort_custom(Mek.compare_meks)
		return true
	return false


func remove_mek_by_uuid(uuid: String) -> bool:
	"""
	Removes a Mek from the player's collection by UUID.
	"""
	for mek in meks:
		if mek.uuid == uuid:
			meks.erase(mek)
			meks.sort_custom(Mek.compare_meks)
			return true
	return false


func get_mek(uuid: String) -> Mek:
	"""
	Retrieves a Mek by its UUID.
	"""
	for mek in meks:
		if mek.uuid == uuid:
			return mek
	return null


# =============================================================================
# ITEMS
# =============================================================================


func add_item(item: Item) -> bool:
	"""
	Adds an item to the player's inventory.
	"""
	items.append(item)
	items.sort_custom(Item.compare_items)
	return true


func remove_item(item: Item) -> bool:
	"""
	Removes an item from the player's inventory.
	"""
	if item in items:
		items.erase(item)
		items.sort_custom(Item.compare_items)
		return true
	return false


func remove_item_by_uuid(uuid: String) -> bool:
	"""
	Removes an item from the player's inventory by UUID.
	"""
	for item in items:
		if item.uuid == uuid:
			items.erase(item)
			items.sort_custom(Item.compare_items)
			return true
	return false


func get_item(uuid: String) -> Item:
	"""
	Retrieves an item by its UUID.
	"""
	for item in items:
		if item.uuid == uuid:
			return item
	return null


func get_equipped_item(uuid: String) -> Variant:
	"""
	Finds an equipped item within the player's Meks.
	"""
	for mek in meks:
		var item = mek.get_item(uuid)
		if item:
			return item
	return null


# =============================================================================
# SERIALIZATION
# =============================================================================


func from_dict(data: Dictionary) -> bool:
	"""Loads player data from a dictionary."""
	if not data.has("player_name") or not data.has("player_uuid"):
		push_error("Invalid Player data: Missing required fields")
		return false

	player_name = data["player_name"]
	player_uuid = data["player_uuid"]

	for mek_data in data.get("meks", {}):
		add_mek(Mek.new(mek_data))
	for item_data in data.get("items", {}):
		add_item(Item.new(item_data))

	return true


func to_dict() -> Dictionary:
	"""
	Converts player data to a dictionary.
	"""
	return {
		"player_name": player_name,
		"player_uuid": player_uuid,
		"meks": Utils.convert_objects_to_dict(meks),
		"items": Utils.convert_objects_to_dict(items),
	}


func to_client_dict() -> Dictionary:
	"""
	Converts Mek instance data to a dictionary.
	"""
	return {
		"player_name": player_name,
		"player_uuid": player_uuid,
		"meks": Utils.convert_objects_to_client_dict(meks),
		"items": Utils.convert_objects_to_client_dict(items),
	}
