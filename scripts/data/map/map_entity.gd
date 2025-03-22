extends RefCounted

class_name MapEntity

# =============================================================================
# PROPERTIES
# =============================================================================

# Map position
var position: Vector2i
# The actual game entity (e.g., Mek, Structure, etc.)
var entity: Variant
# Whether the entity is active (false = destroyed or removed)
var active: bool = true

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================

func _init(p_position: Vector2i, p_entity: Variant) -> void:
	position = p_position
	entity = p_entity
	active = true

# =============================================================================
# SERIALIZATION
# =============================================================================

func from_dict(data: Dictionary):
	"""Loads item data from a dictionary."""
	if not data.has("position") or not data.has("entity") or not data.has("active"):
		push_error("Invalid Item data: Missing required fields")
		return
		
	var coordinates = data["position"].split(",")
	position = Vector2i(int(coordinates[0]), int(coordinates[1]))

func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	return {
		"position": ("%d,%d" % [position.x, position.y]),
		"entity": entity.to_dict(),
		"active": active
	}
