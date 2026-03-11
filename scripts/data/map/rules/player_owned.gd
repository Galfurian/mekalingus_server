# This class is used to represent a player-owned entity in the game.
class_name PlayerOwned
extends EntityOwner

var player: Player


func _init(_player: Player, _clan: Clan) -> void:
	"""
	Initializes the PlayerOwned with a player and clan.
	"""
	super._init(_clan)
	player = _player


func is_player() -> bool:
	"""
	By default, players are players.
	"""
	return true


static func from_dict(data: Dictionary) -> EntityOwner:
	"""
	Loads PlayerOwned data from a dictionary.
	"""
	if not data.has_all(["player_uuid", "clan"]):
		push_error("Invalid PlayerOwned data: missing required fields")
		return null
	var resolved_player: Player = DataManager.find_player_by_uuid(data["player_uuid"])
	if not resolved_player:
		push_error("Invalid PlayerOwned data: unknown player_uuid %s" % data["player_uuid"])
		return null
	var resolved_clan: Clan = DataManager.clans.get(data["clan"], null)
	if not resolved_clan:
		push_error("Invalid PlayerOwned data: unknown clan %s" % data["clan"])
		return null
	return PlayerOwned.new(resolved_player, resolved_clan)


func to_dict() -> Dictionary:
	return {
		"player_uuid": player.player_uuid,
		"clan": clan.id,
	}
