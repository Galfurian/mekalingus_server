# This class is used to represent a player-owned entity in the game.
class_name PlayerOwned
extends EntityOwner

var player: Player
var clan: Clan


func _init(_player: Player, _clan: Clan) -> void:
	player = _player
	clan = _clan


func get_clan() -> Clan:
	return clan


func is_player() -> bool:
	return true
