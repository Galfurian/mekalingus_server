# This class is responsible for logging events in the game.
class_name MapLogger extends Node

# This signal is emitted when a log entry is added.
signal on_log_added(log_entry: LogEntry)
# Enable/disable logging for each type.
var enabled_types: Array = []
# The list of log entries.
var log_entries: Array[LogEntry] = []

func add_log(log_type: Enums.LogType, message: String, sender: String = "") -> void:
	"""
	Adds a log entry to the logger.
	"""
	if log_type not in enabled_types:
		return
	# Create the new log entry.
	var log_entry = LogEntry.new(log_type, message, sender)
	# Add the log entry to the list.
	log_entries.append(log_entry)
	# Emit the signal to notify that a log entry has been added.
	on_log_added.emit(log_entry)

func set_combat_preset() -> void:
	"""
	Sets the logger to combat preset.
	"""
	enabled_types = [Enums.LogType.ATTACK, Enums.LogType.SUPPORT, Enums.LogType.MOVEMENT, Enums.LogType.SYSTEM, Enums.LogType.AI]

func set_chat_preset() -> void:
	"""
	Sets the logger to chat preset.
	"""
	enabled_types = [Enums.LogType.CHAT, Enums.LogType.SYSTEM]

func get_logs() -> Array[LogEntry]:
	"""
	Returns a list of all log entries.
	"""
	return log_entries

func get_logs_by_type(log_type: Enums.LogType) -> Array[LogEntry]:
	"""
	Returns a list of log entries of the specified type.
	"""
	return log_entries.filter(func(entry): return entry.log_type == log_type)

func clear() -> void:
	"""
	Clears all log entries.
	"""
	log_entries.clear()

func set_log_enabled(log_type: Enums.LogType, enabled: bool) -> void:
	"""
	Enables or disables logging for the specified type.
	"""
	if enabled and not is_log_enabled(log_type):
		enabled_types.append(log_type)
	elif not enabled and is_log_enabled(log_type):
		enabled_types.erase(log_type)

func is_log_enabled(log_type: Enums.LogType) -> bool:
	"""
	Checks if logging is enabled for the specified type.
	"""
	return log_type in enabled_types

static func from_dict(data: Dictionary) -> MapLogger:
	"""
	Creates a MapLogger instance from a dictionary.
	"""
	var logger = MapLogger.new()
	# Load the log entries from the dictionary.
	logger.log_entries = LogEntry.decompress_logs_from_base64(data.get("log_entries", {}))
	logger.enabled_types = Utils.strings_to_enums(Enums.LogType, data.get("enabled_types", []))
	return logger


func to_dict() -> Dictionary:
	"""
	Converts the MapLogger instance to a dictionary.
	"""
	return {
		"log_entries": LogEntry.compress_logs_to_base64(log_entries),
		"enabled_types": Utils.enums_to_strings(Enums.LogType, enabled_types),
	}
