class_name StatModifierEffect
extends BaseEffect


func is_modifier() -> bool:
	return true


func get_effect_class_name() -> String:
	return "StatModifierEffect"


func get_effect_type_label() -> String:
	return BaseEffect.get_stat_label(stat)


func apply(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, amount)


func remove(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, -amount)


func get_module_offensive_score(_target, _module: ItemModule = null) -> float:
	# This score now returns 0..1, based on target state and effect magnitude.
	# Only negative modifiers are offensive (debuffs).
	if amount >= 0 or not _target or not _target.combatant:
		return 0.0

	var effect_strength: float = float(abs(amount))
	var base_value: float = 0.0

	match stat:
		Enums.StatType.MAX_HEALTH:
			base_value = float(_target.combatant.max_health)
		Enums.StatType.MAX_SHIELD:
			base_value = float(_target.combatant.max_shield)
		Enums.StatType.MAX_ARMOR:
			base_value = float(_target.combatant.max_armor)
		Enums.StatType.MAX_POWER:
			base_value = float(_target.combatant.max_power)
		Enums.StatType.SPEED:
			base_value = float(_target.combatant.speed)
		Enums.StatType.ACCURACY_MODIFIER, Enums.StatType.RANGE_MODIFIER, Enums.StatType.COOLDOWN_MODIFIER:
			base_value = float(_target.combatant.get_stat(stat))
			if base_value < 1.0:
				base_value = 10.0
		_:
			base_value = 0.0
	if base_value <= 0.0:
		return 0.0
	return clampf(effect_strength / (base_value + 1.0), 0.0, 1.0)


func get_module_defensive_score(_target) -> float:
	# Only positive modifiers are defensive (buffs).
	if amount <= 0 or not _target or not _target.combatant:
		return 0.0

	var effect_strength: float = float(amount)
	var base_value: float = 0.0

	match stat:
		Enums.StatType.MAX_HEALTH:
			base_value = float(_target.combatant.max_health)
		Enums.StatType.MAX_SHIELD:
			base_value = float(_target.combatant.max_shield)
		Enums.StatType.MAX_ARMOR:
			base_value = float(_target.combatant.max_armor)
		Enums.StatType.MAX_POWER:
			base_value = float(_target.combatant.max_power)
		Enums.StatType.SPEED:
			base_value = float(_target.combatant.speed)
		Enums.StatType.ACCURACY_MODIFIER, Enums.StatType.RANGE_MODIFIER, Enums.StatType.COOLDOWN_MODIFIER:
			base_value = float(_target.combatant.get_stat(stat))
			if base_value < 1.0:
				base_value = 10.0
		_:
			base_value = 0.0
	if base_value <= 0.0:
		return 0.0
	return clampf(effect_strength / (base_value + 1.0), 0.0, 1.0)


func _get_type_factor() -> float:
	match stat:
		Enums.StatType.SPEED, Enums.StatType.RANGE_MODIFIER:
			return 2.5
		Enums.StatType.ACCURACY_MODIFIER:
			return 2.0
		Enums.StatType.COOLDOWN_MODIFIER:
			return 3.0
		_:
			return 1.0


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	stat = Utils.string_to_enum(Enums.StatType, str(data.get("stat", "MAX_HEALTH")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["stat"] = Utils.enum_to_string(Enums.StatType, stat)
	data["amount"] = amount
	return data
