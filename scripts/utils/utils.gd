# This class contains a series of utility functions for various tasks such
# as filtering dictionaries, serializing/deserializing positions, converting
# colors to/from hex, and handling enums.

class_name Utils extends Node


static func filter(dictionary: Dictionary, predicate: Callable) -> Array:
	"""
	This function filters a dictionary based on a predicate function.
	The predicate function should take a key and value as arguments and return true or false.
	Returns an array of keys that match the predicate.
	"""
	var result: Array = []
	for key in dictionary:
		if predicate.call(key, dictionary[key]):
			result.append(key)
	return result


static func erase(dictionary: Dictionary, keys: Array) -> void:
	"""
	This function erases keys from a dictionary.
	"""
	for key in keys:
		dictionary.erase(key)


static func serialize_position(position: Vector2i) -> Array:
	"""
	Serializes a Vector2i position into an array of integers.
	"""
	return [position.x, position.y]


static func deserialize_position(array: Array) -> Vector2i:
	"""
	Deserializes an array of integers into a Vector2i position.
	"""
	if array.size() >= 2:
		return Vector2i(array[0], array[1])
	return Vector2i()


static func serialize_dict_of_objects(dict: Dictionary) -> Dictionary:
	"""
	Serializes a dictionary of objects into a dictionary of dictionaries.
	"""
	var result = {}
	for key in dict:
		var obj = dict[key]
		if obj and obj.has_method("to_dict"):
			result[key] = obj.to_dict()
		else:
			push_error("Object at key '%s' does not implement to_dict()" % key)
	return result


static func deserialize_dict_of_objects(data: Dictionary, constructor: Callable) -> Dictionary:
	"""
	Deserializes a dictionary of dictionaries back into objects of the specified class.
	"""
	var result = {}
	for key in data:
		var value = data[key]
		if value:
			result[key] = constructor.call(value)
		else:
			push_error("Value at key '%s' is null or invalid." % key)
	return result


static func to_array_int(array: Array[Variant]) -> Array[int]:
	"""
	Transforms an arbitrary array into an array of integers.
	"""
	var output: Array[int] = []
	for entry in array:
		output.append(int(entry))
	return output


static func convert_objects_to_client_dict(array: Array[Variant]) -> Array[Dictionary]:
	"""
	Convert a array of objects with `to_client_dict()` into a array of dictionaries.
	"""
	var output: Array[Dictionary] = []
	for entry in array:
		if entry.has_method("to_client_dict"):
			output.append(entry.to_client_dict())
		else:
			push_error("Object does not implement to_client_dict() for entry: %s" % str(entry))
	return output


static func convert_objects_to_dict(array: Array[Variant]) -> Array[Dictionary]:
	"""
	Convert a array of objects with `to_dict()` into a array of dictionaries.
	"""
	var output: Array[Dictionary] = []
	for entry in array:
		if entry.has_method("to_dict"):
			output.append(entry.to_dict())
		else:
			push_error("Object does not implement to_dict() for entry: %s" % str(entry))
	return output


static func convert_from_array_dict(array: Array, constructor: Callable) -> Array:
	"""
	Convert an array of dictionaries into an array of objects using a constructor function.
	"""
	var output = []
	if constructor:
		for entry in array:
			output.append(constructor.call(entry))
	return output


static func color_to_hex(color: Color) -> String:
	"""
	Converts a Color object to a hex string, including alpha channel.
	"""
	var r = int(round(color.r * 255))
	var g = int(round(color.g * 255))
	var b = int(round(color.b * 255))
	var a = int(round(color.a * 255))
	return "#%02X%02X%02X%02X" % [r, g, b, a]


static func hex_to_color(hex: String) -> Color:
	"""
	Converts a Color hex string to a Color object.
	"""
	if hex.begins_with("#"):
		if hex.length() == 7:
			var r = hex.substr(1, 2).hex_to_int() / 255.0
			var g = hex.substr(3, 2).hex_to_int() / 255.0
			var b = hex.substr(5, 2).hex_to_int() / 255.0
			return Color(r, g, b, 1.0)
		if hex.length() == 9:
			var r = hex.substr(1, 2).hex_to_int() / 255.0
			var g = hex.substr(3, 2).hex_to_int() / 255.0
			var b = hex.substr(5, 2).hex_to_int() / 255.0
			var a = hex.substr(7, 2).hex_to_int() / 255.0
			return Color(r, g, b, a)
	# Return white as default on error.
	return Color.WHITE


static func string_to_enum(enum_type: Dictionary, value: String) -> Variant:
	"""
	Converts a string to an enum value if it exists.
	"""
	var enum_key = value.to_upper()
	if enum_key in enum_type.keys():
		return enum_type[enum_key]
	return null


static func enum_to_string(enum_type: Dictionary, value: int):
	"""
	Converts a string to an enum value if it exists.
	"""
	if value < enum_type.keys().size():
		return enum_type.keys()[value].to_upper()
	return null


static func strings_to_enums(enum_type: Dictionary, array: Array) -> Array:
	"""
	Converts an array of strings to an array of corresponding enum array.
	Invalid or unmatched strings are filtered out.
	"""
	var result: Array = []
	for value in array:
		var enum_value = string_to_enum(enum_type, str(value))
		if enum_value != null:
			result.append(enum_value)
		else:
			push_error("Invalid enum string: '%s'" % str(value))
			push_error("Enum type  : '%s'" % str(enum_type))
			push_error("Enum keys  : '%s'" % str(enum_type.keys()))
			push_error("Enum values: '%s'" % str(enum_type.values()))
	return result


static func enums_to_strings(enum_type: Dictionary, array: Array) -> Array:
	"""
	Converts an array of enum array to an array of corresponding enum names as uppercase strings.
	Invalid enum array are filtered out.
	"""
	var result: Array = []
	for value in array:
		var string_value = enum_to_string(enum_type, int(value))
		if string_value:
			result.append(string_value)
		else:
			push_error("Invalid enum value: %s" % str(value))
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
