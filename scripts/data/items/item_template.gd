class_name ItemTemplate
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# The item's id.
var id: String
# The item's name.
var name: String
# The item's slot type (e.g., SMALL, MEDIUM, LARGE, UTILITY).
var slot: Enums.SlotType
# The amount of power passively used while equipped.
var base_power_usage: int
# List of modules this item contains.
var modules: Array[ItemModule]

# =============================================================================
# GENERAL
# =============================================================================


func _init(item_id: String = "", item_data: Dictionary = {}):
	"""
	Initializes the item with the given data.
	"""
	id = item_id
	if item_data:
		from_dict(item_id, item_data)


func is_valid() -> bool:
	"""
	Returns true if the item has a valid name and modules.
	"""
	return name != "" and base_power_usage >= 0 and not modules.is_empty()


func build_item(uuid: String = GameServer.generate_uuid()) -> Item:
	"""
	Builds a Mek starting from this template.
	"""
	return Item.new({"item_id": id, "uuid": uuid})


# =============================================================================
# MODULE HANDLING
# =============================================================================


func get_passive_modules() -> Array[ItemModule]:
	"""
	Returns all passive modules this item provides.
	"""
	var passive_modules: Array[ItemModule] = []
	for module in modules:
		if module.passive:
			passive_modules.append(module)
	return passive_modules


func get_active_modules() -> Array[ItemModule]:
	"""
	Returns all active modules this item provides.
	"""
	var active_modules: Array[ItemModule] = []
	for module in modules:
		if not module.passive:
			active_modules.append(module)
	return active_modules


# =============================================================================
# POWER COMPUTATION
# =============================================================================


func evaluate_item_template_power() -> float:
	# Step 1: Sum the power of all modules
	var module_power_total := 0.0
	for module in modules:
		module_power_total += module.evaluate_module_power()

	# Step 2: Compute passive power usage penalty (scaling factor: 0.1)
	var passive_cost_penalty := float(base_power_usage) * 0.1

	# Step 3: Compute activation cost penalty for active modules
	var activation_cost_penalty := 0.0
	for module in modules:
		if not module.passive:
			activation_cost_penalty += float(module.power_on_use) * 0.1

	# Step 4: Final score (rounded)
	return round(module_power_total - passive_cost_penalty - activation_cost_penalty)


# =============================================================================
# SERIALIZATION
# =============================================================================


func from_dict(item_id: String, data: Dictionary):
	"""Loads item data from a dictionary."""
	if not data.has("name") or not data.has("slot") or not data.has("modules"):
		push_error("Invalid Item data: Missing required fields")
		return
	id = item_id
	name = data["name"]
	slot = Utils.string_to_enum(Enums.SlotType, data["slot"])
	base_power_usage = int(data.get("base_power_usage", 0))
	modules.clear()
	for module_data in data["modules"]:
		modules.append(ItemModule.new(module_data))


func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	return {
		"id": id,
		"name": name,
		"slot": Utils.enum_to_string(Enums.SlotType, slot),
		"base_power_usage": base_power_usage,
		"modules": Utils.convert_objects_to_dict(modules)
	}
