# This is an abstract base class for anything that owns an
# entity in the map. It could be extended by both player
# controllers and NPC factions.

class_name EntityOwner
extends RefCounted

# All entities belong to a clan or faction.
var clan: Clan

func _init(_clan: Clan) -> void:
	"""
	Initializes the EntityOwner with a clan.
	"""
	clan = _clan

# Returns the clan (or faction) this owner belongs to.
func get_clan() -> Clan:
	return clan


# Returns whether this owner is controlled by a human player.
func is_player() -> bool:
	return false


static func from_dict(_data: Dictionary) -> EntityOwner:
	if _data.is_empty():
		push_error("Invalid owner data: empty dictionary")
		return null
	if _data.has("player_uuid"):
		return PlayerOwned.from_dict(_data)
	if _data.has("npc_name"):
		return NPCOwned.from_dict(_data)
	push_error("Invalid owner data: unknown owner type")
	return null


func to_dict() -> Dictionary:
	return {}
