# This script defines the rules of combat for the game.
class_name CombatRules

# The game mode determines the rules of combat.
var game_mode: Enums.GameMode
# Whether players can attack each other.
var pvp_enabled: bool = false
# Whether NPCs can attack each other.
var npc_friendly_fire: bool = false
# Whether NPCs are hostile to players.
var player_npc_hostile: bool = true


func _init(mode: Enums.GameMode = Enums.GameMode.FFA) -> void:
	"""
	Initializes the combat rules with the given game mode.
	"""
	game_mode = mode
	match game_mode:
		Enums.GameMode.FFA:
			pvp_enabled = true
			npc_friendly_fire = true
			player_npc_hostile = true
		Enums.GameMode.COOP:
			pvp_enabled = false
			npc_friendly_fire = false
			player_npc_hostile = true
		Enums.GameMode.TEAM:
			pvp_enabled = true
			npc_friendly_fire = false
			player_npc_hostile = true
