# This script defines the ItemEffect class, which represents a single effect that an item can have.
# Effects can be damage, healing, buffs, debuffs, or other stat modifications.
# Effects can target the user, an enemy, an ally, or an area of units.
# Effects can be instantaneous or last for a certain number of turns.
# Effects can have a chance to trigger, a radius for area effects, and other properties.
class_name ItemEffect
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# The type of effect (e.g., DAMAGE, REPAIR, SHIELD_MODIFIER).
var type: Enums.EffectType
# The target type (e.g., SELF, ENEMY, AREA).
var target: Enums.TargetType
# The type of damage (e.g., KINETIC, ENERGY, EXPLOSIVE) for damage-based effects.
var damage_type: Enums.DamageType
# The base amount of effect (e.g., damage dealt, healing applied).
var amount: int
# Duration of the effect in turns (0 = instant effect).
var duration: int
# The chance of the effect triggering (0-100%).
var chance: int
# The area of effect radius (0 = single target).
var radius: int
# If true, the AoE effect is centered on the target; otherwise, it's centered on the user.
var center_on_target: bool

# =============================================================================
# GENERAL
# =============================================================================


func _init(effect_data: Dictionary = {}):
	"""
	Initializes the effect with the given data (if any).
	"""
	if effect_data:
		from_dict(effect_data)


func is_valid() -> bool:
	if amount < 0 or chance < 0 or chance > 100 or duration < 0 or radius < 0:
		return false
	return true


func is_damage() -> bool:
	""" Returns true if the effect deals immediate damage."""
	return type == Enums.EffectType.DAMAGE


func is_dot() -> bool:
	""" Returns true if the effect is a damage-over-time """
	return type == Enums.EffectType.DAMAGE_OVER_TIME


func is_repair() -> bool:
	""" Returns true if the effect is an instantaneous repair (not over time)."""
	return (
		type
		in [
			Enums.EffectType.HEALTH_REPAIR,
			Enums.EffectType.SHIELD_REPAIR,
			Enums.EffectType.ARMOR_REPAIR
		]
	)


func is_regen() -> bool:
	""" Returns true if the effect provides regeneration over time."""
	return (
		type
		in [
			Enums.EffectType.SHIELD_REGEN,
			Enums.EffectType.ARMOR_REGEN,
			Enums.EffectType.POWER_REGEN
		]
	)


func is_damage_reduction() -> bool:
	""" Returns true if the effect reduces incoming damage (general or by type)."""
	return (
		type
		in [
			Enums.EffectType.DAMAGE_REDUCTION_ALL,
			Enums.EffectType.DAMAGE_REDUCTION_KINETIC,
			Enums.EffectType.DAMAGE_REDUCTION_ENERGY,
			Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE,
			Enums.EffectType.DAMAGE_REDUCTION_PLASMA,
			Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE
		]
	)


func is_modifier() -> bool:
	""" Returns true if the effect modifies total stats (health, power, speed, etc.)."""
	return (
		type
		in [
			Enums.EffectType.HEALTH_MODIFIER,
			Enums.EffectType.SHIELD_MODIFIER,
			Enums.EffectType.ARMOR_MODIFIER,
			Enums.EffectType.POWER_MODIFIER,
			Enums.EffectType.SPEED_MODIFIER,
			Enums.EffectType.ACCURACY_MODIFIER,
			Enums.EffectType.RANGE_MODIFIER,
			Enums.EffectType.COOLDOWN_MODIFIER
		]
	)


func is_debuff() -> bool:
	""" Returns true if the effect is a negative stat change (regen reduction, stat debuff, etc.)."""
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount < 0


func is_buff() -> bool:
	""" Returns true if the effect is a positive stat change (regen boost, buff, etc.)."""
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount > 0


func is_offensive() -> bool:
	""" Returns true if the effect is harmful to the enemy (damage, DOT, or debuff)."""
	return is_damage() or is_dot() or is_debuff()


func is_defensive() -> bool:
	""" Returns true if the effect is a beneficial buff and not direct damage."""
	return not is_damage() and is_buff()


func target_self() -> bool:
	""" Returns true if the effect targets the caster."""
	return target == Enums.TargetType.SELF


func target_enemy() -> bool:
	""" Returns true if the effect targets an enemy unit."""
	return target == Enums.TargetType.ENEMY


func target_ally() -> bool:
	""" Returns true if the effect targets an ally (other than self)."""
	return target == Enums.TargetType.ALLY


func target_area() -> bool:
	""" Returns true if the effect targets an area (AOE)."""
	return target == Enums.TargetType.AREA


func get_effect_type_label() -> String:
	"""
	Returns a short label for the effect type, useful for UI or logs.
	"""
	match type:
		Enums.EffectType.DAMAGE:
			return "Damage"
		Enums.EffectType.DAMAGE_OVER_TIME:
			return "Damage over Time"
		Enums.EffectType.HEALTH_REPAIR:
			return "Health Repair"
		Enums.EffectType.SHIELD_REPAIR:
			return "Shield Repair"
		Enums.EffectType.ARMOR_REPAIR:
			return "Armor Repair"
		Enums.EffectType.HEALTH_MODIFIER:
			return "Health Modifier"
		Enums.EffectType.SHIELD_MODIFIER:
			return "Shield Modifier"
		Enums.EffectType.ARMOR_MODIFIER:
			return "Armor Modifier"
		Enums.EffectType.POWER_MODIFIER:
			return "Power Modifier"
		Enums.EffectType.SPEED_MODIFIER:
			return "Speed Modifier"
		Enums.EffectType.ACCURACY_MODIFIER:
			return "Accuracy Modifier"
		Enums.EffectType.RANGE_MODIFIER:
			return "Range Modifier"
		Enums.EffectType.COOLDOWN_MODIFIER:
			return "Cooldown Modifier"
		Enums.EffectType.SHIELD_REGEN:
			return "Shield Regen"
		Enums.EffectType.ARMOR_REGEN:
			return "Armor Regen"
		Enums.EffectType.POWER_REGEN:
			return "Power Regen"
		Enums.EffectType.DAMAGE_REDUCTION_ALL:
			return "All Damage Reduction"
		Enums.EffectType.DAMAGE_REDUCTION_KINETIC:
			return "Kinetic Damage Reduction"
		Enums.EffectType.DAMAGE_REDUCTION_ENERGY:
			return "Energy Damage Reduction"
		Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE:
			return "Explosive Damage Reduction"
		Enums.EffectType.DAMAGE_REDUCTION_PLASMA:
			return "Plasma Damage Reduction"
		Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE:
			return "Corrosive Damage Reduction"
		_:
			return "Unknown Effect"


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	return (
		"Module<"
		+ Utils.enum_to_string(Enums.EffectType, type)
		+ ", "
		+ Utils.enum_to_string(Enums.TargetType, target)
		+ ", "
		+ str(amount)
		+ ">"
	)


func from_dict(data: Dictionary):
	if not data.has("type") or not data.has("target") or not data.has("amount"):
		push_error("Invalid ItemEffect data: Missing required fields")
		return

	type = Utils.string_to_enum(Enums.EffectType, data["type"])
	target = Utils.string_to_enum(Enums.TargetType, data["target"])
	amount = int(data["amount"])
	damage_type = Utils.string_to_enum(Enums.DamageType, data.get("damage_type", "KINETIC"))

	duration = int(data.get("duration", 0))
	chance = int(data.get("chance", 100))
	radius = int(data.get("radius", 0))
	center_on_target = bool(data.get("center_on_target", true))


func to_dict() -> Dictionary:
	var data = {
		"type": Utils.enum_to_string(Enums.EffectType, type),
		"target": Utils.enum_to_string(Enums.TargetType, target),
		"amount": amount,
		"damage_type": Utils.enum_to_string(Enums.DamageType, damage_type)
	}

	if duration > 0:
		data["duration"] = duration
	if chance < 100:
		data["chance"] = chance
	if radius > 0:
		data["radius"] = radius
	if not center_on_target:
		data["center_on_target"] = false

	return data
