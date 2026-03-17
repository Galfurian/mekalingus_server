# This class represents a game entity on the map, such as a Mek or Structure.
# It contains the position of the entity on the map, a reference to the actual
# game entity, and other properties related to the entity's state.

class_name MapEntity
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# Map position
var position: Vector2i
# The owner of this entity.
var owner: EntityOwner
# Whether this entity blocks movement.
var blocking: bool = false
# Whether the entity is active (false = destroyed or removed)
var active: bool = true

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_position: Vector2i, p_owner: EntityOwner, p_blocking: bool = false) -> void:
	position = p_position
	owner = p_owner
	blocking = p_blocking
	active = true


func can_move() -> bool:
	return false


func get_icon_path() -> String:
	return ""


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(_data: Dictionary) -> MapEntity:
	"""
	Loads item data from a dictionary.
	"""
	return null


func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	return {}
