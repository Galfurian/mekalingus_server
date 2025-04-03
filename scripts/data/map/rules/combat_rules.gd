# This script defines the rules of combat for the game.
class_name CombatRules

# The game mode determines the rules of combat.
var game_mode: Enums.GameMode

func _init(mode: Enums.GameMode = Enums.GameMode.FFA) -> void:
	# Initialize the game mode.
	game_mode = mode

func can_attack(attacker: EntityOwner, defender: EntityOwner) -> bool:
	# Don’t allow attacking self
	if attacker == defender:
		return false

	# Same clan = cannot attack
	if attacker.clan.id == defender.clan.id:
		return false

	# Allied clans = cannot attack
	if attacker.clan.id in defender.clan.allies or defender.clan.id in attacker.clan.allies:
		return false

	# Otherwise, attack is allowed
	return true
