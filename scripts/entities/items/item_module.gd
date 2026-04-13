# The ItemModule class represents a module that is associated with an Item. It
# represents one of its abilities or effects. Modules can be passive or active,
# and can have a variety of effects.
class_name ItemModule
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# The module's name.
var module_name: String
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
var effects: Array[BaseEffect]
# Runtime states required to activate this module.
var required_states: Array[int] = []
# Runtime states that prevent this module from activating.
var blocked_states: Array[int] = []
# Runtime states granted by this module when used.
var grants_states: Array[int] = []
# Runtime states removed by this module when used.
var clears_states: Array[int] = []
# Optional stat modifiers applied while a granted state is active.
var state_stat_modifiers: Dictionary = {}

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
	return "Module<" + module_name + ">"


func from_dict(data: Dictionary):
	"""
	Loads module data from a dictionary.
	"""
	if not data.has("name") or not data.has("effects"):
		push_error("Invalid Module data: Missing required fields")
		return
	module_name = data["name"]
	passive = bool(data.get("passive", false))
	power_on_use = int(data.get("power_on_use", 0))
	cooldown = int(data.get("cooldown", 0))
	module_range = int(data.get("module_range", 0))
	repeats = int(data.get("repeats", 1))
	required_states = _to_state_array(data.get("required_states", []))
	blocked_states = _to_state_array(data.get("blocked_states", []))
	grants_states = _to_state_array(data.get("grants_states", []))
	clears_states = _to_state_array(data.get("clears_states", []))
	state_stat_modifiers = _parse_state_stat_modifiers(data.get("state_stat_modifiers", {}))
	effects.clear()
	for effect_data in data["effects"]:
		var effect := EffectFactory.create_from_dict(effect_data)
		if not effect:
			push_error(
				"Failed to create effect for module '%s' from data: %s" % [module_name, effect_data]
			)
			continue
		if passive and effect.duration > 0:
			push_error(
				(
					"Invalid module '%s': passive modules cannot have effects with duration (effect '%s')"
					% [module_name, effect.get_effect_type_label()]
				)
			)
			continue
		if not passive and effect.duration <= 0:
			if not effect.is_damage() and not effect.is_repair():
				push_error(
					(
						"Invalid module '%s': effect '%s' requires a positive duration"
						% [module_name, effect.get_effect_type_label()]
					)
				)
				continue
		effects.append(effect)


func to_dict() -> Dictionary:
	"""
	Converts module data to a dictionary.
	"""
	return {
		"name": module_name,
		"passive": passive,
		"power_on_use": power_on_use,
		"cooldown": cooldown,
		"module_range": module_range,
		"repeats": repeats,
		"required_states": _serialize_states(required_states),
		"blocked_states": _serialize_states(blocked_states),
		"grants_states": _serialize_states(grants_states),
		"clears_states": _serialize_states(clears_states),
		"state_stat_modifiers": _serialize_state_stat_modifiers(),
		"effects": Utils.convert_objects_to_dict(effects)
	}


func _to_state_array(raw_states: Variant) -> Array[int]:
	var output: Array[int] = []
	if typeof(raw_states) != TYPE_ARRAY:
		return output
	for raw_state in raw_states:
		var state_value: int = -1
		if typeof(raw_state) == TYPE_INT:
			state_value = int(raw_state)
		else:
			state_value = Enums.get_runtime_state_from_key(str(raw_state).strip_edges())
		if state_value < 0:
			push_error(
				"Invalid runtime state '%s' in module '%s'" % [str(raw_state), module_name]
			)
			continue
		if state_value in output:
			continue
		output.append(state_value)
	return output


func _serialize_states(states: Array[int]) -> Array[String]:
	var serialized: Array[String] = []
	for state_value in states:
		serialized.append(Enums.get_runtime_state_key(int(state_value)))
	return serialized


func _parse_state_stat_modifiers(raw_modifiers: Variant) -> Dictionary:
	var output: Dictionary = {}
	if typeof(raw_modifiers) != TYPE_DICTIONARY:
		return output

	for raw_stat_key in raw_modifiers.keys():
		var stat: int = Enums.get_stat_from_key(str(raw_stat_key))
		if stat < 0:
			push_error(
				"Invalid state_stat_modifiers stat key '%s' in module '%s'"
				% [str(raw_stat_key), module_name]
			)
			continue
		output[stat] = int(raw_modifiers[raw_stat_key])

	return output


func _serialize_state_stat_modifiers() -> Dictionary:
	var output: Dictionary = {}
	for stat in state_stat_modifiers.keys():
		output[Enums.get_stat_key(int(stat))] = int(state_stat_modifiers[stat])
	return output
