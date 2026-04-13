class_name UseOffensiveModuleOrder
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
	if not _check_target_range_or_log(game_map, source_actor, target_actor, Enums.LogType.ATTACK):
		return false
	if not _check_module_state_or_log(game_map, source_actor, Enums.LogType.ATTACK):
		return false
	if not _try_spend_power_and_start_cooldown(source_actor):
		return false
	_apply_module_state_transitions(source_actor)

	var accuracy_data: Dictionary = _build_accuracy_data(source_actor, target_actor, game_map)
	return _execute_repeated_attacks(game_map, source_actor, target_actor, accuracy_data)


func _to_string() -> String:
	var source_name = source.combatant.get_chat_tag()
	var module_name = equipped_module.module.module_name
	var target_name = target.combatant.get_chat_tag()
	if source == target:
		return "%s is attacking itself with %s" % [source_name, module_name]
	return "%s is attacking %s with %s" % [source_name, target_name, module_name]


func _build_accuracy_data(
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	game_map,
) -> Dictionary:
	var base_accuracy := 90
	var modifier := source_actor.accuracy_modifier
	var move_penalty: int = -min(source_actor.tiles_moved_last_turn * 5, 30)
	var dodge_bonus: int = -min(target_actor.tiles_moved_last_turn * 3, 15)
	var source_height = game_map.get_tile_height(source.position)
	var target_height = game_map.get_tile_height(target.position)
	var height_diff = source_height - target_height
	var height_bonus = clamp(height_diff * 2, -10, 10)
	var final_accuracy = min(
		base_accuracy + modifier + move_penalty + dodge_bonus + height_bonus,
		90,
	)

	return {
		"base_accuracy": base_accuracy,
		"modifier": modifier,
		"move_penalty": move_penalty,
		"dodge_bonus": dodge_bonus,
		"height_bonus": height_bonus,
		"final_accuracy": final_accuracy,
	}


func _execute_repeated_attacks(
	game_map,
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	accuracy_data: Dictionary,
) -> bool:
	var repeats: int = max(1, equipped_module.repeats)
	var hit_count := 0

	for repeat_index in range(repeats):
		if not _are_order_actors_alive(source_actor, target_actor):
			break

		var shot_label := "[shot %d/%d]" % [repeat_index + 1, repeats]
		var shot_result: Dictionary = _perform_single_shot(
			game_map,
			source_actor,
			target_actor,
			accuracy_data,
			repeat_index,
			shot_label,
		)
		if shot_result.hit:
			hit_count += 1

	return hit_count > 0


func _perform_single_shot(
	game_map,
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	accuracy_data: Dictionary,
	repeat_index: int,
	shot_label: String,
) -> Dictionary:
	var roll: int = randi() % 100
	var final_accuracy: int = int(accuracy_data.final_accuracy)
	var hit_success: bool = roll < final_accuracy

	_add_log(
		game_map,
		Enums.LogType.ATTACK,
		_build_shot_log(
			source_actor,
			target_actor,
			accuracy_data,
			roll,
			hit_success,
			repeat_index,
			shot_label,
		),
	)

	if not hit_success:
		return {"hit": false}

	for effect in equipped_module.module.effects:
		if not _should_apply_effect(game_map, effect, Enums.LogType.ATTACK, shot_label):
			continue

		_apply_module_effect(game_map, effect, Enums.LogType.ATTACK, shot_label)
		if not _are_order_actors_alive(source_actor, target_actor):
			break

	return {"hit": true}


func _build_shot_log(
	source_actor: CombatEntity,
	target_actor: CombatEntity,
	accuracy_data: Dictionary,
	roll: int,
	hit_success: bool,
	repeat_index: int,
	shot_label: String,
) -> String:
	var log_text := (
		"%s %s attacking %s with %s:"
		% [
			shot_label,
			source_actor.get_chat_tag(),
			target_actor.get_chat_tag(),
			equipped_module.get_chat_tag(),
		]
	)
	log_text += (
		" base=%d, modifier=%d, move=%d, dodge=%d, height=%d"
		% [
			accuracy_data.base_accuracy,
			accuracy_data.modifier,
			accuracy_data.move_penalty,
			accuracy_data.dodge_bonus,
			accuracy_data.height_bonus,
		]
	)
	log_text += (
		" -> accuracy=%d%% (roll=%d): %s"
		% [accuracy_data.final_accuracy, roll, "HIT" if hit_success else "MISS"]
	)
	if repeat_index == 0:
		if equipped_module.cooldown:
			log_text += " (cooldown: %d)" % equipped_module.cooldown
		else:
			log_text += " (instant use)"
	return log_text
