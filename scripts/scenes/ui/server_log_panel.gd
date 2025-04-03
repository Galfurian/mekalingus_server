extends Node

@onready var server_log = $ServerLog/ServerLogContent


func _ready():
	# Connect the server log.
	GameServer.log_message_emitted.connect(_on_log_message)

func _on_log_message(msg: String):
	"""Handles incoming log messages and updates the UI."""
	server_log.append_text(msg + "\n")
