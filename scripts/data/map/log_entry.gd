# This class represents a log entry in the game.

class_name LogEntry

var timestamp: String  # When the message was sent.
var log_type: Enums.LogType  # The type of log entry.
var sender: String  # The player/NPC sending the message.
var message: String  # The log message.

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(
	p_log_type: Enums.LogType = Enums.LogType.NONE, p_message: String = "", p_sender: String = ""
) -> void:
	"""
	Constructor for the LogEntry class.
	"""
	timestamp = Time.get_time_string_from_system()
	log_type = p_log_type
	sender = p_sender
	message = p_message


func to_simple_log() -> String:
	"""
	Returns a simple log string.
	"""
	if sender.is_empty():
		return "[%s] %s" % [timestamp, message]
	return "[%s] %s: %s" % [timestamp, sender, message]


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	if sender.is_empty():
		return "[%s][%s] %s" % [timestamp, str(log_type), message]
	return "[%s][%s] %s: %s" % [timestamp, str(log_type), sender, message]


static func from_dict(data: Dictionary) -> LogEntry:
	"""
	Loads log entry data from a dictionary.
	"""
	if (
		not data.has("timestamp")
		or not data.has("log_type")
		or not data.has("sender")
		or not data.has("message")
	):
		push_error("Invalid LogEntry data: Missing required fields")
		return null
	var log_entry = LogEntry.new()
	log_entry.timestamp = data["timestamp"]
	log_entry.log_type = Utils.string_to_enum(Enums.LogType, data["log_type"])
	log_entry.sender = data["sender"]
	log_entry.message = data["message"]
	return log_entry


func to_dict() -> Dictionary:
	"""
	Converts log entry data to a dictionary.
	"""
	return {
		"timestamp": timestamp,
		"log_type": Utils.enum_to_string(Enums.LogType, log_type),
		"sender": sender,
		"message": message,
	}


static func serialize_log_entries_compact(logs: Array[LogEntry]) -> String:
	"""
	Converts log entries into a single compact newline-separated string.
	Each log entry becomes: log_type|sender|timestamp|message
	"""
	if logs.is_empty():
		push_warning("Empty log entries array — skipping serialization.")
		return ""
	var lines: Array[String] = []
	for log_entry in logs:
		var line = "%s|%s|%s|%s" % [
			Utils.enum_to_string(Enums.LogType, log_entry.log_type),
			log_entry.sender.replace("|", "␟"),
			log_entry.timestamp.replace("|", "␟"),
			log_entry.message.replace("|", "␟").replace("\n", "\\n")
		]
		lines.append(line)
	return "\n".join(lines)



static func deserialize_log_entries_compact(data: String) -> Array[LogEntry]:
	"""
	Reconstructs log entries from a newline-separated compact string.
	Each line format: log_type|sender|timestamp|message
	"""
	if data.is_empty():
		push_warning("Empty log string — skipping deserialization.")
		return []
	var logs: Array[LogEntry] = []

	for line in data.split("\n"):
		if line.strip_edges() == "":
			continue

		var parts = line.split("|", true)
		if parts.size() < 4:
			push_warning("Skipping malformed log line: %s" % line)
			continue

		var log_entry = LogEntry.new()
		log_entry.log_type = Utils.string_to_enum(Enums.LogType, parts[0])
		log_entry.sender = parts[1].replace("␟", "|")
		log_entry.timestamp = parts[2].replace("␟", "|")
		log_entry.message = "|".join(parts.slice(3)).replace("\\n", "\n")

		logs.append(log_entry)

	return logs


static func compress_logs_to_base64(logs: Array[LogEntry]) -> Dictionary:
	if logs.is_empty():
		return {}
	var raw_string = serialize_log_entries_compact(logs)
	if raw_string.is_empty():
		push_warning("Empty log string — skipping compression.")
		return {}

	var buffer = raw_string.to_utf8_buffer()
	var compressed = buffer.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty():
		push_error("Compression failed — got empty result.")
		return {}

	return {
		"data": Marshalls.raw_to_base64(compressed),
		"uncompressed_size": buffer.size()
	}



static func decompress_logs_from_base64(log_data: Dictionary) -> Array[LogEntry]:
	if log_data.is_empty():
		return []
	
	if not log_data.has("data") or not log_data.has("uncompressed_size"):
		push_error("Log data missing 'data' or 'uncompressed_size' fields.")
		return []

	var encoded: String = log_data["data"]
	var uncompressed_size: int = log_data["uncompressed_size"]

	if encoded.is_empty():
		push_warning("Attempted to decompress empty base64 string.")
		return []

	var compressed: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		push_error("Base64 decoding failed or result is empty.")
		return []

	var decompressed: PackedByteArray = compressed.decompress(uncompressed_size, FileAccess.COMPRESSION_ZSTD)
	if decompressed.is_empty():
		push_error("Decompression failed or returned empty result.")
		return []

	var raw_string := decompressed.get_string_from_utf8()
	if raw_string.is_empty():
		push_warning("Decompressed string is empty or invalid UTF-8.")
		return []

	return deserialize_log_entries_compact(raw_string)
