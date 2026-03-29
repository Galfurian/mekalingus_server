class_name UseOffensiveModuleOrder
extends UseModuleOrder

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source, p_target, p_equipped_module: EquippedModule) -> void:
	super(p_source, p_target, p_equipped_module)


func _add_combat_log(game_map, message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.ATTACK, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(game_map) -> bool:
	var source_actor: CombatEntity = source.combatant
	var target_actor: CombatEntity = target.combatant
	if source_actor.is_dead() or target_actor.is_dead():
		return false
	if not _is_target_in_module_range(game_map):
		var air_distance: float = source.position.distance_to(target.position)
		_add_combat_log(
			game_map,
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
	# Check if the Mek has enough power.
	if source_actor.power < equipped_module.module.power_on_use:
		return false
	# Deduct power.
	source_actor.power -= equipped_module.module.power_on_use
	# Start cooldown if necessary
	source_actor.cooldown_manager.start_cooldown(equipped_module.item, equipped_module.module)
	var repeats: int = max(1, equipped_module.repeats)
	var hit_count := 0

	# Accuracy factors are computed once because they are stable for this order execution.
	var base_accuracy := 90
	var modifier := source_actor.accuracy_modifier
	var move_penalty: int = -min(source_actor.tiles_moved_last_turn * 5, 30)
	var dodge_bonus: int = -min(target_actor.tiles_moved_last_turn * 3, 15)
	var source_height = game_map.get_tile_height(source.position)
	var target_height = game_map.get_tile_height(target.position)
	var height_diff = source_height - target_height
	var height_bonus = clamp(height_diff * 2, -10, 10)
	var final_accuracy = min(
		base_accuracy + modifier + move_penalty + dodge_bonus + height_bonus, 90
	)

	for repeat_index in range(repeats):
		if source_actor.is_dead() or target_actor.is_dead():
			break

		var roll = randi() % 100
		var hit_success = roll < final_accuracy
		var shot_label := "[shot %d/%d]" % [repeat_index + 1, repeats]

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
			% [base_accuracy, modifier, move_penalty, dodge_bonus, height_bonus]
		)
		log_text += (
			" -> accuracy=%d%% (roll=%d): %s"
			% [final_accuracy, roll, "HIT" if hit_success else "MISS"]
		)
		if repeat_index == 0:
			if equipped_module.cooldown:
				log_text += " (cooldown: %d)" % equipped_module.cooldown
			else:
				log_text += " (instant use)"
		_add_combat_log(game_map, log_text)

		if not hit_success:
			continue

		hit_count += 1
		for effect in equipped_module.module.effects:
			var effect_chance: int = clamp(effect.chance, 0, 100)
			if effect_chance < 100:
				var effect_roll: int = randi() % 100
				if effect_roll >= effect_chance:
					_add_combat_log(
						game_map,
						(
							"%s %s effect %s failed (%d%%, roll=%d)"
							% [
								shot_label,
								equipped_module.get_chat_tag(),
								effect.get_effect_type_label(),
								effect_chance,
								effect_roll,
							]
						),
					)
					continue
			if effect.is_damage():
				_apply_damage_effect(game_map, effect)
			elif effect.is_repair():
				_apply_repair_effect(game_map, effect)
			elif effect.is_dot():
				_apply_modifier_effect(game_map, effect)
			elif effect.is_regen():
				_apply_modifier_effect(game_map, effect)
			elif effect.is_damage_reduction():
				_apply_modifier_effect(game_map, effect)
			elif effect.is_modifier():
				_apply_modifier_effect(game_map, effect)
			else:
				_add_combat_log(
					game_map,
					"%s Effect %s not yet implemented"
					% [shot_label, effect.get_effect_type_label()],
				)
			if source_actor.is_dead() or target_actor.is_dead():
				break

	return hit_count > 0


func _to_string() -> String:
	var source_name = source.combatant.get_chat_tag()
	var module_name = equipped_module.module.module_name
	var target_name = target.combatant.get_chat_tag()
	if source == target:
		return "%s is attacking itself with %s" % [source_name, module_name]
	return "%s is attacking %s with %s" % [source_name, target_name, module_name]
