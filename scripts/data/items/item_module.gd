# The ItemModule class represents a module that is associated with an Item. It
# represents one of its abilities or effects. Modules can be passive or active,
# and can have a variety of effects.
class_name ItemModule
extends RefCounted

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
# The number of times the module's behaviour is executed upon use.
var repeats: int
# List of effects this module applies.
var effects: Array[ItemEffect]

# =============================================================================
# GENERAL
# =============================================================================


func _init(module_data: Dictionary = {}):
	"""
	Initializes the module with the given data.
	"""
	if module_data:
		from_dict(module_data)


# =============================================================================
# POWER COMPUTATION
# =============================================================================


func evaluate_module_power() -> float:
	"""
	Computes the tactical power of the module based on its effects and properties.
	"""
	# Step 1: Compute total power of all effects
	var total_effect_power := 0.0
	for effect in effects:
		total_effect_power += effect.evaluate_effect_power(repeats)

	# Step 2: Apply cooldown factor
	var cooldown_factor := 1.5 if passive else 1.0 / sqrt(1.0 + float(cooldown))

	# Step 3: Apply range factor (default scaling is 10% per tile)
	var range_factor := 1.0 + float(module_range) * 0.1

	# Step 4: Final computed module power
	return total_effect_power * cooldown_factor * range_factor


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	return "Module<" + name + ">"


func from_dict(data: Dictionary):
	"""
	Loads module data from a dictionary.
	"""
	if not data.has("name") or not data.has("effects"):
		push_error("Invalid Module data: Missing required fields")
		return
	name = data["name"]
	passive = bool(data.get("passive", false))
	power_on_use = int(data.get("power_on_use", 0))
	cooldown = int(data.get("cooldown", 0))
	module_range = int(data.get("module_range", 0))
	repeats = int(data.get("repeats", 1))
	effects.clear()
	for effect_data in data["effects"]:
		effects.append(ItemEffect.new(effect_data))


func to_dict() -> Dictionary:
	"""
	Converts module data to a dictionary.
	"""
	return {
		"name": name,
		"passive": passive,
		"power_on_use": power_on_use,
		"cooldown": cooldown,
		"module_range": module_range,
		"repeats": repeats,
		"effects": Utils.convert_objects_to_dict(effects)
	}
