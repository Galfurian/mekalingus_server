class_name RepairEffect
extends BaseEffect


func is_repair() -> bool:
	return true


func get_effect_class_name() -> String:
	return "RepairEffect"


func get_effect_type_label() -> String:
	match stat:
		Enums.StatType.HEALTH:
			return "Health Repair"
		Enums.StatType.SHIELD:
			return "Shield Repair"
		Enums.StatType.ARMOR:
			return "Armor Repair"
		_:
			return "Repair"


func get_ai_utility_priority(target) -> int:
	if not target or not target.combatant:
		return 0

	var current: int = BaseEffect.get_actor_stat(target.combatant, stat)
	var maximum: int = BaseEffect.get_actor_stat(target.combatant, _get_max_stat())
	if current < maximum * 0.4:
		return 16
	if current < maximum * 0.7:
		return 8
	return 0


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	stat = Utils.string_to_enum(Enums.StatType, str(data.get("stat", "HEALTH")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["stat"] = Utils.enum_to_string(Enums.StatType, stat)
	data["amount"] = amount
	return data


func _get_max_stat() -> int:
	match stat:
		Enums.StatType.HEALTH:
			return Enums.StatType.MAX_HEALTH
		Enums.StatType.SHIELD:
			return Enums.StatType.MAX_SHIELD
		Enums.StatType.ARMOR:
			return Enums.StatType.MAX_ARMOR
		_:
			return stat