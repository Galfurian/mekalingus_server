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
		+ ", ["
		+ str(color.r8)
		+ ", "
		+ str(color.g8)
		+ ", "
		+ str(color.b8)
		+ "]"
	)


func from_dict(data: Dictionary):
	"""Loads data from a dictionary."""
	index = data["index"]
	height = data["height"]
	movement_cost = data["movement_cost"]
	color = Color(data["color"][0] / 255.0, data["color"][1] / 255.0, data["color"][2] / 255.0, 1.0)


func to_dict() -> Dictionary:
	"""Returns the data as a dictionary."""
	return {
		"index": index,
		"height": height,
		"movement_cost": movement_cost,
		"color": [color.r8, color.g8, color.b8]
	}
