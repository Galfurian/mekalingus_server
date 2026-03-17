# Tracks all ongoing active_effects (buffs, DOTs, HOTs, debuffs, temporary modifiers).
# Handles addition, ticking, expiration, and filtering.
class_name ActiveEffectManager

extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# The combat actor that owns this effect manager.
var actor = null
# List of active effects currently applied to the actor.
var active_effects: Array[ActiveEffect] = []

# =============================================================================
# INITIALIZATION
# =============================================================================


func _init(p_actor) -> void:
	"""
	Initializes the effect manager with the owner actor.
	"""
	self.actor = p_actor
	active_effects = []


# =============================================================================
# EFFECT MANAGEMENT
# =============================================================================


func add_active_effect(active_effect: ActiveEffect) -> void:
	"""
	Adds a new active effect to the list.
	"""
	# Toggle the effect on the owner actor.
	active_effect.effect.apply(actor)
	# Add the effect to the list.
	active_effects.append(active_effect)


func remove_expired_effects() -> void:
	"""
	Removes all expired active_effects from the list.
	"""
	# Deactivate the effect on the owner actor.
	for effect in active_effects:
		if effect.is_expired():
			effect.effect.remove(actor)
	# Filter out expired effects from the list.
	active_effects = active_effects.filter(func(e): return not e.is_expired())


func decrement_durations() -> void:
	"""
	Decrements duration for all active_effects by one turn and removes expired ones.
	"""
	for effect in active_effects:
		effect.decrement_duration()
	remove_expired_effects()


func remove_all_effects() -> void:
	"""
	Removes all active_effects from the list and deactivates them on the owner actor.
	"""
	for effect in active_effects:
		effect.effect.remove(actor)
	active_effects.clear()


# =============================================================================
# QUERIES: GENERAL
# =============================================================================


func get_dot_effects() -> Array[ActiveEffect]:
	"""Returns all currently active DOT active_effects."""
	return active_effects.filter(func(e): return e.is_dot())


func get_regen_effects() -> Array[ActiveEffect]:
	"""Returns all currently active regeneration active_effects (HOTs, power regen, etc.)."""
	return active_effects.filter(func(e): return e.is_regen())


func get_buffs() -> Array[ActiveEffect]:
	"""Returns all active buff active_effects (positive stat increases)."""
	return active_effects.filter(func(e): return e.is_buff())


func get_debuffs() -> Array[ActiveEffect]:
	"""Returns all active debuff active_effects (negative stat reductions)."""
	return active_effects.filter(func(e): return e.is_debuff())


# =============================================================================
# QUERIES: BY CATEGORY
# =============================================================================


func has_any_effects() -> bool:
	"""Returns true if there are any active_effects currently active."""
	return not active_effects.is_empty()


# =============================================================================
# ANALYSIS & AGGREGATES
# =============================================================================


func compute_total_dot_damage() -> int:
	"""Computes the total DOT damage this turn (summed across all DOT active_effects)."""
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


func should_refresh_dot(new_effect: BaseEffect) -> bool:
	"""Returns true when applying a new DOT would extend its remaining duration.

	This is used to avoid wasting attacks on DOTs that are already active and last
	as long or longer than the new effect.
	"""
	if not new_effect.is_dot():
		return false

	for effect in get_dot_effects():
		if effect.effect.damage_type == new_effect.damage_type:
			if effect.remaining_duration >= new_effect.duration:
				return false
	return true


# =============================================================================
# UTILITY
# =============================================================================


func clear() -> void:
	"""Clears all active_effects from the manager (used at the end of combat)."""
	remove_all_effects()
