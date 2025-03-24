extends RefCounted

class_name ItemModule

# =============================================================================
# PROPERTIES
# =============================================================================

# The module's name.
var name: String
# Whether the module is passive (true) or active (false).
var passive: bool
# The power required to activate the module (if active).
var power_on_use: int
# Cooldown in turns before the module can be used again (if active).
var cooldown: int
# The range of the module's effect (if applicable).
var module_range: int
# List of effects this module applies.
var effects: Array[ItemEffect]

# =============================================================================
# GENERAL
# =============================================================================

func _init(module_data: Dictionary = {}):
	if module_data:
		from_dict(module_data)

# =============================================================================
# SERIALIZATION
# =============================================================================

func _to_string() -> String:
	return "Module<" + name + ">"

func from_dict(data: Dictionary):
	"""Loads module data from a dictionary."""
	if not data.has("name") or not data.has("effects"):
		push_error("Invalid Module data: Missing required fields")
		return
	name = data["name"]
	passive = bool(data.get("passive", false))
	power_on_use = int(data.get("power_on_use", 0))
	cooldown = int(data.get("cooldown", 0))
	module_range = int(data.get("module_range", 0))
	effects.clear()
	for effect_data in data["effects"]:
		effects.append(ItemEffect.new(effect_data))

func to_dict() -> Dictionary:
	"""Converts module data to a dictionary."""
	return {
		"name": name,
		"passive": passive,
		"power_on_use": power_on_use,
		"cooldown": cooldown,
		"module_range": module_range,
		"effects": Utils.convert_objects_to_dict(effects)
	}
