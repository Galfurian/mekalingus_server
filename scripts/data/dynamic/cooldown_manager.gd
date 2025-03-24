extends RefCounted

class_name CooldownManager

# =============================================================================
# MANAGES MODULE COOLDOWNS
# =============================================================================
# This class tracks cooldowns for modules, ensuring they cannot be used until
# their cooldown period expires.

# Dictionary mapping module names to remaining cooldown turns.
var cooldowns: Dictionary = {}

# =============================================================================
# GENERAL METHODS
# =============================================================================

func _get_key(item: Item, module: ItemModule) -> String:
	"""Unique key using item UUID + module name."""
	return item.uuid + ":" + module.name

func start_cooldown(item: Item, module: ItemModule):
	"""Starts the cooldown timer for the given module."""
	if module.cooldown > 0:
		cooldowns[_get_key(item, module)] = module.cooldown + 1

func decrement_cooldowns():
	"""Decreases cooldown counters and removes expired cooldowns."""
	var modules_to_remove = []
	for key in cooldowns.keys():
		cooldowns[key] -= 1
		if cooldowns[key] <= 0:
			modules_to_remove.append(key)
	for key in modules_to_remove:
		cooldowns.erase(key)

func is_on_cooldown(item: Item, module: ItemModule) -> bool:
	"""Returns true if the specified module is on cooldown."""
	return _get_key(item, module) in cooldowns

func get_remaining_cooldown(item: Item, module: ItemModule) -> int:
	"""Returns the remaining cooldown time for a module, or 0 if not on cooldown."""
	return cooldowns.get(_get_key(item, module), 0)

func clear():
	"""Clears all cooldowns (used when combat ends)."""
	cooldowns.clear()
