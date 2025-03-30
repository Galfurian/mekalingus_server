# Tracks all ongoing effects (buffs, DOTs, HOTs, debuffs, temporary modifiers).
# Handles addition, ticking, expiration, and filtering.
class_name ActiveEffectManager

extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# List of active effects (e.g., DOTs, buffs, debuffs) currently applied to the Mek.
var active_effects: Array[ActiveEffect] = []

# =============================================================================
# EFFECT MANAGEMENT
# =============================================================================


func add_active_effect(effect: ActiveEffect) -> void:
	"""Adds a new active effect to the list."""
	active_effects.append(effect)


func remove_expired_effects() -> void:
	"""Removes all expired effects from the list."""
	active_effects = active_effects.filter(func(e): return not e.is_expired())


func decrement_durations() -> void:
	"""Decrements duration for all effects by one turn and removes expired ones."""
	for effect in active_effects:
		effect.decrement_duration()
	remove_expired_effects()


# =============================================================================
# QUERIES: GENERAL
# =============================================================================


func get_dot_effects() -> Array[ActiveEffect]:
	"""Returns all currently active DOT effects."""
	return active_effects.filter(func(e): return e.is_dot())


func get_regen_effects() -> Array[ActiveEffect]:
	"""Returns all currently active regeneration effects (HOTs, power regen, etc.)."""
	return active_effects.filter(func(e): return e.is_regen())


func get_buffs() -> Array[ActiveEffect]:
	"""Returns all active buff effects (positive stat increases)."""
	return active_effects.filter(func(e): return e.is_buff())


func get_debuffs() -> Array[ActiveEffect]:
	"""Returns all active debuff effects (negative stat reductions)."""
	return active_effects.filter(func(e): return e.is_debuff())


# =============================================================================
# QUERIES: BY TYPE OR CATEGORY
# =============================================================================


func get_effects_by_type(effect_type: Enums.EffectType) -> Array[ActiveEffect]:
	"""Returns all effects of a specific effect type (e.g., DAMAGE_REDUCTION_ALL)."""
	return active_effects.filter(func(e): return e.effect.type == effect_type)


func has_effect_type(effect_type: Enums.EffectType) -> bool:
	"""Returns true if there is any effect of the specified type."""
	return active_effects.any(func(e): return e.effect.type == effect_type)


func has_any_effects() -> bool:
	"""Returns true if there are any effects currently active."""
	return not active_effects.is_empty()


# =============================================================================
# ANALYSIS & AGGREGATES
# =============================================================================


func compute_total_dot_damage() -> int:
	"""Computes the total DOT damage this turn (summed across all DOT effects)."""
	var total = 0
	for effect in get_dot_effects():
		total += effect.effect.amount
	return total


func get_dot_damage_by_type() -> Dictionary:
	"""Returns a breakdown of DOT damage by damage type (for logging/debugging)."""
	var breakdown: Dictionary = {}
	for effect in get_dot_effects():
		var dmg_type = effect.effect.damage_type
		breakdown[dmg_type] = breakdown.get(dmg_type, 0) + effect.effect.amount
	return breakdown


# =============================================================================
# UTILITY
# =============================================================================


func clear() -> void:
	"""Clears all effects from the manager (used at the end of combat)."""
	active_effects.clear()
