# Class that represents a Clan in the game. Clans are used to group players and
# AI together, and to define their behavior and restrictions.
class_name Clan
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# -------------------------------------
# CORE
# -------------------------------------

# Unique identifier for the clan.
var id: String
# Name of the clan.
var name: String
# Description of the clan.
var description: String
# Color of the clan.
var color: Color
# Path to the emblem of the clan.
var emblem_path: String

# -------------------------------------
# IDENTITY
# -------------------------------------

# The preferred roles for the meks of this clan.
var preferred_roles: Array = []

# -------------------------------------
# AI BEHAVIOR
# -------------------------------------

# How aggressive the AI of this clan is.
var aggressiveness: float = 1.0

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


func generate_clan_starter_meks(count: int = 3) -> Array[Mek]:
	"""
	Generates a set of starter Meks for this clan.
	The Meks will be based on the clan's preferred roles and allowed sizes,
	using NOVICE difficulty power scaling.
	@param count The number of starter Meks to generate (default: 3).
	@return An array of generated Mek instances.
	"""
	var starter_meks: Array[Mek] = []
	for i in count:
		var role: Enums.MekRole = preferred_roles.pick_random()
		var mek: Mek = LoadoutGenerator.generate_mek(Enums.MapDifficulty.NOVICE, role)
		if mek:
			starter_meks.append(mek)
	return starter_meks


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	return "<clan: " + name + " (" + id + ")>"


static func from_dict(data: Dictionary) -> Clan:
	"""Loads clan data from a dictionary."""
	var clan = Clan.new()
	clan.id = data["id"]
	clan.name = data["name"]
	clan.description = data["description"]
	clan.color = Utils.hex_to_color(data["color"])
	clan.emblem_path = data["emblem_path"]
	clan.preferred_roles = Utils.strings_to_enums(Enums.MekRole, data["preferred_roles"])
	clan.aggressiveness = data.get("aggressiveness", 1.0)
	clan.is_player_joinable = data.get("is_player_joinable", true)
	return clan


func to_dict() -> Dictionary:
	"""Converts item instance data to a dictionary."""
	return {
		"id": id,
		"name": name,
		"description": description,
		"color": Utils.color_to_hex(color),
		"emblem_path": emblem_path,
		"preferred_roles": Utils.enums_to_strings(Enums.MekRole, preferred_roles),
		"aggressiveness": aggressiveness,
		"is_player_joinable": is_player_joinable,
	}
