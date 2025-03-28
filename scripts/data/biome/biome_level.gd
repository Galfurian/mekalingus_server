class_name BiomeLevel

extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

var index: int
var name: String
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
		"[("
		+ str(index)
		+ ") "
		+ name
		+ ": "
		+ str(height)
		+ ", "
		+ str(movement_cost)
		+ ", ["
		+ Utils.color_to_hex(color)
		+ "]"
	)


func from_dict(data: Dictionary):
	"""Loads data from a dictionary."""
	index = data["index"]
	name = data["name"]
	height = data["height"]
	movement_cost = data["movement_cost"]
	color = Utils.hex_to_color(data["color"])


func to_dict() -> Dictionary:
	"""Returns the data as a dictionary."""
	return {
		"index": index,
		"name": name,
		"height": height,
		"movement_cost": movement_cost,
		"color": Utils.color_to_hex(color),
	}
