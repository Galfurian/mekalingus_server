class_name Mek
extends CombatActor

# =============================================================================
# PROPERTIES
# =============================================================================

# Unique identifier of the Mek template.
var mek_id: String
# Reference to the Mek template.
var template = null

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	"""Initializes a Mek instance from a dictionary."""
	items = []
	slots = []
	initialize_runtime_managers()
	from_dict(data)


static func compare_meks(a: Mek, b: Mek) -> bool:
	"""Sorts meks first by size, then by name alphabetically."""
	if a.template.size == b.template.size:
		return a.get_mek_name().to_lower() > b.get_mek_name().to_lower()
	return a.template.size < b.template.size


func rebuild_combat_state():
	"""Rebuilds dynamic combat state from template values plus passive item effects."""
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


# =============================================================================
# SERIALIZATION
# =============================================================================


func get_mek_name() -> String:
	"""
	Returns the Mek's name.
	"""
	if alias.is_empty():
		return template.mek_name
	return alias


func get_chat_tag() -> String:
	"""
	Returns a chat tag for the Mek.
	"""
	return MetaTag.mek_tag(uuid, get_mek_name())


func get_icon_path() -> String:
	if template and not template.icon.is_empty():
		return template.icon
	return ""


func _to_string() -> String:
	return "Mek<" + mek_id + ", " + uuid + ">"


func from_dict(data: Dictionary = {}) -> bool:
	"""Loads Mek instance data from a dictionary."""
	if not data.has("mek_id"):
		push_error("Invalid Mek data: Missing required fields")
		return false

	# Load basic fields.
	super(data)

	# Load mek-specific fields.
	mek_id = str(data["mek_id"])

	# Load the template.
	template = TemplateManager.get_mek_template(mek_id)
	assert(template, "Cannot find the template: " + mek_id + "\n")

	# Rebuild combat state based on template values and items.
	rebuild_combat_state()

	return true


func to_dict() -> Dictionary:
	"""Converts Mek instance data to a dictionary."""
	var data: Dictionary = super()
	data["mek_id"] = mek_id
	return data
