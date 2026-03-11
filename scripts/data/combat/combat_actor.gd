class_name CombatActor
extends Node

const CombatDamageCalculatorScript = preload("res://scripts/data/combat/combat_damage_calculator.gd")

# =============================================================================
# IDENTITY / EQUIPMENT
# =============================================================================

var uuid: String
var alias: String
var items: Array[Item]
var slots: Array[int]

# =============================================================================
# MANAGERS
# =============================================================================

# Wiring to concrete managers is intentionally deferred to migration steps.
var active_effect_manager = null
var cooldown_manager = null

# =============================================================================
# COMBAT STATS
# =============================================================================

var health: int
var armor: int
var shield: int
var power: int

var max_health: int
var max_armor: int
var max_shield: int
var max_power: int

var health_generation: int
var armor_generation: int
var shield_generation: int
var power_generation: int

var speed: int

var damage_reduction_all: int
var damage_reduction_kinetic: int
var damage_reduction_energy: int
var damage_reduction_explosive: int
var damage_reduction_plasma: int
var damage_reduction_corrosive: int

var accuracy_modifier: int
var range_modifier: int
var cooldown_modifier: int

var tiles_moved_last_turn: int = 0

# =============================================================================
# SHARED COMBAT API
# =============================================================================


func is_dead() -> bool:
	return health <= 0


func is_alive() -> bool:
	return health > 0


func adjust_health(amount: int) -> int:
	var before = health
	health = clamp(health + amount, 0, max_health)
	return health - before


func adjust_shield(amount: int) -> int:
	var before = shield
	shield = clamp(shield + amount, 0, max_shield)
	return shield - before


func adjust_armor(amount: int) -> int:
	var before = armor
	armor = clamp(armor + amount, 0, max_armor)
	return armor - before


func adjust_power(amount: int) -> int:
	var before = power
	power = clamp(power + amount, 0, max_power)
	return power - before


func regenerate() -> void:
	adjust_health(health_generation)
	adjust_armor(armor_generation)
	adjust_shield(shield_generation)
	adjust_power(power_generation)


func take_damage_from_effect(effect: ItemEffect) -> Dictionary:
	return CombatDamageCalculatorScript.take_damage_from_effect(self, effect)


func take_dot_damage() -> Dictionary:
	return CombatDamageCalculatorScript.take_dot_damage(self)


func repair_from_effect(effect: ItemEffect) -> Dictionary:
	var restored := 0
	var stat := ""
	match effect.type:
		Enums.EffectType.HEALTH_REPAIR:
			restored = adjust_health(effect.amount)
			stat = "health"
		Enums.EffectType.SHIELD_REPAIR:
			restored = adjust_shield(effect.amount)
			stat = "shield"
		Enums.EffectType.ARMOR_REPAIR:
			restored = adjust_armor(effect.amount)
			stat = "armor"
		_:
			return { "stat": "unknown", "amount": 0 }
	return { "stat": stat, "amount": restored }


func apply_regen_effects() -> void:
	if not active_effect_manager:
		return
	for effect in active_effect_manager.get_regen_effects():
		match effect.effect.type:
			Enums.EffectType.HEALTH_REGEN:
				adjust_health(effect.effect.amount)
			Enums.EffectType.SHIELD_REGEN:
				adjust_shield(effect.effect.amount)
			Enums.EffectType.ARMOR_REGEN:
				adjust_armor(effect.effect.amount)
			Enums.EffectType.POWER_REGEN:
				adjust_power(effect.effect.amount)
