# This class represents a template for a Mek, containing all the base stats and
# configuration for a Mek unit. It is used to create Mek instances with the
# desired properties.
class_name MekTemplate
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# Unique identifier for the Mek template.
var id: String
# The name of the Mek.
var name: String
# The size category of the Mek, affecting mobility and load capacity.
var size: Enums.MekSize
# The base health of the Mek, determining its durability.
var health: int
# The base armor value, reducing incoming kinetic and explosive damage.
var armor: int
# The base shield value, absorbing energy and explosive damage before armor is hit.
var shield: int
# The rate at which shields regenerate per turn.
var shield_generation: int
# The total power capacity of the Mek, used for activating items.
var power: int
# The amount of power regenerated per turn.
var power_generation: int
# The movement speed of the Mek, affecting turn order and repositioning.
var speed: int
# Slot configuration for equipping items.
# Each index represents a slot size (e.g., small, medium, large, utility).
var slots: Array[int]
# The icon representing the Mek in the UI.
var icon: String

# =============================================================================
# GENERAL
# =============================================================================


func _init(_id: String = "", data: Dictionary = {}):
	id = _id
	if data:
		from_dict(data)


func is_valid() -> bool:
	"""Checks if the Mek template contains valid values."""
	return id != "" and name != "" and health > 0 and armor >= 0 and shield >= 0


func build_mek(uuid: String = GameServer.generate_uuid()) -> Mek:
	"""Builds a Mek starting from this template."""
	return Mek.new({"mek_id": id, "uuid": uuid})


# =============================================================================
# POWER COMPUTATION
# =============================================================================


func evaluate_mek_template_power() -> float:
	"""
	Computes the total power level of the Mek based on its stats and equipped items.
	"""
	var slot_power := 0.0
	for i in range(slots.size()):
		var slot_type := i
		var slot_count := slots[i]
		var stats = TemplateManager.slot_power_stats.get(slot_type, null)
		if stats:
			slot_power += stats["average"] * slot_count
	var stat_power := (
		health * 0.3
		+ armor * 0.3
		+ shield * 0.3
		+ shield_generation * 2.0
		+ power * 0.15
		+ power_generation * 1.0
		+ speed * 15.0
	)
	return round(slot_power + stat_power)


# =============================================================================
# SERIALIZATION
# =============================================================================


func from_dict(data: Dictionary):
	"""Loads Mek template data from a dictionary."""
	if not data.has("name") or not data.has("size") or not data.has("slots"):
		push_error("Invalid MekTemplate data: Missing required fields")
		return

	name = data["name"]
	size = Utils.string_to_enum(Enums.MekSize, data["size"])
	health = int(data.get("health", 0))
	armor = int(data.get("armor", 0))
	shield = int(data.get("shield", 0))
	shield_generation = int(data.get("shield_generation", 0))
	power = int(data.get("power", 0))
	power_generation = int(data.get("power_generation", 0))
	speed = int(data.get("speed", 0))
	slots = Utils.to_array_int(data["slots"])
	icon = data.get("icon", "")


func to_dict() -> Dictionary:
	"""Converts Mek template data to a dictionary."""
	return {
		"id": id,
		"name": name,
		"size": Utils.enum_to_string(Enums.MekSize, size),
		"health": health,
		"armor": armor,
		"shield": shield,
		"shield_generation": shield_generation,
		"power": power,
		"power_generation": power_generation,
		"speed": speed,
		"slots": slots,
		"icon": icon,
	}
