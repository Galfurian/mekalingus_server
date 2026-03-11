class_name MekPowerEvaluator
extends RefCounted


static func evaluate(mek: Mek) -> float:
	"""
	Computes the total power level of the Mek instance based on:
	- Power contribution of equipped items.
	- Base stats retrieved from the MekTemplate.
	"""
	var item_power := 0.0
	for item in mek.items:
		item_power += item.evaluate_item_power()
	var stat_power := (
		mek.max_health * 0.3
		+ mek.max_armor * 0.3
		+ mek.max_shield * 0.3
		+ mek.max_power * 0.3
		+ mek.health_generation * 2.0
		+ mek.armor_generation * 2.0
		+ mek.shield_generation * 2.0
		+ mek.power_generation * 2.0
		+ mek.speed * 15.0
		+ mek.damage_reduction_all * 5.0
		+ mek.damage_reduction_kinetic * 2.5
		+ mek.damage_reduction_energy * 2.5
		+ mek.damage_reduction_explosive * 2.5
		+ mek.damage_reduction_plasma * 2.5
		+ mek.damage_reduction_corrosive * 2.5
		+ mek.accuracy_modifier * 5.0
		+ mek.range_modifier * 5.0
		+ mek.cooldown_modifier * 5.0
	)
	return round(item_power + stat_power)
