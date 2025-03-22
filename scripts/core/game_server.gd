extends Node

# The port at which the server is listening to.
const SERVER_PORT = 5000

# Keep track if the server is running.
var is_running = false

# Signal for log updates.
signal log_message_emitted(message: String)

# Signal for when the server starts successfully.
signal on_server_start()

# Signal for when the server stops successfully.
signal on_server_stop()

func start():
	"""Starts the server."""
	log_message("============================================================")
	log_message("Starting server...")
	# Check if the server is already running.
	if is_running:
		log_message("Server is already running.")
		return false
	# Load all the templates.
	if not TemplateManager.load_all():
		log_message("Failed to load the templates.")
		return false
	# Load all the data.
	if not DataManager.load_all():
		log_message("Failed to load the data.")
		return false
	# Start the server.
	if not _start_server():
		log_message("Failed to start the server.")
		return false
	# Set the server as running.
	is_running = true
	# Notify that the server has started.
	on_server_start.emit()
	log_message("Server ready!")
	return true

func stop():
	"""Stopes the server."""
	log_message("Stopping server...")
	# Check if the server is not running.
	if not is_running:
		log_message("Server is not running.")
		return false
	# Save all the data.
	if not DataManager.save_all():
		log_message("Failed to save the data.")
		return false
	# Clear all the templates.
	TemplateManager.clear_all()
	# Clear all the data.
	DataManager.clear_all()
	# Stop the server.
	if !_stop_server():
		log_message("Failed to stop the server.")
		return false
	# Set the server as not running.
	is_running = false
	# Notify that the server has stopped.
	on_server_stop.emit()
	log_message("Server stopped!")
	log_message("============================================================")
	return true

# =============================================================================
# CONNECTION
# =============================================================================

# Connection.
var multiplayer_peer = ENetMultiplayerPeer.new()

func _start_server() -> bool:
	multiplayer_peer.create_server(SERVER_PORT, 32)
	multiplayer.multiplayer_peer = multiplayer_peer
	if !multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if !multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return true

func _stop_server() -> bool:
	for peer_id in multiplayer.get_peers():
		multiplayer.disconnect_peer(peer_id)
	multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	return true

func restart_server():
	_stop_server()
	await get_tree().create_timer(1.0).timeout
	_start_server()

func _on_peer_connected(peer_id):
	log_message("Client connected: " + str(peer_id))

func _on_peer_disconnected(peer_id):
	log_message("Client disconnected: " + str(peer_id))

# =============================================================================
# UUID
# =============================================================================

var used_uuids = {}

func occupy_uuid(uuid: String):
	used_uuids[uuid] = true

func free_uuid(uuid: String):
	if uuid in used_uuids:
		used_uuids.erase(uuid)

func generate_uuid() -> String:
	var new_uuid = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000)
	# Ensure uniqueness.
	while new_uuid in used_uuids:
		new_uuid = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000)
	occupy_uuid(new_uuid)
	return new_uuid

# =============================================================================
# LOGGING
# =============================================================================

func log_message(msg: String):
	"""Emits a log message that can be captured by the UI and other scripts."""
	# Get formatted timestamp.
	var log_entry = "[" + Time.get_datetime_string_from_system(true) + "] " + msg
	# Emit log message signal.
	log_message_emitted.emit(log_entry)
	# Also print to console.
	print(log_entry)
