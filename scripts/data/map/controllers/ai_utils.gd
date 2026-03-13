extends Node

# =====================================================================
# PRIORITY CALCULATION FUNCTIONS
# =====================================================================


func evaluate_utility_effect_priority(target: MapCombatEntity, effect: ItemEffect) -> int:
	"""
	Calculates a priority score for a specific effect on a specific target.
	"""
	# Initialize the priority score.
	var priority = 0
	# Check the effect type and assign a score.
	match effect.type:
		# Repairs (High priority if the related stat is low)
		Enums.EffectType.HEALTH_REPAIR:
			if target.combatant.health < target.combatant.max_health * 0.4:
				priority += 16
			elif target.combatant.health < target.combatant.max_health * 0.7:
				priority += 8
		Enums.EffectType.SHIELD_REPAIR:
			if target.combatant.shield < target.combatant.max_shield * 0.4:
				priority += 16
			elif target.combatant.shield < target.combatant.max_shield * 0.7:
				priority += 8
		Enums.EffectType.ARMOR_REPAIR:
			if target.combatant.armor < target.combatant.max_armor * 0.4:
				priority += 16
			elif target.combatant.armor < target.combatant.max_armor * 0.7:
				priority += 8
		# Max stat modifiers (Lower priority than direct repairs)
		Enums.EffectType.HEALTH_MODIFIER:
			priority += 4 if target.combatant.health < target.combatant.max_health * 0.4 else 2
		Enums.EffectType.SHIELD_MODIFIER:
			priority += 4 if target.combatant.shield < target.combatant.max_shield * 0.4 else 2
		Enums.EffectType.ARMOR_MODIFIER:
			priority += 4 if target.combatant.armor < target.combatant.max_armor * 0.4 else 2
		Enums.EffectType.POWER_MODIFIER:
			priority += 3 if target.combatant.power < target.combatant.max_power * 0.4 else 1
		# Speed modifier (Always useful, moderate priority)
		Enums.EffectType.SPEED_MODIFIER:
			priority += 8
		# Combat performance modifiers (Medium priority)
		Enums.EffectType.ACCURACY_MODIFIER:
			priority += 12
		Enums.EffectType.RANGE_MODIFIER:
			priority += 12
		Enums.EffectType.COOLDOWN_MODIFIER:
			priority += 12
		# Regeneration effects (Lower than direct repair but useful)
		Enums.EffectType.HEALTH_REGEN:
			priority += 5 if target.combatant.health < target.combatant.max_health * 0.3 else 3
		Enums.EffectType.SHIELD_REGEN:
			priority += 5 if target.combatant.shield < target.combatant.max_shield * 0.3 else 3
		Enums.EffectType.ARMOR_REGEN:
			priority += 5 if target.combatant.armor < target.combatant.max_armor * 0.3 else 3
		Enums.EffectType.POWER_REGEN:
			priority += 5 if target.combatant.power < target.combatant.max_power * 0.3 else 3
		# Damage Reduction (Always useful, medium priority)
		Enums.EffectType.DAMAGE_REDUCTION_ALL:
			priority += 12
		Enums.EffectType.DAMAGE_REDUCTION_KINETIC:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_ENERGY:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_PLASMA:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE:
			priority += 6
	return priority


func evaluate_offensive_effect_priority(target: MapCombatEntity, effect: ItemEffect) -> int:
	"""
	Assigns a priority value to an offensive effect targeting a specific entity.
	"""
	var priority = 0

	# Factor 1: Threat level by size (larger = more threatening)

	priority += (target.combatant.template.size + 1) * (target.combatant.template.size + 1)

	# Factor 2: Target state sensitivity.

	if target.combatant.health < target.combatant.max_health * 0.25:
		priority += 10
	elif target.combatant.health < target.combatant.max_health * 0.5:
		priority += 5

	if target.combatant.shield < target.combatant.max_shield * 0.25:
		priority += 6
	elif target.combatant.shield < target.combatant.max_shield * 0.5:
		priority += 3

	if target.combatant.armor < target.combatant.max_armor * 0.25:
		priority += 4
	elif target.combatant.armor < target.combatant.max_armor * 0.5:
		priority += 2

	# Factor 3: Effect-Specific Logic.

	if effect.type == Enums.EffectType.DAMAGE:
		# Scale based on raw damage amount.
		priority += clamp(effect.amount / 10.0, 1, 10)

	elif effect.type == Enums.EffectType.DAMAGE_OVER_TIME:
		# Prefer refreshing a DOT only if it will extend the remaining duration.
		if not target.combatant.active_effect_manager.should_refresh_dot(effect):
			priority -= 8
		else:
			# Scale based on damage per second and duration.
			priority += clamp((effect.amount * effect.duration) / 5.0, 1, 8)

	elif (
		effect.type
		in [
			Enums.EffectType.ACCURACY_MODIFIER,
			Enums.EffectType.RANGE_MODIFIER,
			Enums.EffectType.COOLDOWN_MODIFIER,
		]
	):
		# Higher priority for debuffs, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 4, 16)
	elif (
		effect.type
		in [
			Enums.EffectType.POWER_MODIFIER,
			Enums.EffectType.HEALTH_MODIFIER,
			Enums.EffectType.ARMOR_MODIFIER,
			Enums.EffectType.SHIELD_MODIFIER,
		]
	):
		# Moderate priority for debuffs, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 2, 8)
	elif effect.type == Enums.EffectType.SPEED_MODIFIER:
		# High priority for speed debuffs, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 4, 16)
	elif (
		effect.type
		in [
			Enums.EffectType.HEALTH_REGEN,
			Enums.EffectType.SHIELD_REGEN,
			Enums.EffectType.ARMOR_REGEN,
			Enums.EffectType.POWER_REGEN,
		]
	):
		# Moderate priority for regeneration reduction, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 3, 12)
	elif effect.type == Enums.EffectType.DAMAGE_REDUCTION_ALL:
		# Moderate priority for damage reduction debuffs, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 3, 12)
	elif (
		effect.type
		in [
			Enums.EffectType.DAMAGE_REDUCTION_KINETIC,
			Enums.EffectType.DAMAGE_REDUCTION_ENERGY,
			Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE,
			Enums.EffectType.DAMAGE_REDUCTION_PLASMA,
			Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE,
		]
	):
		# Lower priority for specific damage reduction debuffs, scaled by amount.
		if effect.amount < 0:
			priority += clamp(abs(effect.amount), 2, 8)
	else:
		# Default case for any other effect types (shouldn't happen for offensive modules).
		priority += 0

	# Cap to prevent over-prioritization.
	return clamp(priority, 0, 25)


func score_utility_module_on_target(
	module: ItemModule, source: MapCombatEntity, target: MapCombatEntity
) -> int:
	"""
	Calculates the total priority score for a module on a target.
	"""
	var total: int = 0
	for effect in module.effects:
		if effect.target == Enums.TargetType.SELF and target != source:
			continue
		if effect.target == Enums.TargetType.ALLY and target == source:
			continue
		if effect.target == Enums.TargetType.ENEMY and target == source:
			continue
		total += evaluate_utility_effect_priority(target, effect)
	return total


func score_offensive_module_on_target(module: ItemModule, target: MapCombatEntity) -> int:
	"""
	Calculates the total priority score for a module on a target.
	"""
	var total: int = 0
	for effect in module.effects:
		total += evaluate_offensive_effect_priority(target, effect)
	return total


# =====================================================================
# MODULE FILTERING FUNCTIONS
# =====================================================================


func can_module_be_used_now(combatant: CombatActor, item: Item, module: ItemModule) -> bool:
	"""
	Checks if a module can be used based on its cooldown and power requirements.
	"""
	if not combatant or not item or not module:
		return false
	if not has_item_equipped(combatant, item) or not has_item_module(item, module):
		return false
	if module.passive or not combatant.cooldown_manager:
		return false
	if combatant.cooldown_manager.is_on_cooldown(item, module):
		return false

	# Structures consume their base power usage immediately when equipping items,
	# but should still be able to use their modules if they have sufficient total
	# power capacity. Use max_power for structures so weapon modules are not
	# excluded just because the structure has "spent" its base equipment power.
	var available_power: int = combatant.power
	if is_instance_of(combatant, Structure):
		var reserved: int = 0
		for equipped_item in combatant.items:
			if equipped_item and equipped_item.template:
				reserved += int(equipped_item.template.base_power_usage)
		available_power += reserved

	if available_power < module.power_on_use:
		return false
	return true


func has_item_equipped(combatant: CombatActor, item: Item) -> bool:
	if not combatant or not item:
		return false
	for equipped_item: Item in combatant.items:
		if equipped_item == item:
			return true
		if equipped_item and equipped_item.uuid == item.uuid:
			return true
	return false


func has_item_module(item: Item, module: ItemModule) -> bool:
	if not item or not item.template or not module:
		return false
	for item_module: ItemModule in item.template.modules:
		if item_module == module:
			return true
	return false


func is_equipped_module_available(combatant: CombatActor, equipped_module: EquippedModule) -> bool:
	if not combatant or not equipped_module:
		return false
	if not equipped_module.validate():
		return false
	if equipped_module.mek != combatant:
		return false
	if not has_item_equipped(combatant, equipped_module.item):
		return false
	if not has_item_module(equipped_module.item, equipped_module.module):
		return false
	return true


func get_offensive_min_range(module_range: int) -> int:
	if module_range <= 1:
		return 0
	if module_range <= 3:
		return 1
	return 2


func find_matching_modules(
	combatant: CombatActor,
	offensive: bool,
	include_passive: bool,
	include_on_cooldown: bool,
) -> Array[EquippedModule]:
	"""
	Returns a list of modules matching the requested type (offensive or utility).
	Flags control whether passive modules and modules on cooldown are included.
	"""
	var matching_modules: Array[EquippedModule] = []
	for item in combatant.items:
		# Filter by slot type based on offensive flag.
		if offensive and item.template.slot == Enums.SlotType.UTILITY:
			continue
		if not offensive and item.template.slot != Enums.SlotType.UTILITY:
			continue
		for module in item.template.modules:
			# Optionally skip passive modules.
			if not include_passive and module.passive:
				continue
			# Optionally skip modules on cooldown.
			if not include_on_cooldown and combatant.cooldown_manager.is_on_cooldown(item, module):
				continue
			# Always skip if not enough power.
			if combatant.power < module.power_on_use:
				continue
			# Add the module if all checks passed.
			matching_modules.append(EquippedModule.new(combatant, item, module))
	return matching_modules
