class_name CombatDamageCalculator
extends RefCounted

const MAX_DAMAGE_REDUCTION_RATIO: float = 0.95


static func take_damage_from_effect(actor, effect: BaseEffect) -> Dictionary:
	"""
	Applies damage from a given effect using actor resistances and damage-type modifiers.
	"""
	var result = {
		"shield": 0,
		"armor": 0,
		"health": 0,
		"total": 0,
		"raw": effect.amount,
		"reduced": 0,
		"type": effect.damage_type,
	}

	const TYPE_MODIFIERS = {
		Enums.DamageType.KINETIC: { "armor": 0.8, "shield": 0.6, "health": 1.0 },
		Enums.DamageType.ENERGY: { "armor": 0.8, "shield": 1.4, "health": 1.0 },
		Enums.DamageType.PLASMA: { "armor": 1.2, "shield": 1.2, "health": 0.9 },
		Enums.DamageType.EXPLOSIVE: { "armor": 1.3, "shield": 0.7, "health": 1.3 },
		Enums.DamageType.CORROSIVE: { "armor": 1.2, "shield": 0.8, "health": 1.1 },
	}
	var modifiers = TYPE_MODIFIERS.get(
		effect.damage_type, { "shield": 1.0, "armor": 1.0, "health": 1.0 }
	)

	var reduction = max(0, actor.damage_reduction_all)
	match effect.damage_type:
		Enums.DamageType.KINETIC:
			reduction += max(0, actor.damage_reduction_kinetic)
		Enums.DamageType.ENERGY:
			reduction += max(0, actor.damage_reduction_energy)
		Enums.DamageType.EXPLOSIVE:
			reduction += max(0, actor.damage_reduction_explosive)
		Enums.DamageType.PLASMA:
			reduction += max(0, actor.damage_reduction_plasma)
		Enums.DamageType.CORROSIVE:
			reduction += max(0, actor.damage_reduction_corrosive)

	var max_reduction: int = int(floor(float(effect.amount) * MAX_DAMAGE_REDUCTION_RATIO))
	reduction = min(reduction, max_reduction)
	var adjusted = max(effect.amount - reduction, 0)
	result.reduced = effect.amount - adjusted
	var remaining = adjusted

	if actor.shield > 0:
		var shield_damage = int(round(remaining * modifiers.shield))
		shield_damage = min(shield_damage, actor.shield)
		actor.adjust_shield(-shield_damage)
		remaining -= shield_damage / modifiers.shield
		result.shield = shield_damage

	if actor.armor > 0 and remaining > 0:
		var armor_raw = min(remaining, actor.armor / modifiers.armor)
		var armor_damage = int(round(armor_raw * modifiers.armor))
		actor.adjust_armor(-armor_damage)
		remaining -= armor_raw
		result.armor = armor_damage

	if remaining > 0:
		var health_damage = int(round(remaining * modifiers.health))
		actor.adjust_health(-health_damage)
		result.health = health_damage

	result.total = result.shield + result.armor + result.health
	return result


static func take_dot_damage(actor) -> Dictionary:
	"""
	Applies all active DOT effects and returns a breakdown.
	"""
	var total_damage = { "shield": 0, "armor": 0, "health": 0, "total": 0 }
	if not actor.active_effect_manager:
		return total_damage

	for dot in actor.active_effect_manager.get_dot_effects():
		var damage = take_damage_from_effect(actor, dot.effect)
		total_damage.shield += damage.shield
		total_damage.armor += damage.armor
		total_damage.health += damage.health
		total_damage.total += damage.total

	return total_damage
