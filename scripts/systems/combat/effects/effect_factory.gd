class_name EffectFactory
extends RefCounted

const STATE_EFFECT_SCRIPT = preload("res://scripts/systems/combat/effects/state_effect.gd")


static func create_from_dict(data: Dictionary) -> BaseEffect:
	var effect_class_name: String = str(data.get("effect_class", ""))
	match effect_class_name:
		"DamageEffect":
			return DamageEffect.new(data)
		"DamageOverTimeEffect":
			return DamageOverTimeEffect.new(data)
		"RepairEffect":
			return RepairEffect.new(data)
		"StatModifierEffect":
			return StatModifierEffect.new(data)
		"StateEffect":
			return STATE_EFFECT_SCRIPT.new(data)
		"RegenEffect":
			return RegenEffect.new(data)
		"DamageReductionEffect":
			return DamageReductionEffect.new(data)
		_:
			push_error("Unsupported effect_class: %s" % effect_class_name)
			return null