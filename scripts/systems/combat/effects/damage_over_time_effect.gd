class_name DamageOverTimeEffect
extends BaseEffect


func is_dot() -> bool:
	return true


func get_effect_class_name() -> String:
	return "DamageOverTimeEffect"


func get_effect_type_label() -> String:
	return "Damage over Time"


func get_threat_score() -> float:
	"""
	Normalized threat score based on the total damage dealt over the duration of the effect.
	"""
	return clampf(float(amount * duration) / 100.0, 0.0, 1.0)


func get_module_offensive_score(_target) -> float:
	# require target combat entity
	if not _target or not _target.combatant:
		return 0.0

	# if DoT is already present and should not refresh, it is not useful.
	if _target.combatant.active_effect_manager:
		if not _target.combatant.active_effect_manager.should_refresh_dot(self):
			return 0.0

	# Rough estimation of total output damage over duration.
	var raw_total: float = float(amount * duration)

	var current_durability: float = _target.combatant.get_total_current_durability()

	# Returning 0..1 effectiveness w.r.t. target durability.
	return clampf(raw_total / (current_durability + 1.0), 0.0, 1.0)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	damage_type = Utils.string_to_enum(Enums.DamageType, str(data.get("damage_type", "KINETIC")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["damage_type"] = Utils.enum_to_string(Enums.DamageType, damage_type)
	data["amount"] = amount
	data["duration"] = duration
	return data
