# This class represents a game entity on the map, such as a Mek or Structure.
# It contains the position of the entity on the map, a reference to the actual
# game entity, and other properties related to the entity's state.

class_name MapMek
extends MapCombatEntity

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_position: Vector2i, p_owner: EntityOwner, p_mek: Mek) -> void:
	super(p_position, p_owner, p_mek, true)


func can_move() -> bool:
	return true


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapMek:
	"""
	Loads item data from a dictionary.
	"""
	if not data.has("position") or not data.has("owner") or not data.has("active"):
		push_error("Invalid MapMek data: Missing required fields")
		return null

	var actor_data: Dictionary = {}
	if data.has("mek"):
		actor_data = data["mek"]
	elif data.has("actor"):
		# Backward compatibility: some map payloads store Mek data under "actor".
		actor_data = data["actor"]
	else:
		push_error("Invalid MapMek data: Missing mek/actor payload")
		return null

	if not actor_data.has("mek_id") or not actor_data.has("uuid"):
		push_error("Invalid MapMek data: payload is not a Mek actor")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapMek data: failed to deserialize owner")
		return null

	var mek_actor: Mek = Mek.new(actor_data)
	if not mek_actor or mek_actor.mek_id.is_empty():
		push_error("Invalid MapMek data: failed to deserialize mek actor")
		return null

	var loaded_map_mek := MapMek.new(
		Utils.deserialize_position(data["position"]),
		parsed_owner,
		mek_actor
	)
	loaded_map_mek.active = bool(data["active"])
	return loaded_map_mek


func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"mek": combatant.to_dict(),
		"owner": owner.to_dict(),
		"blocking": true,
		"active": active
	}
