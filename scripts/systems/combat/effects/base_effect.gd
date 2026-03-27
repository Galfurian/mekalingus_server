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


func is_buff() -> bool:
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount > 0


func is_debuff() -> bool:
	return (is_regen() or is_damage_reduction() or is_modifier()) and amount < 0


func is_offensive() -> bool:
	var negative_effect: bool = is_damage() or is_dot()
	return negative_effect and target in [Enums.TargetType.ENEMY, Enums.TargetType.AREA]


func is_defensive() -> bool:
	var positive_effect: bool = is_repair() or is_regen() or is_damage_reduction()
	return positive_effect and target in [Enums.TargetType.SELF, Enums.TargetType.ALLY]


func is_utility() -> bool:
	return is_modifier()


func get_effect_class_name() -> String:
	return "BaseEffect"


func get_effect_type_label() -> String:
	return "Effect"


func get_threat_score() -> float:
	return 0.0


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


func get_module_offensive_score(_target) -> float:
	return 0.0


func get_module_defensive_score(_target) -> float:
	return 0.0


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
	return Enums.get_stat_key(stat_type)


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
		Enums.StatType.HEALTH_GENERATION:
			return "Health Generation"
		Enums.StatType.ARMOR_GENERATION:
			return "Armor Generation"
		Enums.StatType.SHIELD_GENERATION:
			return "Shield Generation"
		Enums.StatType.POWER_GENERATION:
			return "Power Generation"
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
	if actor and actor.has_method("get_stat"):
		return int(actor.get_stat(stat_type))
	return 0


static func add_to_actor_stat(actor, stat_type: int, delta: int) -> void:
	if actor and actor.has_method("modify_stat"):
		actor.modify_stat(stat_type, delta)


static func adjust_actor_current_stat(actor, stat_type: int, delta: int) -> int:
	if actor and actor.has_method("adjust_current_stat"):
		return int(actor.adjust_current_stat(stat_type, delta))

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
		Enums.StatType.HEALTH_GENERATION:
			return Enums.StatType.HEALTH
		Enums.StatType.ARMOR_GENERATION:
			return Enums.StatType.ARMOR
		Enums.StatType.SHIELD_GENERATION:
			return Enums.StatType.SHIELD
		Enums.StatType.POWER_GENERATION:
			return Enums.StatType.POWER
		_:
			return stat_type
