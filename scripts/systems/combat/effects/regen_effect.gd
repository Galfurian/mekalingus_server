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


func get_module_offensive_score(_target, _module: ItemModule = null) -> float:
	# Only negative regen (debuff) is offensive in this context.
	if amount >= 0:
		return 0.0
	if not _target or not _target.combatant:
		return 0.0
	# For debuffs, check if the target is sufficiently debuffed (return 0 if useless).
	var current_buff: float = float(_target.combatant.get_stat(stat))
	var debuff_strength: float = float(abs(amount))
	# If the target has no regen to lose, debuff is less useful.
	if current_buff <= 0.0:
		return 0.0
	# Estimate total debuff impact over duration relative to current buff level.
	var total_debuff: float = debuff_strength * float(duration)
	var effectiveness: float = clampf(total_debuff / (current_buff + 1.0), 0.0, 1.0)
	return effectiveness


func get_module_defensive_score(_target) -> float:
	# Only positive regen (buff) is defensive in this context.
	if amount < 0:
		return 0.0
	if not _target or not _target.combatant:
		return 0.0

	# Check if the regen is useless (e.g., healing health when at max, armor regen when at max).
	var target_stat: int = stat
	var current_value: float = float(_target.combatant.get_stat(target_stat))
	var max_stat: int = stat
	match stat:
		Enums.StatType.HEALTH_GENERATION:
			max_stat = Enums.StatType.MAX_HEALTH
		Enums.StatType.ARMOR_GENERATION:
			max_stat = Enums.StatType.MAX_ARMOR
		Enums.StatType.SHIELD_GENERATION:
			max_stat = Enums.StatType.MAX_SHIELD
		Enums.StatType.POWER_GENERATION:
			max_stat = Enums.StatType.MAX_POWER
	var max_value: float = float(_target.combatant.get_stat(max_stat))

	# Return 0 if target is already at max (regen would be wasted).
	if current_value >= max_value:
		return 0.0

	# Estimate effectiveness: how much this regen covers the deficit over duration.
	var total_regen: float = float(amount * duration)
	var deficit: float = max_value - current_value

	# Coverage ratio combined with urgency (how low the current value is).
	var coverage: float = clampf(total_regen / (deficit + 1.0), 0.0, 1.0)
	var urgency: float = clampf(deficit / (max_value + 1.0), 0.0, 1.0)

	return clampf(coverage * 0.5 + urgency * 0.5, 0.0, 1.0)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	assert(data.has("stat"))
	stat = Utils.string_to_enum(Enums.StatType, data["stat"])
	assert(
		(
			stat
			in [
				Enums.StatType.HEALTH_GENERATION,
				Enums.StatType.SHIELD_GENERATION,
				Enums.StatType.ARMOR_GENERATION,
				Enums.StatType.POWER_GENERATION
			]
		)
	)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["stat"] = Utils.enum_to_string(Enums.StatType, stat)
	data["amount"] = amount
	data["duration"] = duration
	return data
