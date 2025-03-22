extends Node

class_name Enums

# Game difficulty levels
enum MapDifficulty {
	NOVICE      = 0, # Entry-level, forgiving challenges
	CADET       = 1, # Beginner-friendly with slightly increased difficulty
	CHALLENGING = 2, # Provides a moderate level of challenge
	VETERAN     = 3, # A tougher experience for skilled players
	ELITE       = 4, # High difficulty with stronger enemies and tactics
	LEGENDARY   = 5  # The toughest challenge, only for the most experienced players
}

# Discrete size classes.
enum MekSize {
	LIGHT    = 0, # Fast, agile, lower durability
	MEDIUM   = 1, # Balanced performance
	HEAVY    = 2, # High durability, slower movement
	COLOSSAL = 3  # Super-heavy, extreme durability, slowest movement
}

# Standardized slot types
enum SlotType {
	SMALL   = 0,
	MEDIUM  = 1,
	LARGE   = 2,
	UTILITY = 3
}

# Defines various damage types and their general strengths/weaknesses.
enum DamageType {
	KINETIC   = 0, # Effective against armor, weak against shields.
	ENERGY    = 1, # Effective against shields, weak against armor.
	EXPLOSIVE = 2, # Strong against armor & health, weak against shields.
	PLASMA    = 3, # Melts through armor & shields, weaker against health.
	CORROSIVE = 4  # Slowly depletes armor & health, weak against shields.
}

# The type of effects.
enum EffectType {
	DAMAGE,             # Deals direct damage.
	DAMAGE_OVER_TIME,   # Damage applied over time.
	# Repairs.
	HEALTH_REPAIR,      # Restores health.
	SHIELD_REPAIR,      # Restores shield.
	ARMOR_REPAIR,       # Restores armor.
	# Total boosts.
	HEALTH_MODIFIER,    # Increases/Decreases total health.
	SHIELD_MODIFIER,    # Increases/Decreases total shield.
	ARMOR_MODIFIER,     # Increases/Decreases total armor.
	POWER_MODIFIER,     # Increases/Decreases total power.
	SPEED_MODIFIER,     # Increases/Decreases total speed.
	# Attack modifiers.
	ACCURACY_MODIFIER,  # Increases/Decreases total accuracy.
	RANGE_MODIFIER,     # Increases/Decreases weapons range.
	COOLDOWN_MODIFIER,  # Increases/Decreases weapons cooldown.
	# Regen boosts.
	SHIELD_REGEN,       # Increases shield regen.
	ARMOR_REGEN,        # Increases armor regen.
	POWER_REGEN,        # Increases power regen.
	# Damage reductions.
	DAMAGE_REDUCTION_ALL,       # Decreases incoming damage.
	DAMAGE_REDUCTION_KINETIC,   # Decreases incoming KINETIC damage.
	DAMAGE_REDUCTION_ENERGY,    # Decreases incoming ENERGY damage.
	DAMAGE_REDUCTION_EXPLOSIVE, # Decreases incoming EXPLOSIVE damage.
	DAMAGE_REDUCTION_PLASMA,    # Decreases incoming PLASMA damage.
	DAMAGE_REDUCTION_CORROSIVE, # Decreases incoming CORROSIVE damage.
}

# The type of target.
enum TargetType {
	ENEMY,    # The effect targets an enemy.
	SELF,     # The effect targets the user, can be positive or negative.
	ALLY,     # The effect targets an ally, can be positive or negative.
	AREA      # The effect targets all entities in a radius.
}

# Types of combat log.
enum LogType {
	ATTACK   = 0, # Use attack module
	SUPPORT  = 1, # Use support module. 
	MOVEMENT = 2, # Move.
	CHAT     = 3, # Player or NPC chat.
	SYSTEM   = 4, # System messages.
	AI       = 5,
}
