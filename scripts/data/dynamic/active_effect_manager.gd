# Tracks all ongoing effects (buffs, DOTs, HOTs, debuffs, temporary modifiers).
# Handles addition, ticking, expiration, and filtering.

extends RefCounted

class_name ActiveEffectManager

# =============================================================================
# PROPERTIES
# =============================================================================

# List of active effects (e.g., DOTs, buffs, debuffs) currently applied to the Mek.
var active_effects: Array[ActiveEffect] = []

# =============================================================================
# EFFECT MANAGEMENT
# =============================================================================

"""Adds a new active effect to the list."""
func add_active_effect(effect: ActiveEffect) -> void:
	active_effects.append(effect)

"""Removes all expired effects from the list."""
func remove_expired_effects() -> void:
	active_effects = active_effects.filter(func(e): return not e.is_expired())

"""Decrements duration for all effects by one turn and removes expired ones."""
func decrement_durations() -> void:
	for effect in active_effects:
		effect.decrement_duration()
	remove_expired_effects()

# =============================================================================
# QUERIES: GENERAL
# =============================================================================

"""Returns all currently active DOT effects."""
func get_dot_effects() -> Array[ActiveEffect]:
	return active_effects.filter(func(e): return e.is_dot())

"""Returns all currently active regeneration effects (HOTs, power regen, etc.)."""
func get_regen_effects() -> Array[ActiveEffect]:
	return active_effects.filter(func(e): return e.is_regen())

"""Returns all active buff effects (positive stat increases)."""
func get_buffs() -> Array[ActiveEffect]:
	return active_effects.filter(func(e): return e.is_buff())

"""Returns all active debuff effects (negative stat reductions)."""
func get_debuffs() -> Array[ActiveEffect]:
	return active_effects.filter(func(e): return e.is_debuff())

# =============================================================================
# QUERIES: BY TYPE OR CATEGORY
# =============================================================================

"""Returns all effects of a specific effect type (e.g., DAMAGE_REDUCTION_ALL)."""
func get_effects_by_type(effect_type: Enums.EffectType) -> Array[ActiveEffect]:
	return active_effects.filter(func(e): return e.effect.type == effect_type)

"""Returns true if there is any effect of the specified type."""
func has_effect_type(effect_type: Enums.EffectType) -> bool:
	return active_effects.any(func(e): return e.effect.type == effect_type)

"""Returns true if there are any effects currently active."""
func has_any_effects() -> bool:
	return not active_effects.is_empty()

# =============================================================================
# ANALYSIS & AGGREGATES
# =============================================================================

"""Computes the total DOT damage this turn (summed across all DOT effects)."""
func compute_total_dot_damage() -> int:
	var total = 0
	for effect in get_dot_effects():
		total += effect.effect.amount
	return total

"""Returns a breakdown of DOT damage by damage type (for logging/debugging)."""
func get_dot_damage_by_type() -> Dictionary:
	var breakdown: Dictionary = {}
	for effect in get_dot_effects():
		var dmg_type = effect.effect.damage_type
		breakdown[dmg_type] = breakdown.get(dmg_type, 0) + effect.effect.amount
	return breakdown

# =============================================================================
# UTILITY
# =============================================================================

"""Clears all effects from the manager (used at the end of combat)."""
func clear() -> void:
	active_effects.clear()
