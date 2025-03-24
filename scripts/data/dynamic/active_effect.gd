extends RefCounted

class_name ActiveEffect

# =============================================================================
# PROPERTIES
# =============================================================================

# The module that applied this effect. Used for logging and reference.
var module: ItemModule
# The effect definition, containing type, amount, duration, and targeting rules.
var effect: ItemEffect
# The original source entity that applied the effect (can be used for ally/enemy checks).
var source: MapEntity
# Remaining duration in turns before the effect expires.
var remaining_duration: int

# =============================================================================
# GENERAL
# =============================================================================

func _init(_module: ItemModule, _effect: ItemEffect, _source: MapEntity, _duration: int) -> void:
	"""Initializes a new ActiveEffect with the provided module, effect, and duration."""
	module = _module
	effect = _effect
	source = _source
	remaining_duration = _duration

func decrement_duration():
	"""Decreases the remaining duration by 1 turn."""
	remaining_duration -= 1

func is_expired() -> bool:
	"""Checks if the module's effect duration has expired."""
	return remaining_duration <= 0

# =============================================================================
# UTILITY
# =============================================================================

func get_type() -> Enums.EffectType:
	return effect.type

func projected_dot_damage() -> int:
	"""Returns the total damage left to apply if this is a DOT."""
	if effect.type == Enums.EffectType.DAMAGE_OVER_TIME:
		return effect.amount * remaining_duration
	return 0

func is_damage() -> bool:
	""" Returns true if the effect deals immediate damage."""
	return effect.is_damage()

func is_dot() -> bool:
	""" Returns true if the effect is a damage-over-time effect."""
	return effect.is_dot()

func is_repair() -> bool:
	""" Returns true if the effect is an instantaneous repair (not over time)."""
	return effect.is_repair()

func is_regen() -> bool:
	""" Returns true if the effect provides regeneration over time."""
	return effect.is_regen()

func is_damage_reduction() -> bool:
	""" Returns true if the effect reduces incoming damage (general or by type)."""
	return effect.is_damage_reduction()

func is_modifier() -> bool:
	""" Returns true if the effect modifies total stats (health, power, speed, etc.)."""
	return effect.is_modifier()

func is_debuff() -> bool:
	""" Returns true if the effect is a negative stat change (regen reduction, stat debuff, etc.)."""
	return effect.is_debuff()

func is_buff() -> bool:
	""" Returns true if the effect is a positive stat change (regen boost, buff, etc.)."""
	return effect.is_buff()

func is_offensive() -> bool:
	""" Returns true if the effect is harmful to the enemy (damage, DOT, or debuff)."""
	return effect.is_offensive()

func is_defensive() -> bool:
	""" Returns true if the effect is a beneficial buff and not direct damage."""
	return effect.is_defensive()

func target_self() -> bool:
	""" Returns true if the effect targets the caster."""
	return effect.target_self()

func target_enemy() -> bool:
	""" Returns true if the effect targets an enemy unit."""
	return effect.target_enemy()

func target_ally() -> bool:
	""" Returns true if the effect targets an ally (other than self)."""
	return effect.target_ally()

func target_area() -> bool:
	""" Returns true if the effect targets an area (AOE)."""
	return effect.target_area()

func get_effect_type_label() -> String:
	"""
	Returns a short label for the effect type, useful for UI or logs.
	"""
	return effect.get_effect_type_label()

func describe() -> String:
	return "%s (%d turns left, amount=%d)" % [
		Enums.EffectType.keys()[effect.type],
		remaining_duration,
		effect.amount
	]
