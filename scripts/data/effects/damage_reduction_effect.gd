class_name DamageReductionEffect
extends BaseEffect


func is_damage_reduction() -> bool:
	return true


func get_effect_class_name() -> String:
	return "DamageReductionEffect"


func get_effect_type_label() -> String:
	return BaseEffect.get_stat_label(stat)


func apply(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, amount)


func remove(actor) -> void:
	BaseEffect.add_to_actor_stat(actor, stat, -amount)


func get_ai_offensive_priority(_target) -> int:
	if amount >= 0:
		return 0
	if stat == Enums.StatType.DAMAGE_REDUCTION_ALL:
		return clamp(abs(amount), 3, 12)
	return clamp(abs(amount), 2, 8)


func get_ai_utility_priority(_target) -> int:
	if stat == Enums.StatType.DAMAGE_REDUCTION_ALL:
		return 12
	return 6


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	stat = Utils.string_to_enum(Enums.StatType, str(data.get("stat", "DAMAGE_REDUCTION_ALL")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["stat"] = Utils.enum_to_string(Enums.StatType, stat)
	data["amount"] = amount
	data["duration"] = duration
	return data