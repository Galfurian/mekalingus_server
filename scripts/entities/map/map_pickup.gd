# Represents an item dropped on the map that can be picked up by Meks.
# Pickups have a position and carry serialized item data.

class_name MapPickup
extends MapEntity

# =============================================================================
# PROPERTIES
# =============================================================================

# Serialized item data (can be reconstructed as an Item)
var item_data: Dictionary

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_item_data: Dictionary,
	p_blocking: bool = false
) -> void:
	super(p_position, p_owner, p_blocking)
	item_data = p_item_data


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapEntity:
	"""
	Loads pickup data from a dictionary.
	"""
	if (
		not data.has("position")
		or not data.has("owner")
		or not data.has("item_data")
		or not data.has("active")
	):
		push_error("Invalid MapPickup data: Missing required fields")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapPickup data: failed to deserialize owner")
		return null

	var loaded_pickup := MapPickup.new(
		Utils.deserialize_position(data["position"]),
		parsed_owner,
		data["item_data"],
		bool(data.get("blocking", false))
	)
	loaded_pickup.active = bool(data["active"])
	return loaded_pickup


func to_dict() -> Dictionary:
	"""Converts pickup data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"owner": owner.to_dict(),
		"item_data": item_data,
		"blocking": blocking,
		"active": active
	}
