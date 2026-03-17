class_name RegenEffect
extends BaseEffect


func is_regen() -> bool:
	return true


func get_effect_class_name() -> String:
	return "RegenEffect"


func get_effect_type_label() -> String:
	return BaseEffect.get_stat_label(stat)


func apply(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, amount)


func remove(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, -amount)


func get_ai_offensive_priority(_target) -> int:
	if amount >= 0:
		return 0
	return clamp(abs(amount), 3, 12)


func get_ai_utility_priority(_target) -> int:
	if not _target or not _target.combatant:
		return 0

	match stat:
		Enums.StatType.HEALTH_REGEN:
			return 5 if _target.combatant.health < _target.combatant.max_health * 0.3 else 3
		Enums.StatType.SHIELD_REGEN:
			return 5 if _target.combatant.shield < _target.combatant.max_shield * 0.3 else 3
		Enums.StatType.ARMOR_REGEN:
			return 5 if _target.combatant.armor < _target.combatant.max_armor * 0.3 else 3
		Enums.StatType.POWER_REGEN:
			return 5 if _target.combatant.power < _target.combatant.max_power * 0.3 else 3
		_:
			return 0


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	stat = Utils.string_to_enum(Enums.StatType, str(data.get("stat", "HEALTH_REGEN")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["stat"] = Utils.enum_to_string(Enums.StatType, stat)
	data["amount"] = amount
	data["duration"] = duration
	return data