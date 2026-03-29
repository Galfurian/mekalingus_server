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


func get_module_defensive_score(_target) -> float:
	if not _target or not _target.combatant:
		return 0.0

	var current: int = BaseEffect.get_actor_stat(_target.combatant, stat)
	var maximum: int = BaseEffect.get_actor_stat(_target.combatant, _get_max_stat())

	# Return 0 if repair would have no effect (already at max).
	if current >= maximum:
		return 0.0

	# Normalize effectiveness based on deficit.
	var deficit: float = float(maximum - current)
	var repair_potential: float = float(amount)

	# If repair amount is negligible, return low score.
	if repair_potential <= 0:
		return 0.0

	# Return how much of the deficit this repair covers, clamped to [0, 1].
	var effectiveness: float = clampf(repair_potential / (deficit + 1.0), 0.0, 1.0)

	# Scale by urgency (more urgent when damage is severe).
	var urgency_factor: float = clampf(deficit / float(maximum), 0.0, 1.0)
	var combined_score: float = clampf(effectiveness * 0.5 + urgency_factor * 0.5, 0.0, 1.0)

	return combined_score


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
