class_name DamageEffect
extends BaseEffect


func is_damage() -> bool:
	return true


func get_effect_class_name() -> String:
	return "DamageEffect"


func get_effect_type_label() -> String:
	return "Damage"


func get_threat_score() -> float:
	"""
	Normalized threat score based on the amount of damage dealt.
	"""
	return clampf(float(amount) / 100.0, 0.0, 1.0)


func get_ai_offensive_priority(_target) -> int:
	return clamp(int(round(float(amount) / 10.0)), 1, 10)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	damage_type = Utils.string_to_enum(Enums.DamageType, str(data.get("damage_type", "KINETIC")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["damage_type"] = Utils.enum_to_string(Enums.DamageType, damage_type)
	data["amount"] = amount
	return data
