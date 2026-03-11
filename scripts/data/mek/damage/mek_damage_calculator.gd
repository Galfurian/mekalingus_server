class_name MekDamageCalculator
extends RefCounted


static func take_damage_from_effect(mek: Mek, effect: ItemEffect) -> Dictionary:
	"""
	Applies damage from a given effect, using resistances and damage-type-specific strengths/weaknesses.
	"""
	var result = {
		"shield": 0,
		"armor": 0,
		"health": 0,
		"total": 0,
		"raw": effect.amount,
		"reduced": 0,
		"type": effect.damage_type
	}

	# =========================================================================
	# 1. DAMAGE MODIFIERS BY DAMAGE TYPE (strengths/weaknesses per layer)
	# =========================================================================
	const TYPE_MODIFIERS = {
		Enums.DamageType.KINETIC: {"armor": 0.8, "shield": 0.6, "health": 1.0},
		Enums.DamageType.ENERGY: {"armor": 0.6, "shield": 1.5, "health": 1.0},
		Enums.DamageType.PLASMA: {"armor": 1.2, "shield": 1.2, "health": 0.9},
		Enums.DamageType.EXPLOSIVE: {"armor": 1.3, "shield": 0.7, "health": 1.3},
		Enums.DamageType.CORROSIVE: {"armor": 1.3, "shield": 0.6, "health": 1.2}
	}
	var modifiers = TYPE_MODIFIERS.get(
		effect.damage_type, {"shield": 1.0, "armor": 1.0, "health": 1.0}
	)

	# =========================================================================
	# 2. APPLY FLAT DAMAGE REDUCTION
	# =========================================================================
	var reduction = max(0, mek.damage_reduction_all)
	match effect.damage_type:
		Enums.DamageType.KINETIC:
			reduction += max(0, mek.damage_reduction_kinetic)
		Enums.DamageType.ENERGY:
			reduction += max(0, mek.damage_reduction_energy)
		Enums.DamageType.EXPLOSIVE:
			reduction += max(0, mek.damage_reduction_explosive)
		Enums.DamageType.PLASMA:
			reduction += max(0, mek.damage_reduction_plasma)
		Enums.DamageType.CORROSIVE:
			reduction += max(0, mek.damage_reduction_corrosive)
	var adjusted = max(effect.amount - reduction, 0)
	result.reduced = effect.amount - adjusted
	var remaining = adjusted

	# =========================================================================
	# 3. APPLY DAMAGE TO SHIELD
	# =========================================================================
	if mek.shield > 0:
		var scaled = int(round(remaining * modifiers.shield))
		scaled = min(scaled, mek.shield)
		mek.adjust_shield(-scaled)
		remaining -= scaled / modifiers.shield
		result.shield = scaled

	# =========================================================================
	# 4. APPLY DAMAGE TO ARMOR
	# =========================================================================
	if mek.armor > 0 and remaining > 0:
		var raw = min(remaining, mek.armor / modifiers.armor)
		var scaled = int(round(raw * modifiers.armor))
		mek.adjust_armor(-scaled)
		remaining -= raw
		result.armor = scaled

	# =========================================================================
	# 5. APPLY DAMAGE TO HEALTH
	# =========================================================================
	if remaining > 0:
		var scaled = int(round(remaining * modifiers.health))
		mek.adjust_health(-scaled)
		result.health = scaled

	# =========================================================================
	# 6. FINAL TALLY
	# =========================================================================
	result.total = result.shield + result.armor + result.health
	return result


static func take_dot_damage(mek: Mek) -> Dictionary:
	"""
	Applies all active DOT effects using resistances and returns a breakdown.
	"""
	var total_damage = {"shield": 0, "armor": 0, "health": 0, "total": 0}
	for dot in mek.active_effect_manager.get_dot_effects():
		var damage = take_damage_from_effect(mek, dot.effect)
		total_damage.shield += damage.shield
		total_damage.armor += damage.armor
		total_damage.health += damage.health
		total_damage.total += damage.total
	return total_damage
