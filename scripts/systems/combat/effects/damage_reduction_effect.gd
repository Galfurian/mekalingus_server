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


func get_module_offensive_score(_target) -> float: 
	# Return a normalized 0..1 measure of how impactful this effect is when used offensively.
	# Positive amount means defensive buff, not offensive, so score is 0.
	if amount >= 0:
		return 0.0
	if not _target or not _target.combatant:
		return 0.0

	# How strong is the debuff relative to current resistance level.
	var current_value: float = float(_target.combatant.get_stat(stat))
	var delta: float = float(abs(amount))
	var denominator: float = abs(current_value) + 1.0

	# Straightforward effectiveness ratio in 0..1.
	var effectiveness: float = clampf(delta / denominator, 0.0, 1.0)

	# Certain all-damage reductions are more valuable by nature.
	if stat == Enums.StatType.DAMAGE_REDUCTION_ALL:
		# amplify a bit in the normalized range without leaving 0..1.
		effectiveness = clampf(effectiveness * 1.2, 0.0, 1.0)

	return effectiveness


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