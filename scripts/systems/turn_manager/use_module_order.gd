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
	if not AIUtils.can_module_be_used_now(source.combatant, equipped_module):
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


func _are_order_actors_alive(source_actor: CombatEntity, target_actor: CombatEntity) -> bool:
	return not source_actor.is_dead() and not target_actor.is_dead()


func _check_target_range_or_log(
	game_map,
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	log_type: Enums.LogType,
) -> bool:
	if _is_target_in_module_range(game_map):
		return true

	var air_distance: float = source.position.distance_to(target.position)
	_add_log(
		game_map,
		log_type,
		(
			"%s cannot use %s on %s (range: %d, distance: %.1f)"
			% [
				source_actor.get_chat_tag(),
				equipped_module.get_chat_tag(),
				target_actor.get_chat_tag(),
				_get_effective_module_range(),
				air_distance,
			]
		),
	)
	return false


func _try_spend_power_and_start_cooldown(source_actor: CombatEntity) -> bool:
	if source_actor.power < equipped_module.power_on_use:
		return false

	source_actor.power -= equipped_module.power_on_use
	source_actor.cooldown_manager.start_cooldown(equipped_module.item, equipped_module.module)
	return true


func _check_module_state_or_log(
	game_map,
	source_actor: CombatEntity,
	log_type: Enums.LogType,
) -> bool:
	var validation_error: String = _get_module_state_validation_error(source_actor)
	if validation_error.is_empty():
		return true

	_add_log(
		game_map,
		log_type,
		(
			"%s cannot use %s (%s)"
			% [source_actor.get_chat_tag(), equipped_module.get_chat_tag(), validation_error]
		),
	)
	return false


func _apply_module_state_transitions(source_actor: CombatEntity) -> void:
	for runtime_state in equipped_module.module.grants_states:
		source_actor.add_runtime_state(runtime_state, equipped_module.module.state_stat_modifiers)
	for runtime_state in equipped_module.module.clears_states:
		source_actor.remove_runtime_state(runtime_state)


func _get_module_state_validation_error(source_actor: CombatEntity) -> String:
	for required_state: int in equipped_module.module.required_states:
		if not source_actor.has_runtime_state(required_state):
			return "missing state '%s'" % Enums.get_runtime_state_key(required_state)

	for blocked_state: int in equipped_module.module.blocked_states:
		if source_actor.has_runtime_state(blocked_state):
			return "blocked by state '%s'" % Enums.get_runtime_state_key(blocked_state)

	return ""


func _should_apply_effect(
	game_map,
	effect: BaseEffect,
	log_type: Enums.LogType,
	log_prefix: String = "",
) -> bool:
	var effect_chance: int = clamp(effect.chance, 0, 100)
	if effect_chance >= 100:
		return true

	var effect_roll: int = randi() % 100
	if effect_roll < effect_chance:
		return true

	if log_prefix.is_empty():
		_add_log(
			game_map,
			log_type,
			(
				"%s effect %s failed (%d%%, roll=%d)"
				% [
					equipped_module.get_chat_tag(),
					effect.get_effect_type_label(),
					effect_chance,
					effect_roll,
				]
			),
		)
	else:
		_add_log(
			game_map,
			log_type,
			(
				"%s %s effect %s failed (%d%%, roll=%d)"
				% [
					log_prefix,
					equipped_module.get_chat_tag(),
					effect.get_effect_type_label(),
					effect_chance,
					effect_roll,
				]
			),
		)

	return false


func _apply_module_effect(
	game_map,
	effect: BaseEffect,
	unsupported_log_type: Enums.LogType,
	unsupported_log_prefix: String = "",
) -> void:
	if effect.is_damage():
		_apply_damage_effect(game_map, effect)
	elif effect.is_repair():
		_apply_repair_effect(game_map, effect)
	elif (
		effect.is_dot() or effect.is_regen() or effect.is_damage_reduction() or effect.is_modifier()
	):
		_apply_modifier_effect(game_map, effect)
	else:
		if unsupported_log_prefix.is_empty():
			_add_log(
				game_map,
				unsupported_log_type,
				"Effect %s not yet implemented" % effect.get_effect_type_label(),
			)
		else:
			_add_log(
				game_map,
				unsupported_log_type,
				(
					"%s Effect %s not yet implemented"
					% [unsupported_log_prefix, effect.get_effect_type_label()]
				),
			)


# =============================================================================
# PRIVATE FUNCTIONS
# =============================================================================


func _apply_damage_effect(game_map, effect: BaseEffect) -> void:
	var source_actor: CombatEntity = source.combatant
	var target_actor: CombatEntity = target.combatant
	if not _are_order_actors_alive(source_actor, target_actor):
		return

	# SELF target branch.
	if effect.target == Enums.TargetType.SELF:
		var result = source_actor.take_damage_from_effect(effect)
		_add_log(
			game_map,
			Enums.LogType.ATTACK,
			(
				"%s hurts itself with %s -> %d shield, %d armor, %d health (reduced %d %s)"
				% [
					source_actor.get_chat_tag(),
					equipped_module.module.module_name,
					result.shield,
					result.armor,
					result.health,
					result.reduced,
					Enums.DamageType.keys()[effect.damage_type]
				]
			)
		)
	# AREA target branch.
	elif effect.target == Enums.TargetType.AREA:
		var center = target if effect.center_on_target else source
		var affected = AIUnitQueries.get_units_in_range(
			game_map, source, center.position, effect.radius, true, true
		)
		for entity in affected:
			var actor: CombatEntity = entity.combatant
			if actor.is_dead():
				continue
			var result = actor.take_damage_from_effect(effect)
			_add_log(
				game_map,
				Enums.LogType.ATTACK,
				(
					"%s hits %s with AoE from %s -> %d shield, %d armor, %d health (reduced %d %s)"
					% [
						source_actor.get_chat_tag(),
						actor.get_chat_tag(),
						equipped_module.module.module_name,
						result.shield,
						result.armor,
						result.health,
						result.reduced,
						Enums.DamageType.keys()[effect.damage_type]
					]
				)
			)
	# DIRECT target branch.
	else:
		var result = target_actor.take_damage_from_effect(effect)
		_add_log(
			game_map,
			Enums.LogType.ATTACK,
			(
				"%s hits %s with %s -> %d shield, %d armor, %d health (reduced %d %s)"
				% [
					source_actor.get_chat_tag(),
					target_actor.get_chat_tag(),
					equipped_module.module.module_name,
					result.shield,
					result.armor,
					result.health,
					result.reduced,
					Enums.DamageType.keys()[effect.damage_type]
				]
			)
		)


func _apply_repair_effect(game_map, effect: BaseEffect) -> void:
	var source_actor: CombatEntity = source.combatant
	var target_actor: CombatEntity = target.combatant
	if not _are_order_actors_alive(source_actor, target_actor):
		return

	# SELF target branch.
	if effect.target == Enums.TargetType.SELF:
		var result = source_actor.repair_from_effect(effect)
		_add_log(
			game_map,
			Enums.LogType.SUPPORT,
			(
				"%s restores %d %s to itself using %s"
				% [
					source_actor.get_chat_tag(),
					result.amount,
					result.stat,
					equipped_module.module.module_name
				]
			)
		)
	# AREA target branch.
	elif effect.target == Enums.TargetType.AREA:
		var center = target if effect.center_on_target else source
		var include_allies = (
			effect.target == Enums.TargetType.ALLY or effect.target == Enums.TargetType.SELF
		)
		var include_enemies = effect.target == Enums.TargetType.ENEMY
		var affected = AIUnitQueries.get_units_in_range(
			game_map, source, center.position, effect.radius, include_allies, include_enemies, []
		)
		for entity in affected:
			var actor: CombatEntity = entity.combatant
			if actor.is_dead():
				continue
			var result = actor.repair_from_effect(effect)
			_add_log(
				game_map,
				Enums.LogType.SUPPORT,
				(
					"%s restores %d %s to %s using %s (AoE)"
					% [
						source_actor.get_chat_tag(),
						result.amount,
						result.stat,
						actor.get_chat_tag(),
						equipped_module.module.module_name
					]
				)
			)
	# DIRECT target branch.
	else:
		if target_actor.is_dead():
			return
		var result = target_actor.repair_from_effect(effect)
		_add_log(
			game_map,
			Enums.LogType.SUPPORT,
			(
				"%s restores %d %s to %s using %s"
				% [
					source_actor.get_chat_tag(),
					result.amount,
					result.stat,
					target_actor.get_chat_tag(),
					equipped_module.module.module_name
				]
			)
		)


func _apply_modifier_effect(game_map, effect: BaseEffect) -> void:
	var source_actor: CombatEntity = source.combatant
	var target_actor: CombatEntity = target.combatant
	if not _are_order_actors_alive(source_actor, target_actor):
		return

	# SELF target branch.
	if effect.target == Enums.TargetType.SELF:
		source_actor.add_effect(equipped_module.module, effect, source)
		_add_log(
			game_map,
			Enums.LogType.SUPPORT,
			(
				"%s applies %s to itself -> %d for %d turns (%s)"
				% [
					source_actor.get_chat_tag(),
					effect.get_effect_type_label(),
					effect.amount,
					effect.duration,
					equipped_module.module.module_name
				]
			)
		)
	# AREA target branch.
	elif effect.target == Enums.TargetType.AREA:
		var center = target if effect.center_on_target else source
		var include_allies = (
			effect.target == Enums.TargetType.ALLY or effect.target == Enums.TargetType.SELF
		)
		var include_enemies = effect.target == Enums.TargetType.ENEMY
		var affected = AIUnitQueries.get_units_in_range(
			game_map,
			source,
			center.position,
			effect.radius,
			include_allies,
			include_enemies,
			[source]
		)
		for entity in affected:
			var actor: CombatEntity = entity.combatant
			if actor.is_dead():
				continue
			actor.add_effect(equipped_module.module, effect, source)
			_add_log(
				game_map,
				Enums.LogType.SUPPORT,
				(
					"%s applies %s to %s -> %d for %d turns (%s, AoE)"
					% [
						source_actor.get_chat_tag(),
						effect.get_effect_type_label(),
						actor.get_chat_tag(),
						effect.amount,
						effect.duration,
						equipped_module.module.module_name
					]
				)
			)
	# DIRECT target branch.
	else:
		target_actor.add_effect(equipped_module.module, effect, source)
		_add_log(
			game_map,
			Enums.LogType.SUPPORT,
			(
				"%s applies %s to %s -> %d for %d turns (%s)"
				% [
					source_actor.get_chat_tag(),
					effect.get_effect_type_label(),
					target_actor.get_chat_tag(),
					effect.amount,
					effect.duration,
					equipped_module.module.module_name
				]
			)
		)
