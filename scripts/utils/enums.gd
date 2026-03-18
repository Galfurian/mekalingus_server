# Defines various enums used throughout the game.
class_name Enums
extends Node

# The type of game mode.
enum GameMode {
	FFA,  # Free-for-all, every player/NPC for themselves.
	COOP,  # Players versus AI-controlled enemies.
	TEAM,  # Teams of NPCs and Players versus each other.
	CLAN_WAR,  # Use clan logic exclusively
}

# Defines the entity size categories, which can influence stats and behavior.
enum EntitySize {
	LIGHT = 0,
	MEDIUM = 1,
	HEAVY = 2,
	COLOSSAL = 3,
}

# Defines the types of slots available on a mek.
enum SlotType {
	SMALL = 0,
	MEDIUM = 1,
	LARGE = 2,
	UTILITY = 3,
}

# Defines various damage types and their general strengths/weaknesses.
enum DamageType {
	KINETIC = 0,  # Effective against armor, weak against shields.
	ENERGY = 1,  # Effective against shields, weak against armor.
	EXPLOSIVE = 2,  # Strong against armor & health, weak against shields.
	PLASMA = 3,  # Melts through armor & shields, weaker against health.
	CORROSIVE = 4,  # Slowly depletes armor & health, weak against shields.
}

# Canonical combat stat identifiers.
enum StatType {
	HEALTH,
	ARMOR,
	SHIELD,
	POWER,
	MAX_HEALTH,
	MAX_ARMOR,
	MAX_SHIELD,
	MAX_POWER,
	HEALTH_REGEN,
	ARMOR_REGEN,
	SHIELD_REGEN,
	POWER_REGEN,
	SPEED,
	SENSOR_RANGE,
	DAMAGE_REDUCTION_ALL,
	DAMAGE_REDUCTION_KINETIC,
	DAMAGE_REDUCTION_ENERGY,
	DAMAGE_REDUCTION_EXPLOSIVE,
	DAMAGE_REDUCTION_PLASMA,
	DAMAGE_REDUCTION_CORROSIVE,
	ACCURACY_MODIFIER,
	RANGE_MODIFIER,
	COOLDOWN_MODIFIER,
}


static func get_stat_types() -> Array[int]:
	var stat_types: Array[int] = []
	for value in StatType.values():
		stat_types.append(int(value))
	return stat_types


static func get_stat_key(stat_type: int) -> String:
	match stat_type:
		StatType.HEALTH:
			return "health"
		StatType.ARMOR:
			return "armor"
		StatType.SHIELD:
			return "shield"
		StatType.POWER:
			return "power"
		StatType.MAX_HEALTH:
			return "max_health"
		StatType.MAX_ARMOR:
			return "max_armor"
		StatType.MAX_SHIELD:
			return "max_shield"
		StatType.MAX_POWER:
			return "max_power"
		# Keep payload wire keys as *_generation for backward compatibility.
		StatType.HEALTH_REGEN:
			return "health_generation"
		StatType.ARMOR_REGEN:
			return "armor_generation"
		StatType.SHIELD_REGEN:
			return "shield_generation"
		StatType.POWER_REGEN:
			return "power_generation"
		StatType.SPEED:
			return "speed"
		StatType.DAMAGE_REDUCTION_ALL:
			return "damage_reduction_all"
		StatType.DAMAGE_REDUCTION_KINETIC:
			return "damage_reduction_kinetic"
		StatType.DAMAGE_REDUCTION_ENERGY:
			return "damage_reduction_energy"
		StatType.DAMAGE_REDUCTION_EXPLOSIVE:
			return "damage_reduction_explosive"
		StatType.DAMAGE_REDUCTION_PLASMA:
			return "damage_reduction_plasma"
		StatType.DAMAGE_REDUCTION_CORROSIVE:
			return "damage_reduction_corrosive"
		StatType.ACCURACY_MODIFIER:
			return "accuracy_modifier"
		StatType.RANGE_MODIFIER:
			return "range_modifier"
		StatType.COOLDOWN_MODIFIER:
			return "cooldown_modifier"
		_:
			return "unknown"


static func get_stat_type_from_key(stat_key: String) -> int:
	match stat_key:
		"health":
			return StatType.HEALTH
		"armor":
			return StatType.ARMOR
		"shield":
			return StatType.SHIELD
		"power":
			return StatType.POWER
		"max_health":
			return StatType.MAX_HEALTH
		"max_armor":
			return StatType.MAX_ARMOR
		"max_shield":
			return StatType.MAX_SHIELD
		"max_power":
			return StatType.MAX_POWER
		"health_generation":
			return StatType.HEALTH_REGEN
		"armor_generation":
			return StatType.ARMOR_REGEN
		"shield_generation":
			return StatType.SHIELD_REGEN
		"power_generation":
			return StatType.POWER_REGEN
		"speed":
			return StatType.SPEED
		"damage_reduction_all":
			return StatType.DAMAGE_REDUCTION_ALL
		"damage_reduction_kinetic":
			return StatType.DAMAGE_REDUCTION_KINETIC
		"damage_reduction_energy":
			return StatType.DAMAGE_REDUCTION_ENERGY
		"damage_reduction_explosive":
			return StatType.DAMAGE_REDUCTION_EXPLOSIVE
		"damage_reduction_plasma":
			return StatType.DAMAGE_REDUCTION_PLASMA
		"damage_reduction_corrosive":
			return StatType.DAMAGE_REDUCTION_CORROSIVE
		"accuracy_modifier":
			return StatType.ACCURACY_MODIFIER
		"range_modifier":
			return StatType.RANGE_MODIFIER
		"cooldown_modifier":
			return StatType.COOLDOWN_MODIFIER
		_:
			return -1


static func is_modifier_stat(stat_type: int) -> bool:
	return (
		stat_type == StatType.DAMAGE_REDUCTION_ALL
		or stat_type == StatType.DAMAGE_REDUCTION_KINETIC
		or stat_type == StatType.DAMAGE_REDUCTION_ENERGY
		or stat_type == StatType.DAMAGE_REDUCTION_EXPLOSIVE
		or stat_type == StatType.DAMAGE_REDUCTION_PLASMA
		or stat_type == StatType.DAMAGE_REDUCTION_CORROSIVE
		or stat_type == StatType.ACCURACY_MODIFIER
		or stat_type == StatType.RANGE_MODIFIER
		or stat_type == StatType.COOLDOWN_MODIFIER
	)

# The type of effects.
enum EffectType {
	DAMAGE,  # Deals direct damage.
	DAMAGE_OVER_TIME,  # Damage applied over time.
	# Repairs.
	HEALTH_REPAIR,  # Restores health.
	SHIELD_REPAIR,  # Restores shield.
	ARMOR_REPAIR,  # Restores armor.
	# Total boosts.
	HEALTH_MODIFIER,  # Increases/Decreases total health.
	SHIELD_MODIFIER,  # Increases/Decreases total shield.
	ARMOR_MODIFIER,  # Increases/Decreases total armor.
	POWER_MODIFIER,  # Increases/Decreases total power.
	SPEED_MODIFIER,  # Increases/Decreases total speed.
	# Attack modifiers.
	ACCURACY_MODIFIER,  # Increases/Decreases total accuracy.
	RANGE_MODIFIER,  # Increases/Decreases weapons range.
	COOLDOWN_MODIFIER,  # Increases/Decreases weapons cooldown.
	# Regen boosts.
	HEALTH_REGEN,  # Increases health regen.
	SHIELD_REGEN,  # Increases shield regen.
	ARMOR_REGEN,  # Increases armor regen.
	POWER_REGEN,  # Increases power regen.
	# Damage reductions.
	DAMAGE_REDUCTION_ALL,  # Decreases incoming damage.
	DAMAGE_REDUCTION_KINETIC,  # Decreases incoming KINETIC damage.
	DAMAGE_REDUCTION_ENERGY,  # Decreases incoming ENERGY damage.
	DAMAGE_REDUCTION_EXPLOSIVE,  # Decreases incoming EXPLOSIVE damage.
	DAMAGE_REDUCTION_PLASMA,  # Decreases incoming PLASMA damage.
	DAMAGE_REDUCTION_CORROSIVE,  # Decreases incoming CORROSIVE damage.
}

# The type of target.
enum TargetType {
	ENEMY,  # The effect targets an enemy.
	SELF,  # The effect targets the user, can be positive or negative.
	ALLY,  # The effect targets an ally, can be positive or negative.
	AREA,  # The effect targets all entities in a radius.
}

# Types of combat log.
enum LogType {
	NONE,
	ATTACK,  # Use attack module
	SUPPORT,  # Use support module.
	MOVEMENT,  # Move.
	CHAT,  # Player or NPC chat.
	SYSTEM,  # System messages.
	AI,  # AI messages.
}

# Describes different combat roles a Mek can be built for.
enum MekRole {
	BRAWLER,
	SNIPER,
	ARTILLERY,
	SUPPORT,
}

# Global behavior directives used by AI squads.
enum NpcDirective {
	HOLD_PERIMETER,
	PATROL,
}
