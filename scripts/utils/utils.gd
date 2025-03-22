extends Node

class_name Utils

static func to_array_int(array: Array) -> Array[int]:
	var output: Array[int] = []
	for entry in array:
		output.append(int(entry))
	return output

# Convert a list of objects with `to_dict()` into a list of dictionaries
static func convert_objects_to_client_dict(list: Array[Variant]) -> Array:
	var output = []
	for entry in list:
		if entry.has_method("to_client_dict"):
			output.append(entry.to_client_dict())
		else:
			GameServer.log_message("Object does not implement to_client_dict()")
	return output

# Convert a list of objects with `to_dict()` into a list of dictionaries
static func convert_objects_to_dict(list: Array[Variant]) -> Array:
	var output = []
	for entry in list:
		if entry.has_method("to_dict"):
			output.append(entry.to_dict())
		else:
			GameServer.log_message("Object does not implement to_dict()")
	return output

# Convert a list of dictionaries back into objects of the specified class
static func convert_from_list_dict(list: Array, target_class: GDScript) -> Array:
	var output = []
	for entry in list:
		output.append(target_class.new(entry))
	return output

# Converts a string to an enum value if it exists
static func string_to_enum(enum_type: Dictionary, value: String):
	var enum_key = value.to_upper()
	if enum_key in enum_type.keys():
		return enum_type[enum_key]
	else:
		GameServer.log_message("Unknown enum value: " + value)
		return null

# Converts a string to an enum value if it exists
static func enum_to_string(enum_type: Dictionary, value: int):
	if value < enum_type.keys().size():
		return enum_type.keys()[value].to_upper()
	else:
		GameServer.log_message("Unknown enum value: " + str(value))
		return null
