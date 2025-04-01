# This class represents a game entity on the map, such as a Mek or Structure.
# It contains the position of the entity on the map, a reference to the actual
# game entity, and other properties related to the entity's state.

class_name MapMek
extends MapEntity

# =============================================================================
# PROPERTIES
# =============================================================================

var mek: Mek

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_position: Vector2i, p_owner: EntityOwner, p_mek: Mek) -> void:
	position = p_position
	owner = p_owner
	mek = p_mek
	active = true


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapMek:
	"""
	Loads item data from a dictionary.
	"""
	if (
		not data.has("position")
		or not data.has("mek")
		or not data.has("owner")
		or not data.has("active")
	):
		push_error("Invalid MapMek data: Missing required fields")
		return null
	return MapMek.new(
		Utils.deserialize_position(data["position"]),
		NPCOwned.from_dict(data["owner"]),
		Mek.new(data["mek"])
	)


func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"mek": mek.to_dict(),
		"owner": owner.to_dict(),
		"active": active
	}
