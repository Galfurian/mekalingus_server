class_name BiomeLevel

extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

var index: int
var height: int
var movement_cost: int
var color: Color

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	if data:
		from_dict(data)


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	"""Returns the data as a string."""
	return (
		"BiomeLevel: "
		+ str(index)
		+ ", "
		+ str(height)
		+ ", "
		+ str(movement_cost)
		+ ", "
		+ str(color)
	)


func from_dict(data: Dictionary):
	"""Loads data from a dictionary."""
	index = data.get("index", 0)
	height = data.get("height", 0)
	movement_cost = data.get("movement_cost", 0)
	color = data.get("color", Color.GRAY)


func to_dict() -> Dictionary:
	"""Returns the data as a dictionary."""
	return {
		"index": index,
		"height": height,
		"movement_cost": movement_cost,
		"color": [color.r8, color.g8, color.b8]
	}
