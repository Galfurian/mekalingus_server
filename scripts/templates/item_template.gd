extends RefCounted

class_name ItemTemplate

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
	id = item_id
	if item_data:
		from_dict(item_id, item_data)

func is_valid() -> bool:
	"""Returns true if the item has a valid name and modules."""
	return name != "" and base_power_usage >= 0 and not modules.is_empty()

func build_item(uuid: String = GameServer.generate_uuid()) -> Item:
	"""Builds a Mek starting from this template."""
	return Item.new(
		{
			"item_id" : id,
			"uuid"    : uuid
		}
	)

# =============================================================================
# MODULE HANDLING
# =============================================================================

func get_passive_modules() -> Array[ItemModule]:
	"""Returns all passive modules this item provides."""
	var passive_modules: Array[ItemModule] = []
	for module in modules:
		if module.passive:
			passive_modules.append(module)
	return passive_modules

func get_active_modules() -> Array[ItemModule]:
	"""Returns all active modules this item provides."""
	var active_modules: Array[ItemModule] = []
	for module in modules:
		if not module.passive:
			active_modules.append(module)
	return active_modules

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
