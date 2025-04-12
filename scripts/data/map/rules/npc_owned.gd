# This class is used to represent an NPC-owned entity in the game.
class_name NPCOwned
extends EntityOwner

# The name of the NPC.
var npc_name: String


func _init(_npc_name: String, _clan: Clan) -> void:
	"""
	Initializes the NPCOwned with a clan and NPC name.
	"""
	super._init(_clan)
	npc_name = _npc_name


func is_player() -> bool:
	"""
	By default, NPCs are not players.
	"""
	return false


static func from_dict(data: Dictionary) -> EntityOwner:
	"""
	Loads NPC data from a dictionary.
	"""
	return NPCOwned.new(data["npc_name"], DataManager.clans[data["clan"]])


func to_dict() -> Dictionary:
	return {"npc_name": npc_name, "clan": clan.id}
