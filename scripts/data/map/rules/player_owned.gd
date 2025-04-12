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
