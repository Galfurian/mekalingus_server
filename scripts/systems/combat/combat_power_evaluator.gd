class_name CombatPowerEvaluator
extends RefCounted


static func evaluate(actor) -> float:
	var item_power := 0.0
	for item in actor.items:
		item_power += item.evaluate_item_power()

	var stat_power: float = (
		actor.max_health * 0.3
		+ actor.max_armor * 0.3
		+ actor.max_shield * 0.3
		+ actor.max_power * 0.3
		+ actor.health_generation * 2.0
		+ actor.armor_generation * 2.0
		+ actor.shield_generation * 2.0
		+ actor.power_generation * 2.0
		+ actor.speed * 15.0
		+ actor.damage_reduction_all * 5.0
		+ actor.damage_reduction_kinetic * 2.5
		+ actor.damage_reduction_energy * 2.5
		+ actor.damage_reduction_explosive * 2.5
		+ actor.damage_reduction_plasma * 2.5
		+ actor.damage_reduction_corrosive * 2.5
		+ actor.accuracy_modifier * 5.0
		+ actor.range_modifier * 5.0
		+ actor.cooldown_modifier * 5.0
	)

	return round(item_power + stat_power)
