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

static func apply_damage(damage_type: Enums.DamageType, base_damage: int, target: Mek):
	"""Applies damage to a target Mek using the correct modifiers."""
	var remaining_damage = base_damage
	
	# Apply damage to shields first
	if target.shield > 0:
		var shield_damage = remaining_damage * get_modifier(damage_type, "shield")
		target.shield -= shield_damage
		remaining_damage -= shield_damage
		if remaining_damage <= 0:
			return  # Shield absorbed all damage

	# Apply damage to armor next
	if target.armor > 0:
		var armor_damage = remaining_damage * get_modifier(damage_type, "armor")
		target.armor -= armor_damage
		remaining_damage -= armor_damage
		if remaining_damage <= 0:
			return  # Armor absorbed all damage

	# Finally, apply remaining damage to health
	var health_damage = remaining_damage * get_modifier(damage_type, "health")
	target.health -= health_damage
