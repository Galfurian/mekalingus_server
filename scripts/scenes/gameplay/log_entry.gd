class_name LogEntry

var timestamp: String       # When the message was sent.
var log_type: Enums.LogType # The type of log entry.
var sender: String          # The player/NPC sending the message.
var message: String         # The log message.

func _init(p_log_type: Enums.LogType, p_message: String, p_sender: String = "") -> void:
	timestamp = Time.get_time_string_from_system()
	log_type = p_log_type
	sender = p_sender
	message = p_message

func to_simple_log() -> String:
	if sender.is_empty():
		return "[%s] %s" % [timestamp, message]
	return "[%s] %s: %s" % [timestamp, sender, message]

func _to_string() -> String:
	if sender.is_empty():
		return "[%s][%s] %s" % [timestamp, str(log_type), message]
	return "[%s][%s] %s: %s" % [timestamp, str(log_type), sender, message]
