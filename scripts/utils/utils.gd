class_name Utils

extends Node


static func to_array_int(array: Array) -> Array[int]:
	"""Transforms an arbitrary array into an array of integers"""
	var output: Array[int] = []
	for entry in array:
		output.append(int(entry))
	return output


static func convert_objects_to_client_dict(list: Array[Variant]) -> Array:
	"""Convert a list of objects with `to_dict()` into a list of dictionaries."""
	var output = []
	for entry in list:
		if entry.has_method("to_client_dict"):
			output.append(entry.to_client_dict())
		else:
			GameServer.log_message("Object does not implement to_client_dict()")
	return output


static func convert_objects_to_dict(list: Array[Variant]) -> Array:
	"""Convert a list of objects with `to_dict()` into a list of dictionaries."""
	var output = []
	for entry in list:
		if entry.has_method("to_dict"):
			output.append(entry.to_dict())
		else:
			GameServer.log_message("Object does not implement to_dict()")
	return output


static func convert_from_list_dict(list: Array, target_class: GDScript) -> Array:
	"""Convert a list of dictionaries back into objects of the specified class."""
	var output = []
	for entry in list:
		output.append(target_class.new(entry))
	return output


static func color_to_hex(color: Color) -> String:
	"""
	Converts a Color object to a hex string (e.g., "#FFA500").
	Alpha is ignored unless needed.
	"""
	var r = int(round(color.r * 255))
	var g = int(round(color.g * 255))
	var b = int(round(color.b * 255))
	return "#%02X%02X%02X" % [r, g, b]


static func hex_to_color(hex: String) -> Color:
	"""
	Converts a hex string (e.g., "#ffa500") to a Color object.
	Supports lowercase or uppercase, but expects exactly 6 hex digits.
	"""
	if hex.begins_with("#") and hex.length() == 7:
		var r = hex.substr(1, 2).hex_to_int() / 255.0
		var g = hex.substr(3, 2).hex_to_int() / 255.0
		var b = hex.substr(5, 2).hex_to_int() / 255.0
		return Color(r, g, b, 1.0)
	return Color.WHITE


static func string_to_enum(enum_type: Dictionary, value: String):
	"""Converts a string to an enum value if it exists."""
	var enum_key = value.to_upper()
	if enum_key in enum_type.keys():
		return enum_type[enum_key]
	return null


static func enum_to_string(enum_type: Dictionary, value: int):
	"""Converts a string to an enum value if it exists."""
	if value < enum_type.keys().size():
		return enum_type.keys()[value].to_upper()
	return null


static func strings_to_enums(enum_type: Dictionary, values: Array) -> Array:
	"""
	Converts an array of strings to an array of corresponding enum values.
	Invalid or unmatched strings are filtered out.
	"""
	var result: Array = []
	for value in values:
		var enum_value = string_to_enum(enum_type, str(value))
		if enum_value != null:
			result.append(enum_value)
	return result


static func enums_to_strings(enum_type: Dictionary, values: Array) -> Array:
	"""
	Converts an array of enum values to an array of corresponding enum names as uppercase strings.
	Invalid enum values are filtered out.
	"""
	var result: Array = []
	for value in values:
		var str_value = enum_to_string(enum_type, int(value))
		if str_value != null:
			result.append(str_value)
	return result


static func serialize_matrix(matrix: Array, width: int, height: int) -> Dictionary:
	"""
	Serializes a 2D terrain matrix into a Dictionary with compressed and base64-encoded binary data.
	Assumes each value in the matrix is an integer from 0 to 255.
	Returns a dictionary with 'width', 'height', 'original_size', and 'data' fields.
	"""
	var flat_data = PackedByteArray()
	for row in matrix:
		for value in row:
			flat_data.append(value)
	var compressed = flat_data.compress(FileAccess.COMPRESSION_ZSTD)
	var encoded = Marshalls.raw_to_base64(compressed)
	return {"width": width, "height": height, "original_size": flat_data.size(), "data": encoded}


static func deserialize_matrix(data: Dictionary) -> Array:
	"""
	Deserializes a Dictionary containing compressed and
	base64-encoded terrain data back into a 2D matrix.
	Expects keys: 'width', 'height', 'original_size', and 'data'.
	Returns a 2D array of integers.
	"""
	var width = data.get("width", 0)
	var height = data.get("height", 0)
	var original_size = data.get("original_size", 0)
	var compressed = Marshalls.base64_to_raw(data.get("data", ""))
	var raw = compressed.decompress(original_size, FileAccess.COMPRESSION_ZSTD)
	var matrix = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(raw[y * width + x])
		matrix.append(row)
	return matrix
