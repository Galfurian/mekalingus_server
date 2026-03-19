class_name Structure
extends CombatEntity

# =============================================================================
# PROPERTIES
# =============================================================================

var structure_id: String = ""
var template: StructureTemplate = null

# =============================================================================
# GENERAL
# =============================================================================


func _init(
	p_uuid: String,
	p_structure_id: String,
	p_template: StructureTemplate,
) -> void:
	super(p_uuid)
	structure_id = p_structure_id
	template = p_template
	# Simply intialize the combat state based on the template values.
	rebuild_combat_state()


func get_structure_name() -> String:
	if alias.is_empty():
		return structure_id
	return alias


func get_chat_tag() -> String:
	return MetaTag.structure_tag(uuid, get_structure_name())


func get_icon_path() -> String:
	if template and not template.icon.is_empty():
		return template.icon
	return ""


func rebuild_combat_state() -> void:
	var stats_payload: Dictionary = {
		"health": template.health,
		"armor": template.armor,
		"shield": template.shield,
		"power": template.power,
		"max_health": template.health,
		"max_armor": template.armor,
		"max_shield": template.shield,
		"max_power": template.power,
		"health_generation": template.health_generation,
		"armor_generation": template.armor_generation,
		"shield_generation": template.shield_generation,
		"power_generation": template.power_generation,
		"speed": template.speed,
		"sensor_range": template.sensor_range,
	}
	rebuild_combat_state_with_items(stats_payload, template.slots)


static func from_dict(data: Dictionary = {}) -> Structure:
	"""Loads Structure instance data from a dictionary."""
	if not data.has("structure_id"):
		push_error("Invalid Structure data: Missing required fields")
		return null
	# Get the UUID
	var p_uuid = str(data["uuid"])
	# Get the Structure ID.
	var p_structure_id = str(data["structure_id"])
	# Get the template.
	var p_template = TemplateManager.get_structure_template(p_structure_id)
	if not p_template:
		push_error("Invalid Structure data: unknown Structure template '%s'" % p_structure_id)
		return null
	# Create the Structure instance.
	var structure: Structure = Structure.new(p_uuid, p_structure_id, p_template)
	# Set the alias if it exists.
	structure.alias = str(data.get("alias", ""))
	# Reconstruct items.
	structure.items.clear()
	for item_data: Dictionary in data.get("items", []):
		structure.items.append(Item.new(item_data))
	structure.items.sort_custom(Item.compare_items)
	# Get the slots.
	structure.slots = Utils.to_array_int(data.get("slots", []))
	# Load the AI thought log.
	structure.ai_thought_log.clear()
	for thought_data: Dictionary in data.get("ai_thought_log", []):
		structure.ai_thought_log.append(thought_data)
	# Rebuild combat state based on template values and items.
	structure.rebuild_combat_state()
	return structure


func to_dict() -> Dictionary:
	"""Converts Structure instance data to a dictionary."""
	var data: Dictionary = super.to_dict()
	data["structure_id"] = structure_id
	return data
