extends Node

# =====================================================================
# MODULE FILTERING FUNCTIONS
# =====================================================================


func can_module_be_used_now(combatant: CombatEntity, equipped_module: EquippedModule) -> bool:
	"""
	Checks if a module can be used based on its cooldown and power requirements.
	"""
	if not combatant or not equipped_module:
		return false
	if not has_item_equipped(combatant, equipped_module.item):
		return false
	if not has_item_module(equipped_module.item, equipped_module.module):
		return false
	if equipped_module.module.passive or not combatant.cooldown_manager:
		return false
	if combatant.cooldown_manager.is_on_cooldown(equipped_module.item, equipped_module.module):
		return false
	if combatant.power < equipped_module.module.power_on_use:
		return false
	return true


func has_item_equipped(combatant: CombatEntity, item: Item) -> bool:
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


func is_equipped_module_available(combatant: CombatEntity, equipped_module: EquippedModule) -> bool:
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


func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func get_max_module_range(
	source: MapCombatEntity,
	modules: Array[EquippedModule],
) -> int:
	var max_range: int = 0
	var range_modifier: int = source.combatant.get_stat(Enums.StatType.RANGE_MODIFIER)
	for equipped_module: EquippedModule in modules:
		var range_with_modifier: int = equipped_module.module.module_range + range_modifier
		max_range = maxi(max_range, range_with_modifier)
	return max_range


func find_matching_modules(
	combatant: CombatEntity,
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
