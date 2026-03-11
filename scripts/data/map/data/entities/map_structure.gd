# Represents a structure on the map (wall, building, etc).
# Structures have position, ownership, health, armor, and can block movement.

class_name MapStructure
extends "res://scripts/data/map/data/entities/map_combat_entity.gd"

const StructureActorScript = preload("res://scripts/data/structure/structure_actor.gd")

# =============================================================================
# PROPERTIES
# =============================================================================

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
	p_items: Array[Item],
	p_blocking: bool = true
) -> void:
	position = p_position
	owner = p_owner
	combatant = StructureActorScript.new(p_structure_name, p_max_health, p_armor, p_items)
	blocking = p_blocking
	active = true


func take_damage(damage: int) -> void:
	"""Apply damage to this structure."""
	var adjusted_damage: int = max(1, damage - combatant.armor)
	combatant.health = max(0, combatant.health - adjusted_damage)
	if combatant.health <= 0:
		active = false


func is_alive() -> bool:
	"""Check if this structure still has health."""
	return combatant and combatant.is_alive() and active


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
		or not data.has("actor")
		or not data.has("blocking")
		or not data.has("active")
	):
		push_error("Invalid MapStructure data: Missing required fields")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapStructure data: failed to deserialize owner")
		return null

	var actor = StructureActorScript.from_dict(data["actor"])
	if not actor:
		push_error("Invalid MapStructure data: failed to deserialize actor")
		return null

	var loaded_structure := MapStructure.new(
		Utils.deserialize_position(data["position"]),
		parsed_owner,
		actor.structure_name,
		actor.max_health,
		actor.armor,
		actor.items,
		data["blocking"]
	)
	loaded_structure.combatant = actor
	loaded_structure.active = bool(data["active"])
	return loaded_structure


func to_dict() -> Dictionary:
	"""Converts structure data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"owner": owner.to_dict(),
		"actor": combatant.to_dict(),
		"blocking": blocking,
		"active": active
	}
