class_name CombatPowerEvaluator
extends RefCounted


static func evaluate(entity: CombatEntity) -> float:
	var item_power := 0.0
	for item in entity.items:
		item_power += item.evaluate_item_power()

	var stat_power: float = (
		entity.max_health * 0.3
		+ entity.max_armor * 0.3
		+ entity.max_shield * 0.3
		+ entity.max_power * 0.3
		+ entity.health_generation * 2.0
		+ entity.armor_generation * 2.0
		+ entity.shield_generation * 2.0
		+ entity.power_generation * 2.0
		+ entity.speed * 15.0
		+ entity.damage_reduction_all * 5.0
		+ entity.damage_reduction_kinetic * 2.5
		+ entity.damage_reduction_energy * 2.5
		+ entity.damage_reduction_explosive * 2.5
		+ entity.damage_reduction_plasma * 2.5
		+ entity.damage_reduction_corrosive * 2.5
		+ entity.accuracy_modifier * 5.0
		+ entity.range_modifier * 5.0
		+ entity.cooldown_modifier * 5.0
	)

	return round(item_power + stat_power)
