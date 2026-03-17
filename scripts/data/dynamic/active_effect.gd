# Keeps track of active effects on entities.
class_name ActiveEffect
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# The module that applied this effect. Used for logging and reference.
var module: ItemModule
# The effect definition, containing type, amount, duration, and targeting rules.
var effect: BaseEffect
# The original source entity that applied the effect (can be used for ally/enemy checks).
var source: MapEntity
# Remaining duration in turns before the effect expires.
var remaining_duration: int

# =============================================================================
# GENERAL
# =============================================================================


func _init(_module: ItemModule, _effect: BaseEffect, _source: MapEntity, _duration: int) -> void:
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


func projected_dot_damage() -> int:
	"""Returns the total damage left to apply if this is a DOT."""
	if effect.is_dot():
		return effect.amount * remaining_duration
	return 0


func is_damage() -> bool:
	""" Returns true if the effect deals immediate damage."""
	return effect.is_damage()


func is_dot() -> bool:
	""" Returns true if the effect is a damage-over-time effect."""
	return effect.is_dot()


func is_regen() -> bool:
	""" Returns true if the effect provides regeneration over time."""
	return effect.is_regen()


func is_debuff() -> bool:
	""" Returns true if the effect is a negative stat change (regen reduction, stat debuff, etc.)."""
	return effect.is_debuff()


func is_buff() -> bool:
	""" Returns true if the effect is a positive stat change (regen boost, buff, etc.)."""
	return effect.is_buff()


func is_offensive() -> bool:
	""" Returns true if the effect is harmful to the enemy (damage, DOT, or debuff)."""
	return effect.is_offensive()


func get_effect_type_label() -> String:
	"""
	Returns a short label for the effect type, useful for UI or logs.
	"""
	return effect.get_effect_type_label()


func describe() -> String:
	return (
		"%s (%d turns left, amount=%d)"
		% [effect.get_effect_type_label(), remaining_duration, effect.amount]
	)
