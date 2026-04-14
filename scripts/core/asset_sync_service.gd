extends Node


const ASSET_ROOT := "res://assets"
const ASSET_ROOT_PREFIX := "assets/"
const DEFAULT_CHUNK_SIZE := 65_536
const MAX_CHUNK_SIZE := 262_144


var _manifest_revision: int = 0
var _manifest_files: Array[Dictionary] = []
var _manifest_index: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	refresh_manifest()


func refresh_manifest() -> void:
	_manifest_files.clear()
	_manifest_index.clear()

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ASSET_ROOT)):
		_manifest_revision = int(Time.get_unix_time_from_system())
		return

	_scan_directory(ASSET_ROOT)
	_manifest_files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)

	for entry in _manifest_files:
		_manifest_index[str(entry.get("path", ""))] = entry

	_manifest_revision = int(Time.get_unix_time_from_system())
	print("Asset sync manifest ready. Files: " + str(_manifest_files.size()))


func build_manifest_payload() -> Dictionary:
	return {
		"schema_version": "1.0.0",
		"manifest_revision": _manifest_revision,
		"files": _manifest_files.duplicate(true),
	}


func build_chunk_payload(asset_path: String, offset: int, requested_chunk_size: int) -> Dictionary:
	if not _is_valid_asset_path(asset_path):
		return {}

	if not _manifest_index.has(asset_path):
		return {}

	var entry: Dictionary = _manifest_index[asset_path]
	var total_size: int = int(entry.get("size", 0))
	if total_size < 0 or offset < 0 or offset > total_size:
		return {}

	var chunk_size: int = int(clamp(requested_chunk_size, 1, MAX_CHUNK_SIZE))
	if chunk_size <= 0:
		chunk_size = DEFAULT_CHUNK_SIZE

	var file_path := "res://" + asset_path
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	file.seek(offset)
	var remaining := total_size - offset
	var read_size: int = int(min(chunk_size, remaining))
	var chunk_data := file.get_buffer(read_size)
	file.close()

	var next_offset := offset + chunk_data.size()
	return {
		"path": asset_path,
		"offset": offset,
		"next_offset": next_offset,
		"total_size": total_size,
		"is_last": next_offset >= total_size,
		"sha256": str(entry.get("sha256", "")),
		"data_base64": Marshalls.raw_to_base64(chunk_data),
		"manifest_revision": _manifest_revision,
	}


func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break

		if entry_name == "." or entry_name == "..":
			continue

		var absolute_path := dir_path + "/" + entry_name
		if dir.current_is_dir():
			_scan_directory(absolute_path)
			continue

		if _should_skip_file(entry_name):
			continue

		_register_file(absolute_path)

	dir.list_dir_end()


func _register_file(file_path: String) -> void:
	var relative_path := file_path.trim_prefix("res://")
	if not _is_valid_asset_path(relative_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)

	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		var read_size: int = int(min(remaining, DEFAULT_CHUNK_SIZE))
		var chunk := file.get_buffer(read_size)
		if chunk.is_empty() and read_size > 0:
			break
		hasher.update(chunk)

	var size := file.get_length()
	file.close()

	_manifest_files.append(
		{
			"path": relative_path,
			"size": size,
			"sha256": hasher.finish().hex_encode(),
		}
	)


func _is_valid_asset_path(path: String) -> bool:
	if path.is_empty():
		return false
	if ".." in path:
		return false
	if path.begins_with("/"):
		return false
	return path.begins_with(ASSET_ROOT_PREFIX)


func _should_skip_file(file_name: String) -> bool:
	return file_name.ends_with(".import") or file_name.ends_with(".uid")