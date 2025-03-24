extends RefCounted

class_name DamageModifiers

# =============================================================================
# DAMAGE MODIFIER TABLE
# =============================================================================
# Defines how different damage types interact with armor, shields, and health.

const DAMAGE_MODIFIERS = {
	Enums.DamageType.KINETIC: {
		"armor": 0.8,
		"shield": 0.6,
		"health": 1.0
	},
	Enums.DamageType.ENERGY: {
		"armor": 0.6,
		"shield": 1.5,
		"health": 1.0
	},
	Enums.DamageType.PLASMA: {
		"armor": 1.2,
		"shield": 1.2,
		"health": 0.9
	},
	Enums.DamageType.EXPLOSIVE: {
		"armor": 1.3,
		"shield": 0.7,
		"health": 1.3
	},
	Enums.DamageType.CORROSIVE: {
		"armor": 1.3,
		"shield": 0.6,
		"health": 1.2
	}
}

# =============================================================================
# MODIFIER RETRIEVAL FUNCTIONS
# =============================================================================

static func get_modifier(damage_type: Enums.DamageType, target_type: String) -> float:
	"""Returns the damage modifier for a given damage type and target type (armor, shield, health)."""
	if DAMAGE_MODIFIERS.has(damage_type) and DAMAGE_MODIFIERS[damage_type].has(target_type):
		return DAMAGE_MODIFIERS[damage_type][target_type]
	
	# Default modifier if the type is not found (shouldn't happen)
	return 1.0

static func apply_effect_damage(effect: ItemEffect, target: Mek) -> Dictionary:
	"""Applies damage from an effect to a Mek, with resistances and layer modifiers."""
	var result = {
		"shield": 0,
		"armor": 0,
		"health": 0,
		"total": 0,
		"raw": effect.amount,
		"reduced": 0,
		"type": effect.damage_type
	}

	# Base damage reduction
	var reduction = target.damage_reduction_all
	match effect.damage_type:
		Enums.DamageType.KINETIC:   reduction += target.damage_reduction_kinetic
		Enums.DamageType.ENERGY:    reduction += target.damage_reduction_energy
		Enums.DamageType.EXPLOSIVE: reduction += target.damage_reduction_explosive
		Enums.DamageType.PLASMA:    reduction += target.damage_reduction_plasma
		Enums.DamageType.CORROSIVE: reduction += target.damage_reduction_corrosive

	# Final clamped damage
	var final_damage = max(effect.amount - reduction, 0)
	result.reduced = effect.amount - final_damage
	var remaining = final_damage

	# Shield
	if target.shield > 0:
		var mod = get_modifier(effect.damage_type, "shield")
		var applied = min(remaining * mod, target.shield)
		target.shield -= applied
		remaining -= applied / mod
		result.shield = applied

	# Armor
	if target.armor > 0 and remaining > 0:
		var mod = get_modifier(effect.damage_type, "armor")
		var applied = min(remaining * mod, target.armor)
		target.armor -= applied
		remaining -= applied / mod
		result.armor = applied

	# Health
	if remaining > 0:
		var mod = get_modifier(effect.damage_type, "health")
		var applied = remaining * mod
		target.health -= applied
		result.health = applied

	result.total = result.shield + result.armor + result.health
	return result
