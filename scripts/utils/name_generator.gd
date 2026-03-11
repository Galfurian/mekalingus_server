extends Node

# Simple random name generator.  Loads lists of first/last names from text files
# (one name per line) and provides helper functions.  Falls back to a tiny hard-
# coded set if the files are missing, and caches the lists on first access so
# memory usage is minimal.

class_name NameGenerator

# Paths are relative to the project.  Using plain text keeps disk/memory cost
# very small and supports arbitrary UTF-8 characters in the names.
const FIRST_NAMES_PATH := "res://data/names/first_names.txt"
const LAST_NAMES_PATH := "res://data/names/last_names.txt"

# cached arrays; populated lazily
static var _first_names: Array = []
static var _last_names: Array = []

static func _load_list(path: String, out_list: Array) -> void:
	# Clear the list first in case of reload, but only load if the file exists.
	out_list.clear()
	# If the file doesn't exist, we'll just end up with an empty list and fallback to hardcoded names.
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			if line != "":
				out_list.append(line)
		f.close()

static func _ensure_loaded() -> void:
	_load_list(FIRST_NAMES_PATH, _first_names)
	_load_list(LAST_NAMES_PATH, _last_names)

static func random_first_name() -> String:
	_ensure_loaded()
	if _first_names.is_empty():
		return ""
	return _first_names[randi() % _first_names.size()]

static func random_last_name() -> String:
	_ensure_loaded()
	if _last_names.is_empty():
		return ""
	return _last_names[randi() % _last_names.size()]

static func random_full_name() -> String:
	return "%s %s" % [random_first_name(), random_last_name()]
