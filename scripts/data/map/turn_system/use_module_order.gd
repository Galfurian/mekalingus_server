# This class represents the order to use a module on a target.
class_name UseModuleOrder
extends Order

# =============================================================================
# PROPERTIES
# =============================================================================

# The unit using the module.
var source
# The entity affected (can be `source`, an ally, or an enemy).
var target
# The equipped module being activated.
var equipped_module: EquippedModule

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source, p_target, p_equipped_module: EquippedModule) -> void:
	source = p_source
	target = p_target
	equipped_module = p_equipped_module


func _add_log(game_map, type: Enums.LogType, message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(type, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(_game_map) -> bool:
	push_error("execute() not implemented in subclass: %s" % self)
	return false


func validate() -> bool:
	if not source or not target or not equipped_module:
		return false
	if not source.combatant or not target.combatant:
		return false
	if source.combatant.is_dead() or target.combatant.is_dead():
		return false
	if not AIUtils.is_equipped_module_available(source.combatant, equipped_module):
		return false
	if not AIUtils.can_module_be_used_now(source.combatant, equipped_module.item, equipped_module.module):
		return false
	return true


func _to_string() -> String:
	return "<UseModuleOrder base class>"


func _get_effective_module_range() -> int:
	return max(0, equipped_module.module.module_range + source.combatant.range_modifier)


func _is_target_in_module_range(_game_map) -> bool:
	var effective_range: int = _get_effective_module_range()
	var distance: float = source.position.distance_to(target.position)
	return distance <= float(effective_range)


# =============================================================================
# PRIVATE FUNCTIONS
# =============================================================================


func _apply_damage_effect(game_map, effect: ItemEffect) -> void:
	var source_actor: CombatActor = source.combatant
	var target_actor: CombatActor = target.combatant
	if source_actor.is_dead() or target_actor.is_dead():
		return
	# Handle SELF damage.
	if effect.target_self():
		var result = source_actor.take_damage_from_effect(effect)
		_add_log(game_map, Enums.LogType.ATTACK, "%s hurts itself with %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
			source_actor.get_chat_tag(),
			equipped_module.module.module_name,
			result.shield,
			result.armor,
			result.health,
			result.reduced,
			Enums.DamageType.keys()[effect.damage_type]])
	# Handle AREA damage.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var affected = AIUnitQueries.get_units_in_range(game_map,
			source, center.position, effect.radius, true, true
		)
		for entity in affected:
			var actor: CombatActor = entity.combatant
			if actor.is_dead():
				continue
			var result = actor.take_damage_from_effect(effect)
			_add_log(game_map, Enums.LogType.ATTACK, "%s hits %s with AoE from %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
				source_actor.get_chat_tag(),
				actor.get_chat_tag(),
				equipped_module.module.module_name,
				result.shield,
				result.armor,
				result.health,
				result.reduced,
				Enums.DamageType.keys()[effect.damage_type]])
	# Handle regular ENEMY / ALLY targeting.
	else:
		var result = target_actor.take_damage_from_effect(effect)
		_add_log(game_map, Enums.LogType.ATTACK, "%s hits %s with %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
			source_actor.get_chat_tag(),
			target_actor.get_chat_tag(),
			equipped_module.module.module_name,
			result.shield,
			result.armor,
			result.health,
			result.reduced,
			Enums.DamageType.keys()[effect.damage_type]])


func _apply_repair_effect(game_map, effect: ItemEffect) -> void:
	var source_actor: CombatActor = source.combatant
	var target_actor: CombatActor = target.combatant
	if source_actor.is_dead() or target_actor.is_dead():
		return
	# Handle SELF repair.
	if effect.target_self():
		var result = source_actor.repair_from_effect(effect)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to itself using %s" % [
			source_actor.get_chat_tag(),
			result.amount,
			result.stat,
			equipped_module.module.module_name])
	# Handle AREA repair.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = AIUnitQueries.get_units_in_range(game_map,
			source, center.position, effect.radius, include_allies, include_enemies, []
		)
		for entity in affected:
			var actor: CombatActor = entity.combatant
			if actor.is_dead():
				continue
			var result = actor.repair_from_effect(effect)
			_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to %s using %s (AoE)" % [
					source_actor.get_chat_tag(),
					result.amount,
					result.stat,
					actor.get_chat_tag(),
					equipped_module.module.module_name
				]
			)
	# Handle ENEMY / ALLY repair.
	else:
		if target_actor.is_dead():
			return
		var result = target_actor.repair_from_effect(effect)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to %s using %s" % [
			source_actor.get_chat_tag(),
			result.amount,
			result.stat,
			target_actor.get_chat_tag(),
			equipped_module.module.module_name])


func _apply_modifier_effect(game_map, effect: ItemEffect) -> void:
	var source_actor: CombatActor = source.combatant
	var target_actor: CombatActor = target.combatant
	if source_actor.is_dead() or target_actor.is_dead():
		return
	# Handle SELF-targeted effects.
	if effect.target_self():
		source_actor.add_effect(equipped_module.module, effect, source)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to itself -> %d for %d turns (%s)" % [
			source_actor.get_chat_tag(),
			effect.get_effect_type_label(),
			effect.amount,
			effect.duration,
			equipped_module.module.module_name])
	# Handle AREA-based effects.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = AIUnitQueries.get_units_in_range(game_map,
			source, center.position, effect.radius, include_allies, include_enemies, [source]
		)
		for entity in affected:
			var actor: CombatActor = entity.combatant
			if actor.is_dead():
				continue
			actor.add_effect(equipped_module.module, effect, source)
			_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to %s -> %d for %d turns (%s, AoE)" % [
				source_actor.get_chat_tag(),
				effect.get_effect_type_label(),
				actor.get_chat_tag(),
				effect.amount,
				effect.duration,
				equipped_module.module.module_name])
	# Handle direct ENEMY / ALLY targeting.
	else:
		target_actor.add_effect(equipped_module.module, effect, source)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to %s -> %d for %d turns (%s)" % [
			source_actor.get_chat_tag(),
			effect.get_effect_type_label(),
			target_actor.get_chat_tag(),
			effect.amount,
			effect.duration,
			equipped_module.module.module_name])
