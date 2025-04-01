# This class is used to represent an NPC-owned entity in the game.
class_name NPCOwned
extends EntityOwner

var npc_name: String
var clan: Clan


func _init(_npc_name: String, _clan: Clan) -> void:
	npc_name = _npc_name
	clan = _clan


func get_clan() -> Clan:
	return clan


# By default, NPCFaction is not player-controlled.
func is_player() -> bool:
	return false


static func from_dict(data: Dictionary) -> EntityOwner:
	"""
	Loads NPC data from a dictionary.
	"""
	return NPCOwned.new(data["npc_name"], DataManager.clans[data["clan"]])


func to_dict() -> Dictionary:
	return {"npc_name": npc_name, "clan": clan.id}
