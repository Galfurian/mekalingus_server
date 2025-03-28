class_name Item
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# Unique identifier of the item template.
var item_id: String
# Unique instance identifier.
var uuid: String
# Reference to the item template.
var template: ItemTemplate

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	"""
	Initializes an Item instance from a dictionary.
	"""
	from_dict(data)


func is_valid() -> bool:
	"""
	Checks if the item instance is valid.
	"""
	return item_id != "" and template != null


static func compare_items(a: Item, b: Item) -> bool:
	"""
	Sorts items first by slot type (SMALL -> MEDIUM -> LARGE -> UTILITY), then by name alphabetically.
	"""
	if a.template.slot == b.template.slot:
		return a.template.name.to_lower() > b.template.name.to_lower()
	return a.template.slot < b.template.slot

# =============================================================================
# POWER COMPUTATION
# =============================================================================


func evaluate_item_power() -> float:
	"""
	Computes the total power level of the Item.
	"""
	return template.evaluate_item_template_power()

# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	return "Item<" + item_id + ", " + uuid + ">"


func from_dict(data: Dictionary = {}) -> bool:
	"""Loads item instance data from a dictionary."""
	if not data.has("item_id"):
		push_error("Invalid Item data: Missing required fields")
		return false

	item_id = data["item_id"]
	uuid = data["uuid"]

	# Mark the UUID as used.
	GameServer.occupy_uuid(uuid)

	# Load the template.
	template = TemplateManager.get_item_template(item_id)
	assert(template, "Cannot find the template: " + item_id + "\n")

	return true


func to_dict() -> Dictionary:
	"""Converts item instance data to a dictionary."""
	return {"item_id": item_id, "uuid": uuid}


func to_client_dict() -> Dictionary:
	"""Converts Mek instance data to a dictionary."""
	return {"item_id": item_id, "uuid": uuid}
