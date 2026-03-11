# Represents a structure on the map (wall, building, etc).
# Structures have position, ownership, health, armor, and can block movement.

class_name MapStructure
extends MapEntity

# =============================================================================
# PROPERTIES
# =============================================================================

var structure_name: String
var max_health: int
var current_health: int
var armor: int
# Whether this structure blocks movement
var blocking: bool

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_structure_name: String,
	p_max_health: int,
	p_armor: int,
	p_blocking: bool = true
) -> void:
	position = p_position
	owner = p_owner
	structure_name = p_structure_name
	max_health = p_max_health
	current_health = p_max_health
	armor = p_armor
	blocking = p_blocking
	active = true


func take_damage(damage: int) -> void:
	"""Apply damage to this structure."""
	var adjusted_damage: int = max(1, damage - armor)
	current_health = max(0, current_health - adjusted_damage)
	if current_health <= 0:
		active = false


func is_alive() -> bool:
	"""Check if this structure still has health."""
	return current_health > 0 and active


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapStructure:
	"""
	Loads structure data from a dictionary.
	"""
	if (
		not data.has("position")
		or not data.has("owner")
		or not data.has("structure_name")
		or not data.has("max_health")
		or not data.has("current_health")
		or not data.has("armor")
		or not data.has("blocking")
		or not data.has("active")
	):
		push_error("Invalid MapStructure data: Missing required fields")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapStructure data: failed to deserialize owner")
		return null

	var loaded_structure := MapStructure.new(
		Utils.deserialize_position(data["position"]),
		parsed_owner,
		data["structure_name"],
		data["max_health"],
		data["armor"],
		data["blocking"]
	)
	loaded_structure.current_health = data["current_health"]
	loaded_structure.active = bool(data["active"])
	return loaded_structure


func to_dict() -> Dictionary:
	"""Converts structure data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"owner": owner.to_dict(),
		"structure_name": structure_name,
		"max_health": max_health,
		"current_health": current_health,
		"armor": armor,
		"blocking": blocking,
		"active": active
	}
