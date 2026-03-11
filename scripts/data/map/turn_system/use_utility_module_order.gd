class_name UseUtilityModuleOrder
extends UseModuleOrder

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source: MapMek, p_target: MapMek, p_equipped_module: EquippedModule) -> void:
	super (p_source, p_target, p_equipped_module)


func _add_utility_log(game_map: GameMap, message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.SUPPORT, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(game_map: GameMap) -> bool:
	var source_mek: Mek = source.mek
	var target_mek: Mek = target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return false
	if not _is_target_in_module_range(game_map):
		_add_utility_log(
			game_map,
			"%s cannot use %s on %s (out of range: %d)" % [
				source_mek.get_chat_tag(),
				equipped_module.get_chat_tag(),
				target_mek.get_chat_tag(),
				_get_effective_module_range(),
			],
		)
		return false
	# Check if the Mek has enough power.
	if source_mek.power < equipped_module.module.power_on_use:
		return false
	# Deduct power.
	source_mek.power -= equipped_module.module.power_on_use
	# Start cooldown if necessary.
	if equipped_module.module.cooldown > 0:
		source_mek.cooldown_manager.start_cooldown(equipped_module.item, equipped_module.module)
	_add_utility_log(game_map, "%s used %s" % [source_mek.get_chat_tag(), equipped_module.get_chat_tag()])
	for effect in equipped_module.module.effects:
		var effect_chance: int = clamp(effect.chance, 0, 100)
		if effect_chance < 100:
			var effect_roll: int = randi() % 100
			if effect_roll >= effect_chance:
				_add_utility_log(
					game_map,
					"%s effect %s failed (%d%%, roll=%d)" % [
						equipped_module.get_chat_tag(),
						effect.get_effect_type_label(),
						effect_chance,
						effect_roll,
					],
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
			_add_utility_log(game_map, "Effect %s not yet implemented" % Enums.EffectType.keys()[effect.type])
		if source_mek.is_dead() or target_mek.is_dead():
			break
	return true


func _to_string() -> String:
	var source_name = source.mek.get_mek_name()
	var module_name = equipped_module.module.module_name
	var target_name = target.mek.get_mek_name()

	if source == target:
		return "%s is supporting itself with %s" % [source_name, module_name]
	return "%s is supporting %s with %s" % [source_name, target_name, module_name]
