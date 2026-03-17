# Class that represents a Clan in the game. Clans are used to group players and
# AI together, and to define their behavior and restrictions.
class_name Clan
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# -------------------------------------
# CORE
# -------------------------------------

# Unique identifier for the clan.
var id: String
# Name of the clan.
var clan_name: String
# Description of the clan.
var description: String
# Color of the clan.
var color: Color
# Path to the emblem of the clan.
var emblem_path: String
# List of allied clans.
var allies: Array

# Tactical doctrine profile path used by AI-controlled members of this clan.
var ai_profile_path: String = ""

# -------------------------------------
# PLAYER INTEGRATION
# -------------------------------------

# Whether players can join this clan.
var is_player_joinable: bool = true

# =============================================================================
# METHODS
# =============================================================================


func _init(data: Dictionary = {}) -> void:
	if data:
		from_dict(data)


func _finalize():
	print("Clan is being freed.")


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	return "<clan: " + clan_name + " (" + id + ")>"


static func from_dict(data: Dictionary) -> Clan:
	"""Loads clan data from a dictionary."""
	var clan = Clan.new()
	clan.id = data["id"]
	clan.clan_name = data["name"]
	clan.description = data["description"]
	clan.color = Utils.hex_to_color(data["color"])
	clan.emblem_path = data.get("emblem_path", "")
	clan.ai_profile_path = data.get("ai_profile_path", "")
	clan.is_player_joinable = data.get("is_player_joinable", true)
	clan.allies = data.get("allies", [])
	return clan


func to_dict() -> Dictionary:
	"""Converts item instance data to a dictionary."""
	return {
		"id": id,
		"name": clan_name,
		"description": description,
		"color": Utils.color_to_hex(color),
		"emblem_path": emblem_path,
		"ai_profile_path": ai_profile_path,
		"is_player_joinable": is_player_joinable,
		"allies": allies,
	}
