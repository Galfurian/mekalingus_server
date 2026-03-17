class_name DamageOverTimeEffect
extends BaseEffect


func is_dot() -> bool:
	return true


func get_effect_class_name() -> String:
	return "DamageOverTimeEffect"


func get_effect_type_label() -> String:
	return "Damage over Time"


func get_threat_score() -> float:
	return float(amount * duration) * 0.5


func get_ai_offensive_priority(p_target) -> int:
	if not p_target or not p_target.combatant or not p_target.combatant.active_effect_manager:
		return clamp(int(round(float(amount * duration) / 5.0)), 1, 8)
	if not p_target.combatant.active_effect_manager.should_refresh_dot(self):
		return -8
	return clamp(int(round(float(amount * duration) / 5.0)), 1, 8)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	damage_type = Utils.string_to_enum(Enums.DamageType, str(data.get("damage_type", "KINETIC")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["damage_type"] = Utils.enum_to_string(Enums.DamageType, damage_type)
	data["amount"] = amount
	data["duration"] = duration
	return data
