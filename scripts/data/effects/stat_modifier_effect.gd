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


func get_ai_offensive_priority(_target) -> int:
	if amount >= 0:
		return 0

	match stat:
		Enums.StatType.ACCURACY_MODIFIER, Enums.StatType.RANGE_MODIFIER, Enums.StatType.COOLDOWN_MODIFIER:
			return clamp(abs(amount), 4, 16)
		Enums.StatType.MAX_POWER, Enums.StatType.MAX_HEALTH, Enums.StatType.MAX_ARMOR, Enums.StatType.MAX_SHIELD:
			return clamp(abs(amount), 2, 8)
		Enums.StatType.SPEED:
			return clamp(abs(amount), 4, 16)
		_:
			return 0


func get_ai_utility_priority(_target) -> int:
	if not _target or not _target.combatant:
		return 0

	match stat:
		Enums.StatType.MAX_HEALTH:
			return 4 if _target.combatant.health < _target.combatant.max_health * 0.4 else 2
		Enums.StatType.MAX_SHIELD:
			return 4 if _target.combatant.shield < _target.combatant.max_shield * 0.4 else 2
		Enums.StatType.MAX_ARMOR:
			return 4 if _target.combatant.armor < _target.combatant.max_armor * 0.4 else 2
		Enums.StatType.MAX_POWER:
			return 3 if _target.combatant.power < _target.combatant.max_power * 0.4 else 1
		Enums.StatType.SPEED:
			return 8
		Enums.StatType.ACCURACY_MODIFIER, Enums.StatType.RANGE_MODIFIER, Enums.StatType.COOLDOWN_MODIFIER:
			return 12
		_:
			return 0


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
