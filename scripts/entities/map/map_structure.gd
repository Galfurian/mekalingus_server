# Represents a structure on the map (wall, building, etc).
# Structures have position, ownership, health, armor, and can block movement.

class_name MapStructure
extends MapCombatEntity

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_structure: Structure,
) -> void:
	super(p_position, p_owner, false, true, p_structure)


func take_damage(damage: int) -> void:
	"""Apply damage to this structure."""
	var adjusted_damage: int = max(1, damage - combatant.armor)
	combatant.health = max(0, combatant.health - adjusted_damage)
	if combatant.health <= 0:
		active = false


func is_alive() -> bool:
	"""Check if this structure still has health."""
	return combatant and combatant.is_alive() and active


func can_move() -> bool:
	return false


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapEntity:
	"""
	Loads item data from a dictionary.
	"""
	if not data:
		push_error("Invalid MapStructure data: data is null")
		return null
	if not data.has("position"):
		push_error("Invalid MapStructure data: missing position")
		return null
	if not data.has("owner"):
		push_error("Invalid MapStructure data: missing owner")
		return null
	if not data.has("actor_type"):
		push_error("Invalid MapStructure data: missing actor_type")
		return null
	if not data.has("actor"):
		push_error("Invalid MapStructure data: missing actor")
		return null
	if not data.has("passable"):
		push_error("Invalid MapStructure data: missing passable")
		return null
	if not data.has("active"):
		push_error("Invalid MapStructure data: missing active")
		return null

	if str(data["actor_type"]) != "structure":
		push_error("Invalid MapStructure data: actor_type must be 'structure'")
		return null

	var actor_data: Dictionary = data["actor"]
	if not actor_data.has("structure_id") or not actor_data.has("uuid"):
		push_error("Invalid MapStructure data: payload is not a Structure actor")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapStructure data: failed to deserialize owner")
		return null

	var structure_actor: Structure = Structure.from_dict(actor_data)
	if not structure_actor:
		push_error("Invalid MapStructure data: failed to deserialize structure actor")
		return null

	var loaded_map_structure := MapStructure.new(
		Utils.deserialize_position(data["position"]), parsed_owner, structure_actor
	)
	loaded_map_structure.active = bool(data["active"])
	return loaded_map_structure


func to_dict() -> Dictionary:
	"""Converts structure data to a dictionary."""
	var data: Dictionary = super.to_dict()
	data["actor_type"] = "structure"
	return data
