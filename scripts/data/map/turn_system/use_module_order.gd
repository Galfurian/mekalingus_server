# This class represents the order to use a module on a target.
class_name UseModuleOrder
extends Order

# =============================================================================
# PROPERTIES
# =============================================================================

# The unit using the module.
var source: MapMek
# The entity affected (can be `source`, an ally, or an enemy).
var target: MapMek
# The equipped module being activated.
var equipped_module: EquippedModule

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source: MapMek, p_target: MapMek, p_equipped_module: EquippedModule) -> void:
	source = p_source
	target = p_target
	equipped_module = p_equipped_module


func _add_log(game_map: GameMap, type: Enums.LogType, message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(type, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# OVERRIDE FUNCTIONS
# =============================================================================


func execute(_game_map: GameMap) -> bool:
	push_error("execute() not implemented in subclass: %s" % self)
	return false


func validate() -> bool:
	push_warning("validate() not implemented in subclass: %s" % self)
	return false


func _to_string() -> String:
	return "<UseModuleOrder base class>"


# =============================================================================
# PRIVATE FUNCTIONS
# =============================================================================


func _apply_damage_effect(game_map: GameMap, effect: ItemEffect) -> void:
	var source_mek: Mek = source.mek
	var target_mek: Mek = target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF damage.
	if effect.target_self():
		var result = source_mek.take_damage_from_effect(effect)
		_add_log(game_map, Enums.LogType.ATTACK, "%s hurts itself with %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
			source_mek.template.mek_name,
			equipped_module.module.module_name,
			result.shield,
			result.armor,
			result.health,
			result.reduced,
			Enums.DamageType.keys()[effect.damage_type]])
	# Handle AREA damage.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var affected = game_map.get_units_in_range(
			source, center.position, effect.radius, true, true
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			var result = mek.take_damage_from_effect(effect)
			_add_log(game_map, Enums.LogType.ATTACK, "%s hits %s with AoE from %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
				source_mek.template.mek_name,
				target_mek.template.mek_name,
				equipped_module.module.module_name,
				result.shield,
				result.armor,
				result.health,
				result.reduced,
				Enums.DamageType.keys()[effect.damage_type]])
	# Handle regular ENEMY / ALLY targeting.
	else:
		var result = target_mek.take_damage_from_effect(effect)
		_add_log(game_map, Enums.LogType.ATTACK, "%s hits %s with %s -> %d shield, %d armor, %d health (reduced %d %s)" % [
			source_mek.template.mek_name,
			target_mek.template.mek_name,
			equipped_module.module.module_name,
			result.shield,
			result.armor,
			result.health,
			result.reduced,
			Enums.DamageType.keys()[effect.damage_type]])


func _apply_repair_effect(game_map: GameMap, effect: ItemEffect) -> void:
	var source_mek: Mek = source.mek
	var target_mek: Mek = target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF repair.
	if effect.target_self():
		var result = source_mek.repair_from_effect(effect)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to itself using %s" % [
			source_mek.template.mek_name,
			result.amount,
			result.stat,
			equipped_module.module.module_name])
	# Handle AREA repair.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = game_map.get_units_in_range(
			source, center.position, effect.radius, include_allies, include_enemies, []
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			var result = mek.repair_from_effect(effect)
			_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to %s using %s (AoE)" % [
					source_mek.template.mek_name,
					result.amount,
					result.stat,
					mek.template.mek_name,
					equipped_module.module.module_name
				]
			)
	# Handle ENEMY / ALLY repair.
	else:
		if target_mek.is_dead():
			return
		var result = target_mek.repair_from_effect(effect)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s restores %d %s to %s using %s" % [
			source_mek.template.mek_name,
			result.amount,
			result.stat,
			target_mek.template.mek_name,
			equipped_module.module.module_name])


func _apply_modifier_effect(game_map: GameMap, effect: ItemEffect) -> void:
	var source_mek: Mek = source.mek
	var target_mek: Mek = target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF-targeted effects.
	if effect.target_self():
		source_mek.add_effect(equipped_module.module, effect, source)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to itself -> %d for %d turns (%s)" % [
			source_mek.template.mek_name,
			effect.get_effect_type_label(),
			effect.amount,
			effect.duration,
			equipped_module.module.module_name])
	# Handle AREA-based effects.
	elif effect.target_area():
		var center = target if effect.center_on_target else source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = game_map.get_units_in_range(
			source, center.position, effect.radius, include_allies, include_enemies, [source]
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			mek.add_effect(equipped_module.module, effect, source)
			_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to %s -> %d for %d turns (%s, AoE)" % [
				source_mek.template.mek_name,
				effect.get_effect_type_label(),
				mek.template.mek_name,
				effect.amount,
				effect.duration,
				equipped_module.module.module_name])
	# Handle direct ENEMY / ALLY targeting.
	else:
		target_mek.add_effect(equipped_module.module, effect, source)
		_add_log(game_map, Enums.LogType.SUPPORT, "%s applies %s to %s -> %d for %d turns (%s)" % [
			source_mek.template.mek_name,
			effect.get_effect_type_label(),
			target_mek.template.mek_name,
			effect.amount,
			effect.duration,
			equipped_module.module.module_name])
