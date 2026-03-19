class_name Mek
extends CombatEntity

# =============================================================================
# PROPERTIES
# =============================================================================

# Unique identifier of the Mek template.
var mek_id: String = ""
# Reference to the Mek template.
var template: MekTemplate = null

# =============================================================================
# GENERAL
# =============================================================================


func _init(
	p_uuid: String,
	p_mek_id: String,
	p_template: MekTemplate,
) -> void:
	super(p_uuid)
	mek_id = p_mek_id
	template = p_template
	# Simply intialize the combat state based on the template values.
	rebuild_combat_state()


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
		"health_generation": 0,
		"armor": template.armor,
		"max_armor": template.armor,
		"armor_generation": 0,
		"shield": template.shield,
		"max_shield": template.shield,
		"power": template.power,
		"max_power": template.power,
		"shield_generation": template.shield_generation,
		"power_generation": template.power_generation,
		"speed": template.speed,
		"sensor_range": template.sensor_range,
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


static func from_dict(data: Dictionary = {}) -> Mek:
	"""Loads Mek instance data from a dictionary."""
	if not data.has("mek_id"):
		push_error("Invalid Mek data: Missing required fields")
		return null
	# Get the UUID
	var p_uuid = str(data["uuid"])
	# Get the Mek ID.
	var p_mek_id = str(data["mek_id"])
	# Get the template.
	var p_template = TemplateManager.get_mek_template(p_mek_id)
	if not p_template:
		push_error("Invalid Mek data: unknown Mek template '%s'" % p_mek_id)
		return null
	# Creat the Mek instance.
	var mek: Mek = Mek.new(p_uuid, p_mek_id, p_template)
	# Set the alias if it exists.
	mek.alias = str(data.get("alias", ""))
	# Reconstruct items.
	mek.items.clear()
	for item_data: Dictionary in data.get("items", []):
		mek.items.append(Item.new(item_data))
	mek.items.sort_custom(Item.compare_items)
	# Get the slots.
	mek.slots = Utils.to_array_int(data.get("slots", []))
	# Load the AI thought log.
	mek.ai_thought_log.clear()
	for thought_data: Dictionary in data.get("ai_thought_log", []):
		mek.ai_thought_log.append(thought_data)
	# Rebuild combat state based on template values and items.
	mek.rebuild_combat_state()
	return mek


func to_dict() -> Dictionary:
	"""Converts Mek instance data to a dictionary."""
	var data: Dictionary = super.to_dict()
	data["mek_id"] = mek_id
	return data
