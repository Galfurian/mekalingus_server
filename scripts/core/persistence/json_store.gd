class_name JsonStore
extends RefCounted


static func ensure_directory(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir and dir.dir_exists(path):
		return true

	dir = DirAccess.open("user://")
	if not dir:
		return false

	return dir.make_dir_recursive(path) == OK


static func write_json_file(file_path: String, data, indent: String = "") -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(JSON.stringify(data, indent))
	file.close()
	return true


static func read_json_file(file_path: String):
	if not FileAccess.file_exists(file_path):
		return null

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null

	var json_string = file.get_as_text()
	file.close()
	return JSON.parse_string(json_string)


static func delete_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	return DirAccess.remove_absolute(file_path) == OK


static func list_json_basenames(folder_path: String) -> Array[String]:
	var basenames: Array[String] = []
	var dir = DirAccess.open(folder_path)
	if not dir or not dir.dir_exists(folder_path):
		return basenames

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			basenames.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	return basenames