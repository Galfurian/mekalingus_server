class_name BaseEffect
extends RefCounted


var target: Enums.TargetType = Enums.TargetType.ENEMY
var chance: int = 100
var duration: int = 0
var radius: int = 0
var center_on_target: bool = true
var amount: int = 0
var stat: int = -1
var damage_type: int = Enums.DamageType.KINETIC


func _init(effect_data: Dictionary = {}) -> void:
	if effect_data:
		from_dict(effect_data)


func is_valid() -> bool:
	return chance >= 0 and chance <= 100 and duration >= 0 and radius >= 0


func is_damage() -> bool:
	return false


func is_dot() -> bool:
	return false


func is_repair() -> bool:
	return false


func is_regen() -> bool:
	return false


func is_damage_reduction() -> bool:
	return false


func is_modifier() -> bool:
	return false


func is_debuff() -> bool:
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount < 0


func is_buff() -> bool:
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount > 0


func is_offensive() -> bool:
	return is_damage() or is_dot() or is_debuff()


func get_effect_class_name() -> String:
	return "BaseEffect"


func get_effect_type_label() -> String:
	return "Effect"


func get_threat_score() -> float:
	return 2.0


func apply(_actor) -> void:
	pass


func remove(_actor) -> void:
	pass


func evaluate_effect_power(repeats: int) -> float:
	var repeat_factor: float = float(repeats) if is_damage() else 1.0
	return (
		abs(amount)
		* _get_duration_factor()
		* _get_area_factor()
		* _get_chance_factor()
		* _get_type_factor()
		* repeat_factor
		* _get_target_rationale()
	)


func get_ai_offensive_priority(_target) -> int:
	return 0


func get_ai_utility_priority(_target) -> int:
	return 0


func from_dict(data: Dictionary) -> void:
	if not data.has("target"):
		push_error("Invalid effect data: Missing target field")
		return

	target = Utils.string_to_enum(Enums.TargetType, str(data["target"]))
	amount = int(data.get("amount", 0))
	duration = int(data.get("duration", 0))
	chance = int(data.get("chance", 100))
	radius = int(data.get("radius", 0))
	center_on_target = bool(data.get("center_on_target", true))


func to_dict() -> Dictionary:
	var data := {
		"effect_class": get_effect_class_name(),
		"target": Utils.enum_to_string(Enums.TargetType, target),
	}

	if amount != 0:
		data["amount"] = amount
	if duration > 0:
		data["duration"] = duration
	if chance < 100:
		data["chance"] = chance
	if radius > 0:
		data["radius"] = radius
	if not center_on_target:
		data["center_on_target"] = false

	return data


func _get_type_factor() -> float:
	return 1.0


func _get_duration_factor() -> float:
	return 1.0 + float(duration)


func _get_area_factor() -> float:
	return 1.0 if target != Enums.TargetType.AREA else float(max(radius, 1))


func _get_chance_factor() -> float:
	return float(chance) / 100.0


func _get_target_rationale() -> float:
	if (target == Enums.TargetType.SELF or target == Enums.TargetType.ALLY) and amount < 0:
		return -1.0
	return 1.0


static func get_stat_key(stat_type: int) -> String:
	match stat_type:
		Enums.StatType.HEALTH:
			return "health"
		Enums.StatType.ARMOR:
			return "armor"
		Enums.StatType.SHIELD:
			return "shield"
		Enums.StatType.POWER:
			return "power"
		Enums.StatType.MAX_HEALTH:
			return "max_health"
		Enums.StatType.MAX_ARMOR:
			return "max_armor"
		Enums.StatType.MAX_SHIELD:
			return "max_shield"
		Enums.StatType.MAX_POWER:
			return "max_power"
		Enums.StatType.HEALTH_REGEN:
			return "health_generation"
		Enums.StatType.ARMOR_REGEN:
			return "armor_generation"
		Enums.StatType.SHIELD_REGEN:
			return "shield_generation"
		Enums.StatType.POWER_REGEN:
			return "power_generation"
		Enums.StatType.SPEED:
			return "speed"
		Enums.StatType.DAMAGE_REDUCTION_ALL:
			return "damage_reduction_all"
		Enums.StatType.DAMAGE_REDUCTION_KINETIC:
			return "damage_reduction_kinetic"
		Enums.StatType.DAMAGE_REDUCTION_ENERGY:
			return "damage_reduction_energy"
		Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE:
			return "damage_reduction_explosive"
		Enums.StatType.DAMAGE_REDUCTION_PLASMA:
			return "damage_reduction_plasma"
		Enums.StatType.DAMAGE_REDUCTION_CORROSIVE:
			return "damage_reduction_corrosive"
		Enums.StatType.ACCURACY_MODIFIER:
			return "accuracy_modifier"
		Enums.StatType.RANGE_MODIFIER:
			return "range_modifier"
		Enums.StatType.COOLDOWN_MODIFIER:
			return "cooldown_modifier"
		_:
			return "unknown"


static func get_stat_label(stat_type: int) -> String:
	match stat_type:
		Enums.StatType.HEALTH:
			return "Health"
		Enums.StatType.ARMOR:
			return "Armor"
		Enums.StatType.SHIELD:
			return "Shield"
		Enums.StatType.POWER:
			return "Power"
		Enums.StatType.MAX_HEALTH:
			return "Health Modifier"
		Enums.StatType.MAX_ARMOR:
			return "Armor Modifier"
		Enums.StatType.MAX_SHIELD:
			return "Shield Modifier"
		Enums.StatType.MAX_POWER:
			return "Power Modifier"
		Enums.StatType.HEALTH_REGEN:
			return "Health Regen"
		Enums.StatType.ARMOR_REGEN:
			return "Armor Regen"
		Enums.StatType.SHIELD_REGEN:
			return "Shield Regen"
		Enums.StatType.POWER_REGEN:
			return "Power Regen"
		Enums.StatType.SPEED:
			return "Speed Modifier"
		Enums.StatType.DAMAGE_REDUCTION_ALL:
			return "All Damage Reduction"
		Enums.StatType.DAMAGE_REDUCTION_KINETIC:
			return "Kinetic Damage Reduction"
		Enums.StatType.DAMAGE_REDUCTION_ENERGY:
			return "Energy Damage Reduction"
		Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE:
			return "Explosive Damage Reduction"
		Enums.StatType.DAMAGE_REDUCTION_PLASMA:
			return "Plasma Damage Reduction"
		Enums.StatType.DAMAGE_REDUCTION_CORROSIVE:
			return "Corrosive Damage Reduction"
		Enums.StatType.ACCURACY_MODIFIER:
			return "Accuracy Modifier"
		Enums.StatType.RANGE_MODIFIER:
			return "Range Modifier"
		Enums.StatType.COOLDOWN_MODIFIER:
			return "Cooldown Modifier"
		_:
			return "Unknown Stat"


static func get_actor_stat(actor, stat_type: int) -> int:
	match stat_type:
		Enums.StatType.HEALTH:
			return actor.health
		Enums.StatType.ARMOR:
			return actor.armor
		Enums.StatType.SHIELD:
			return actor.shield
		Enums.StatType.POWER:
			return actor.power
		Enums.StatType.MAX_HEALTH:
			return actor.max_health
		Enums.StatType.MAX_ARMOR:
			return actor.max_armor
		Enums.StatType.MAX_SHIELD:
			return actor.max_shield
		Enums.StatType.MAX_POWER:
			return actor.max_power
		Enums.StatType.HEALTH_REGEN:
			return actor.health_generation
		Enums.StatType.ARMOR_REGEN:
			return actor.armor_generation
		Enums.StatType.SHIELD_REGEN:
			return actor.shield_generation
		Enums.StatType.POWER_REGEN:
			return actor.power_generation
		Enums.StatType.SPEED:
			return actor.speed
		Enums.StatType.DAMAGE_REDUCTION_ALL:
			return actor.damage_reduction_all
		Enums.StatType.DAMAGE_REDUCTION_KINETIC:
			return actor.damage_reduction_kinetic
		Enums.StatType.DAMAGE_REDUCTION_ENERGY:
			return actor.damage_reduction_energy
		Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE:
			return actor.damage_reduction_explosive
		Enums.StatType.DAMAGE_REDUCTION_PLASMA:
			return actor.damage_reduction_plasma
		Enums.StatType.DAMAGE_REDUCTION_CORROSIVE:
			return actor.damage_reduction_corrosive
		Enums.StatType.ACCURACY_MODIFIER:
			return actor.accuracy_modifier
		Enums.StatType.RANGE_MODIFIER:
			return actor.range_modifier
		Enums.StatType.COOLDOWN_MODIFIER:
			return actor.cooldown_modifier
		_:
			return 0


static func add_to_actor_stat(actor, stat_type: int, delta: int) -> void:
	match stat_type:
		Enums.StatType.MAX_HEALTH:
			actor.max_health += delta
			actor.health = min(actor.health, actor.max_health)
		Enums.StatType.MAX_ARMOR:
			actor.max_armor += delta
			actor.armor = min(actor.armor, actor.max_armor)
		Enums.StatType.MAX_SHIELD:
			actor.max_shield += delta
			actor.shield = min(actor.shield, actor.max_shield)
		Enums.StatType.MAX_POWER:
			actor.max_power += delta
			actor.power = min(actor.power, actor.max_power)
		Enums.StatType.HEALTH_REGEN:
			actor.health_generation += delta
		Enums.StatType.ARMOR_REGEN:
			actor.armor_generation += delta
		Enums.StatType.SHIELD_REGEN:
			actor.shield_generation += delta
		Enums.StatType.POWER_REGEN:
			actor.power_generation += delta
		Enums.StatType.SPEED:
			actor.speed += delta
		Enums.StatType.DAMAGE_REDUCTION_ALL:
			actor.damage_reduction_all += delta
		Enums.StatType.DAMAGE_REDUCTION_KINETIC:
			actor.damage_reduction_kinetic += delta
		Enums.StatType.DAMAGE_REDUCTION_ENERGY:
			actor.damage_reduction_energy += delta
		Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE:
			actor.damage_reduction_explosive += delta
		Enums.StatType.DAMAGE_REDUCTION_PLASMA:
			actor.damage_reduction_plasma += delta
		Enums.StatType.DAMAGE_REDUCTION_CORROSIVE:
			actor.damage_reduction_corrosive += delta
		Enums.StatType.ACCURACY_MODIFIER:
			actor.accuracy_modifier += delta
		Enums.StatType.RANGE_MODIFIER:
			actor.range_modifier += delta
		Enums.StatType.COOLDOWN_MODIFIER:
			actor.cooldown_modifier += delta
		_:
			pass


static func adjust_actor_current_stat(actor, stat_type: int, delta: int) -> int:
	match stat_type:
		Enums.StatType.HEALTH:
			return actor.adjust_health(delta)
		Enums.StatType.ARMOR:
			return actor.adjust_armor(delta)
		Enums.StatType.SHIELD:
			return actor.adjust_shield(delta)
		Enums.StatType.POWER:
			return actor.adjust_power(delta)
		_:
			return 0


static func get_regen_target_stat(stat_type: int) -> int:
	match stat_type:
		Enums.StatType.HEALTH_REGEN:
			return Enums.StatType.HEALTH
		Enums.StatType.ARMOR_REGEN:
			return Enums.StatType.ARMOR
		Enums.StatType.SHIELD_REGEN:
			return Enums.StatType.SHIELD
		Enums.StatType.POWER_REGEN:
			return Enums.StatType.POWER
		_:
			return stat_type