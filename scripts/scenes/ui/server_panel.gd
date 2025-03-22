extends Node

@onready var server_log        = $ServerLog/ServerLogContent
@onready var server_status     = $HBoxContainer/ServerStatus
@onready var server_start_stop = $HBoxContainer/ServerStartStop
@onready var server_quit       = $HBoxContainer/ServerQuit

func _ready():
	# Connect the server log.
	GameServer.log_message_emitted.connect(_on_log_message)
	server_start_stop.pressed.connect(_on_server_start_stop)
	server_quit.pressed.connect(_on_server_quit)


func _on_server_quit():
	if GameServer.stop():
		get_tree().quit()
	else:
		_on_log_message("Failed to stop the server.")
	
func _on_server_start_stop():
	"""Handles the start/stop button."""
	if GameServer.is_running:
		if GameServer.stop():
			server_start_stop.text = "Start"
	else:
		if GameServer.start():
			server_start_stop.text = "Stop"

func _on_log_message(msg: String):
	"""Handles incoming log messages and updates the UI."""
	server_log.append_text(msg + "\n")
