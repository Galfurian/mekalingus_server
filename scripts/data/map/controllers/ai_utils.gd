extends Node

# =====================================================================
# PRIORITY CALCULATION FUNCTIONS
# =====================================================================


func evaluate_utility_effect_priority(target: MapCombatEntity, effect: BaseEffect) -> int:
	"""
	Calculates a priority score for a specific effect on a specific target.
	"""
	return effect.get_ai_utility_priority(target)


func evaluate_offensive_effect_priority(target: MapCombatEntity, effect: BaseEffect) -> int:
	"""
	Assigns a priority value to an offensive effect targeting a specific entity.
	"""
	var priority: int = _get_target_state_priority(target) + effect.get_ai_offensive_priority(target)
	return clamp(priority, 0, 25)


func _get_target_state_priority(target: MapCombatEntity) -> int:
	var priority: int = (target.combatant.template.size + 1) * (target.combatant.template.size + 1)

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

	return priority


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
	if combatant.power < module.power_on_use:
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
