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


func get_module_offensive_score(_target) -> float:
	if not _target or not _target.combatant:
		return 0.0

	# Estimate effective damage after target resistances and defenses (dry run, no mutation).
	var damage_dict: Dictionary = CombatDamageCalculator.take_damage_from_effect(
		_target.combatant,
		self,
		true,
	)
	var estimated_damage: float = float(damage_dict.total)

	# Use target total durability as normalizer so result is 0..1.
	var total_defense: float = (
		float(_target.combatant.health)
		+ float(_target.combatant.armor)
		+ float(_target.combatant.shield)
	)

	# Straightforward fraction of baseline threat.
	return clampf(estimated_damage / (total_defense + 1.0), 0.0, 1.0)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	damage_type = Utils.string_to_enum(Enums.DamageType, str(data.get("damage_type", "KINETIC")))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["damage_type"] = Utils.enum_to_string(Enums.DamageType, damage_type)
	data["amount"] = amount
	return data
