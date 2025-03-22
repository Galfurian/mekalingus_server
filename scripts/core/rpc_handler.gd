extends Node

# Stores connections [peer_id -> Player.player_uuid]
var peer_player_map: Dictionary[int, String]

# =============================================================================
# GENERAL
# =============================================================================

func log_message(msg: String):
	GameServer.log_message(msg)

func associate_peer_with_player(peer_id: int, player_uuid: String):
	"""When a client logs in, associate their peer_id with their player_uuid."""
	# Search for a possible previously associated peer_id.
	var previous_peer_id = find_peer_id(player_uuid)
	# If an old peer_id exists, force disconnect it before reassigning
	if previous_peer_id and previous_peer_id != peer_id:
		# Check if the peer is active.
		if multiplayer.get_peers().has(previous_peer_id):
			log_message("Forcing disconnect of old session for:" + player_uuid)
			multiplayer.disconnect_peer(previous_peer_id)
		remove_peer(previous_peer_id)
	# Assign new peer_id to the player_uuid
	peer_player_map[peer_id] = player_uuid
	log_message("Associated peer with player: " + str(peer_id) + " -> " + player_uuid)

func find_player_uuid(peer_id: int) -> String:
	"""Get the player_uuid associated with a peer_id."""
	return peer_player_map.get(peer_id, "")

func find_peer_id(player_uuid: String) -> int:
	"""Get the peer_id associated with a player_uuid."""
	for peer_id in peer_player_map:
		if peer_player_map[peer_id] == player_uuid:
			return peer_id
	return 0

func remove_peer(peer_id: int):
	"""Remove peer association when they disconnect."""
	if peer_player_map.has(peer_id):
		log_message("Removing peer from player map: " + str(peer_id) + " -> " + peer_player_map[peer_id])
		peer_player_map.erase(peer_id)
	
# =============================================================================
# RPC: GENERIC
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func generic_failed_request(_reason: String):
	pass

func send_generic_failure(peer_id: int, reason: String):
	generic_failed_request.rpc_id(peer_id, reason)
	log_message("[" + str(peer_id) + "] " + reason)
	
# =============================================================================
# RPC: LOGIN
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func login_successful(_player_data: Player):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func login_player(player_name: String):
	var peer_id = multiplayer.get_remote_sender_id()
	var player  = DataManager.find_player_by_name(player_name)
	if not player:
		send_generic_failure(peer_id, "Failed to FIND player.")
		return
	log_message("Login peer " + str(peer_id) + " as player " + player_name + ".")
	# Update the (peer_id <-> player_uuid) association.
	associate_peer_with_player(peer_id, player.player_uuid)
	# Send the updated player.
	receive_player.rpc_id(peer_id, player.to_client_dict())
	# Notify that the login was successful.
	login_successful.rpc_id(peer_id, player.player_uuid)

# =============================================================================
# RPC: REGISTER
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func registration_successful(_player_uuid: String):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func register_player(player_name: String):
	var peer_id = multiplayer.get_remote_sender_id()
	var player  = DataManager.find_player_by_name(player_name)
	if player:
		send_generic_failure(peer_id, "Player with given NAME already exists.")
		return
	var player_uuid = GameServer.generate_uuid()
	player = DataManager.find_player_by_uuid(player_uuid)
	if player:
		send_generic_failure(peer_id, "Player with given UUID already exists.")
		return
	player = DataManager.create_player(player_name, player_uuid)
	if not player:
		send_generic_failure(peer_id, "Failed to CREATE new player.")
		return
	if not DataManager.save_player(player):
		send_generic_failure(peer_id, "Failed to SAVE new player.")
		return
	log_message("Registered peer " + str(peer_id) + " as player " + player_name + ".")
	# Update the (peer_id <-> player_uuid) association.
	associate_peer_with_player(peer_id, player.player_uuid)
	# Send the updated player.
	receive_player.rpc_id(peer_id, player.to_client_dict())
	# Notify that the registration was successful.
	registration_successful.rpc_id(peer_id, player.player_uuid)

# =============================================================================
# RPC: TEMPLATES
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_mek_templates(_data: Array):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_item_templates(_data: Array):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func request_mek_templates():
	var peer_id = multiplayer.get_remote_sender_id()
	log_message("Peer " + str(peer_id) + " requested the Mek templates.")
	receive_mek_templates.rpc_id(peer_id, Utils.convert_objects_to_dict(TemplateManager.mek_templates.values()))

@rpc("any_peer", "call_remote", "reliable", 0)
func request_item_templates():
	var peer_id = multiplayer.get_remote_sender_id()
	log_message("Peer " + str(peer_id) + " requested the Item templates.")
	receive_item_templates.rpc_id(peer_id, Utils.convert_objects_to_dict(TemplateManager.item_templates.values()))

# =============================================================================
# RPC: EQUIP
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func request_equip_item_success(_mek_uuid: String, _item_uuid: String):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func request_equip_item(mek_uuid: String, item_uuid: String):
	var peer_id     = multiplayer.get_remote_sender_id()
	var player_uuid = find_player_uuid(peer_id)
	
	var player = DataManager.find_player_by_uuid(player_uuid)
	if not player:
		send_generic_failure(peer_id, "Failed to find player (" + player_uuid + ")")
		return
	var mek = player.get_mek(mek_uuid)
	if not mek:
		send_generic_failure(peer_id, "Failed to find mek (" + mek_uuid + ")")
		return
	var item = player.get_item(item_uuid)
	if not item:
		send_generic_failure(peer_id, "Failed to find item (" + item_uuid + ")")
		return
	if not player.remove_item(item):
		send_generic_failure(peer_id, "Failed to remove item " + item.template.name + " from player.")
		return
	if not mek.add_item(item):
		if not player.add_item(item):
			send_generic_failure(peer_id, "Failed to re-add item " + item.template.name + " to player.")
			return
		send_generic_failure(peer_id, "Failed to equip item " + item.template.name + " to " + mek.template.name )
		return
		
	log_message("Player " + player.player_name + " equipped " + mek.template.name + " with " + item.template.name)
	
	# Send the updated player.
	request_equip_item_success.rpc_id(peer_id, mek_uuid, item_uuid)

# =============================================================================
# RPC: UNEQUIP
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func request_unequip_item_success(_mek_uuid: String, _item_uuid: String):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func request_unequip_item(mek_uuid: String, item_uuid: String):
	var peer_id     = multiplayer.get_remote_sender_id()
	var player_uuid = find_player_uuid(peer_id)
	
	var player: Player
	var mek: Mek
	var item: Item
	
	player = DataManager.find_player_by_uuid(player_uuid)
	if not player:
		send_generic_failure(peer_id, "Failed to find player (" + player_uuid + ")")
		return
	
	mek = player.get_mek(mek_uuid)
	if not mek:
		send_generic_failure(peer_id, "Failed to find mek (" + mek_uuid + ")")
		return
	
	item = mek.get_item(item_uuid)
	if not item:
		send_generic_failure(peer_id, "Failed to find equipped item " + item_uuid + " in " + mek.template.name)
		return
	
	if not mek.remove_item(item):
		send_generic_failure(peer_id, "Failed to remove item " + item.template.name + " from " + mek.template.name)
		return
	player.add_item(item)
	
	log_message("Player " + player.player_name + " unequipped " + item.template.name + " from " + mek.template.name)
	
	# Send the updated player.
	request_unequip_item_success.rpc_id(peer_id, mek_uuid, item_uuid)
	
	

# =============================================================================
# RPC: PLAYER
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_player(_data: Dictionary):
	pass

# =============================================================================
# RPC: MEK
# =============================================================================

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_mek(_mek_data: Dictionary):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func request_mek(mek_uuid: String):
	var peer_id     = multiplayer.get_remote_sender_id()
	var player_uuid = find_player_uuid(peer_id)
	
	var player: Player
	var mek: Mek
	
	player = DataManager.find_player_by_uuid(player_uuid)
	if not player:
		send_generic_failure(peer_id, "Failed to find player (" + player_uuid + ")")
		return
	
	mek = player.get_mek(mek_uuid)
	if not mek:
		send_generic_failure(peer_id, "Failed to find mek (" + mek_uuid + ")")
		return

	# Send the Mek data back to the requesting client.
	receive_mek.rpc_id(peer_id, mek.to_client_dict())
	
	log_message("Player " + player.player_name + " requested update for " + mek.template.name + ".")

@rpc("any_peer", "call_remote", "reliable", 0)
func set_mek_alias_success(_mek_uuid: String, _alias: String):
	pass

@rpc("any_peer", "call_remote", "reliable", 0)
func set_mek_alias(mek_uuid: String, alias: String):
	var peer_id     = multiplayer.get_remote_sender_id()
	var player_uuid = find_player_uuid(peer_id)
	var player: Player = DataManager.find_player_by_uuid(player_uuid)
	if not player:
		send_generic_failure(peer_id, "Failed to find player (" + player_uuid + ")")
		return
	var mek: Mek = player.get_mek(mek_uuid)
	if not mek:
		send_generic_failure(peer_id, "Failed to find mek (" + mek_uuid + ")")
		return
	# Set the mek alias.
	mek.alias = alias
	# Send the updated player.
	set_mek_alias_success.rpc_id(peer_id, mek_uuid, alias)
	log_message("Player " + player.player_name + " calls " + mek.template.name + " with the alias " + alias + ".")
