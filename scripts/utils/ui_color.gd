extends Node

# =============================================================================
# MEK STAT COLORS
# =============================================================================

# Default color - Used when no specific color is assigned.
const DEFAULT = "#FFFFFF"

# Health color - Represents Mek health (red-orange).
const HEALTH = "#FF5733"

# Armor color - Represents Mek armor (steel blue).
const ARMOR = "#4682B4"

# Armor regeneration color - Represents armor recovery rate.
const ARMOR_GENERATION = "#66A2D4"

# Shield color - Represents energy shields (turquoise).
const SHIELD = "#00CED1"

# Shield regeneration color - Represents shield recovery rate (light blue).
const SHIELD_GENERATION = "#87CEFA"

# Power color - Represents energy capacity (orange).
const POWER = "#FFA500"

# Power generation color - Represents energy regen rate (lime green).
const POWER_GENERATION = "#32CD32"

# Speed color - Represents Mek movement speed (gold).
const SPEED = "#FFD700"

# =============================================================================
# ITEM STAT COLORS
# =============================================================================

# Slot type color - Indicates the slot category of an item (gold).
const SLOT_TYPE = "#FFD700"

# Damage color - Represents the raw damage output of an item (red).
const DAMAGE = "#FF4500"

# Range color - Indicates the attack range of an item (green).
const RANGE = "#32CD32"

# Energy cost color - Represents power consumption for using an item (orange).
const ENERGY_COST = "#FFA500"

# Damage type color - Indicates the type of damage inflicted (dodger blue).
const DAMAGE_TYPE = "#1E90FF"

# Power on use color - Represents additional power required when activating an item (deep orange).
const POWER_ON_USE = "#FF8C00"

# Cooldown color - Represents cooldown time before an item can be used again (light gray).
const COOLDOWN = "#D3D3D3"

# =============================================================================
# EFFECT STAT COLORS
# =============================================================================

# Effect type color - Represents different effect categories (purple).
const EFFECT_TYPE = "#8A2BE2"

# Target type color - Represents who the effect is applied to (cyan).
const EFFECT_TARGET_TYPE = "#00FFFF"

# Effect amount color - Represents the magnitude of the effect (light coral).
const EFFECT_AMOUNT = "#F08080"

# Effect duration color - Represents how long an effect lasts (dark orange).
const EFFECT_DURATION = "#FF8C00"

# Effect chance color - Represents the probability of an effect occurring (goldenrod).
const EFFECT_CHANCE = "#DAA520"

# Effect radius color - Represents the area of effect (sky blue).
const EFFECT_RADIUS = "#87CEEB"

# Passive effect color - Highlights always-on effects (spring green).
const EFFECT_PASSIVE = "#00FA9A"

# Center on target color - Indicates if the effect is centered on the target (medium orchid).
const EFFECT_CENTER_ON_TARGET = "#BA55D3"

# =============================================================================
# COLOR MAPPING
# =============================================================================

# Dictionary mapping stat keys to corresponding colors.
const COLORS = {
	"default": DEFAULT,
	"health": HEALTH,
	"armor": ARMOR,
	"armor_generation": ARMOR_GENERATION,
	"shield": SHIELD,
	"shield_generation": SHIELD_GENERATION,
	"power": POWER,
	"power_generation": POWER_GENERATION,
	"speed": SPEED,
	"slot": SLOT_TYPE,
	"damage": DAMAGE,
	"module_range": RANGE,
	"energy_cost": ENERGY_COST,
	"damage_type": DAMAGE_TYPE,
	"power_on_use": POWER_ON_USE,
	"cooldown": COOLDOWN,
	"effect_type": EFFECT_TYPE,
	"effect_target_type": EFFECT_TARGET_TYPE,
	"effect_amount": EFFECT_AMOUNT,
	"effect_duration": EFFECT_DURATION,
	"effect_chance": EFFECT_CHANCE,
	"effect_radius": EFFECT_RADIUS,
	"effect_passive": EFFECT_PASSIVE,
	"effect_center_on_target": EFFECT_CENTER_ON_TARGET,
}

# =============================================================================
# UTILITY FUNCTION
# =============================================================================

func apply(key: String, value: Variant) -> String:
	"""Applies the appropriate color formatting to a given value based on the key."""
	return "[color=" + COLORS.get(key, DEFAULT) + "]" + str(value) + "[/color]"
