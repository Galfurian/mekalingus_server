class_name Structure
extends CombatActor

var structure_id: String
var template: StructureTemplate = null


func _init(data: Dictionary = {}) -> void:
	items = []
	slots = []
	initialize_runtime_managers()
	from_dict(data)


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
		"max_health": template.health,
		"armor": template.armor,
		"max_armor": template.armor,
		"shield": template.shield,
		"max_shield": template.shield,
		"power": template.power,
		"max_power": template.power,
		"health_generation": 0,
		"armor_generation": 0,
		"shield_generation": template.shield_generation,
		"power_generation": template.power_generation,
		"speed": template.speed,
	}
	rebuild_combat_state_with_items(stats_payload, template.slots)


func from_dict(data: Dictionary = {}) -> bool:
	"""Loads Structure instance data from a dictionary."""
	if not data.has("structure_id"):
		push_error("Invalid Structure data: Missing required fields")
		return false

	# Load basic fields.
	super(data)

	# Load structure-specific fields.
	structure_id = str(data["structure_id"])

	# Load the template.
	template = TemplateManager.get_structure_template(structure_id)
	assert(template, "Structure template '%s' not found for structure '%s'." % [structure_id, uuid])

	# Rebuild combat state based on template values and items.
	rebuild_combat_state()

	return true


func to_dict() -> Dictionary:
	"""Converts Structure instance data to a dictionary."""
	var data: Dictionary = super()
	data["structure_id"] = structure_id
	return data
