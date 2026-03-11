class_name PeerSessionManager
extends RefCounted

## Manages the bidirectional peer_id <-> player_uuid association for active sessions.

var _map: Dictionary[int, String]


func associate(multiplayer_api: MultiplayerAPI, peer_id: int, player_uuid: String) -> void:
	"""Associates a peer with a player. Disconnects any stale session for the same player."""
	var previous_peer_id := find_peer_id(player_uuid)
	if previous_peer_id != 0 and previous_peer_id != peer_id:
		if multiplayer_api.get_peers().has(previous_peer_id):
			multiplayer_api.disconnect_peer(previous_peer_id)
		remove(previous_peer_id)
	_map[peer_id] = player_uuid


func find_player_uuid(peer_id: int) -> String:
	"""Returns the player_uuid associated with a peer_id, or empty string if not found."""
	return _map.get(peer_id, "")


func find_peer_id(player_uuid: String) -> int:
	"""Returns the peer_id associated with a player_uuid, or 0 if not found."""
	for peer_id: int in _map:
		if _map[peer_id] == player_uuid:
			return peer_id
	return 0


func remove(peer_id: int) -> void:
	"""Removes the peer association when the peer disconnects."""
	_map.erase(peer_id)
