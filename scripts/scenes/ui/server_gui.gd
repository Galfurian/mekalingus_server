extends Node

@onready var server_status = $VBoxContainer/HBoxContainer/ServerStatus
@onready var server_start_stop = $VBoxContainer/HBoxContainer/ServerStartStop
@onready var server_quit = $VBoxContainer/HBoxContainer/ServerQuit

func _ready():
	# Connect the server log.
	server_start_stop.pressed.connect(_on_server_start_stop)
	server_quit.pressed.connect(_on_server_quit)


func _on_server_quit():
	if not GameServer.is_running:
		# If the server is not running, just quit the game.
		get_tree().quit()
		return
	# If the server is running, attempt to stop it before quitting.
	GameServer.log_message("Attempting to stop the server before quitting...")
	if GameServer.stop():
		get_tree().quit()
	else:
		GameServer.log_message("Failed to stop the server.")


func _on_server_start_stop():
	"""Handles the start/stop button."""
	if GameServer.is_running:
		if GameServer.stop():
			server_start_stop.text = "Start"
	else:
		if GameServer.start():
			server_start_stop.text = "Stop"
