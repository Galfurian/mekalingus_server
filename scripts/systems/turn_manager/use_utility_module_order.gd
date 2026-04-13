class_name UseUtilityModuleOrder
extends UseModuleOrder

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source, p_target, p_equipped_module: EquippedModule) -> void:
	super(p_source, p_target, p_equipped_module)


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(game_map) -> bool:
	var source_actor: CombatEntity = source.combatant
	var target_actor: CombatEntity = target.combatant
	if not _are_order_actors_alive(source_actor, target_actor):
		return false
	if not _check_target_range_or_log(game_map, source_actor, target_actor, Enums.LogType.SUPPORT):
		return false
	if not _check_module_state_or_log(game_map, source_actor, Enums.LogType.SUPPORT):
		return false
	if not _try_spend_power_and_start_cooldown(source_actor):
		return false
	_apply_module_state_transitions(source_actor)
	if not _passes_offensive_accuracy_gate(game_map, source_actor, target_actor):
		return false

	_add_log(
		game_map,
		Enums.LogType.SUPPORT,
		"%s used %s" % [source_actor.get_chat_tag(), equipped_module.get_chat_tag()],
	)

	for effect in equipped_module.module.effects:
		if not _should_apply_effect(game_map, effect, Enums.LogType.SUPPORT):
			continue

		_apply_module_effect(game_map, effect, Enums.LogType.SUPPORT)
		if not _are_order_actors_alive(source_actor, target_actor):
			break
	return true


func _to_string() -> String:
	var source_name = source.combatant.get_chat_tag()
	var module_name = equipped_module.module.module_name
	var target_name = target.combatant.get_chat_tag()

	if source == target:
		return "%s is supporting itself with %s" % [source_name, module_name]
	return "%s is supporting %s with %s" % [source_name, target_name, module_name]


func _passes_offensive_accuracy_gate(
	game_map,
	source_actor: CombatEntity,
	target_actor: CombatEntity,
) -> bool:
	if not _should_use_offensive_accuracy_gate(game_map):
		return true

	var final_accuracy: int = _calculate_accuracy(source_actor, target_actor, game_map)
	var roll: int = randi() % 100
	if roll < final_accuracy:
		return true

	_add_log(
		game_map,
		Enums.LogType.SUPPORT,
		(
			"%s used %s on %s and missed (accuracy=%d%%, roll=%d)"
			% [
				source_actor.get_chat_tag(),
				equipped_module.get_chat_tag(),
				target_actor.get_chat_tag(),
				final_accuracy,
				roll,
			]
		),
	)
	return false


func _should_use_offensive_accuracy_gate(game_map) -> bool:
	var has_offensive_effect: bool = equipped_module.module.effects.any(
		func(effect: BaseEffect): return effect.is_offensive()
	)
	return has_offensive_effect and game_map.is_enemy_of(source, target)


func _calculate_accuracy(
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	game_map,
) -> int:
	var base_accuracy: int = 90 + source_actor.accuracy_modifier
	var move_penalty: int = -min(source_actor.tiles_moved_last_turn * 5, 30)
	var dodge_bonus: int = -min(target_actor.tiles_moved_last_turn * 3, 15)
	var source_height: int = game_map.get_tile_height(source.position)
	var target_height: int = game_map.get_tile_height(target.position)
	var height_diff: int = source_height - target_height
	var height_bonus: int = clamp(height_diff * 2, -10, 10)
	return min(base_accuracy + move_penalty + dodge_bonus + height_bonus, 90)
