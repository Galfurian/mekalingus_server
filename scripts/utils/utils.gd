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
