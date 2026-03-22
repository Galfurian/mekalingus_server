# This class is used to represent an NPC-owned entity in the game.
class_name NPCOwned
extends EntityOwner

# The name of the NPC.
var npc_name: String
# Optional per-pilot AI profile override path.
var ai_profile_path: String = ""


func _init(_npc_name: String, _clan: Clan) -> void:
	"""
	Initializes the NPCOwned with a clan and NPC name.
	"""
	super._init(_clan)
	npc_name = _npc_name


func get_name() -> String:
	"""
	Returns the name of the NPC owner.
	"""
	return npc_name


func is_player() -> bool:
	"""
	By default, NPCs are not players.
	"""
	return false


static func from_dict(data: Dictionary) -> EntityOwner:
	"""
	Loads NPC data from a dictionary.
	"""
	if not data.has_all(["npc_name", "clan"]):
		push_error("Invalid NPCOwned data: missing required fields")
		return null
	var resolved_clan: Clan = DataManager.clans.get(data["clan"], null)
	if not resolved_clan:
		push_error("Invalid NPCOwned data: unknown clan %s" % data["clan"])
		return null
	var npc_owner: NPCOwned = NPCOwned.new(data["npc_name"], resolved_clan)
	npc_owner.ai_profile_path = data.get("ai_profile_path", "")
	return npc_owner


func to_dict() -> Dictionary:
	return {
		"npc_name": npc_name,
		"clan": clan.id,
		"ai_profile_path": ai_profile_path,
	}
