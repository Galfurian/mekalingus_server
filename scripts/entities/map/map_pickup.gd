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
	p_passable: bool,
	p_active: bool,
	p_item_data: Dictionary,
) -> void:
	super(p_position, p_owner, p_passable, p_active)
	item_data = p_item_data


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapEntity:
	"""
	Loads pickup data from a dictionary.
	"""
	if not data:
		push_error("Invalid MapPickup data: data is null")
		return null
	if not data.has("position"):
		push_error("Invalid MapPickup data: missing position")
		return null
	if not data.has("owner"):
		push_error("Invalid MapPickup data: missing owner")
		return null
	if not data.has("item_data"):
		push_error("Invalid MapPickup data: missing item_data")
		return null
	if not data.has("active"):
		push_error("Invalid MapPickup data: missing active")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapPickup data: failed to deserialize owner")
		return null

	var loaded_pickup := (
		MapPickup
		. new(
			Utils.deserialize_position(data["position"]),
			parsed_owner,
			bool(data["passable"]),
			bool(data["active"]),
			data["item_data"],
		)
	)
	return loaded_pickup


func to_dict() -> Dictionary:
	"""Converts pickup data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"owner": owner.to_dict(),
		"passable": passable,
		"active": active,
		"item_data": item_data,
	}
