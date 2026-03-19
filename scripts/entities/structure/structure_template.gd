class_name StructureTemplate
extends Node

# Unique identifier for the Mek template.
var id: String
# The name of the Structure.
var structure_name: String
# The size category of the Structure.
var size: Enums.EntitySize
# The base health of the Structure, determining its durability.
var health: int
# The rate at which health regenerates per turn.
var health_generation: int
# The base armor value, reducing incoming kinetic and explosive damage.
var armor: int
# The rate at which armor regenerates per turn.
var armor_generation: int
# The base shield value, absorbing energy and explosive damage before armor is hit.
var shield: int
# The rate at which shields regenerate per turn.
var shield_generation: int
# The total power capacity of the Structure, used for activating items.
var power: int
# The amount of power regenerated per turn.
var power_generation: int
# The movement speed of the Structure, affecting turn order and repositioning.
var speed: int
# The sensor range of the Structure, defining how far it can detect enemies.
var sensor_range: int
# Slot configuration for equipping items.
# Each index represents a slot size (e.g., small, medium, large, utility).
var slots: Array[int]
# The icon representing the Structure in the UI.
var icon: String
# The type of the Structure.
var structure_type: String
# The subtype of the Structure, used for more specific categorization.
var structure_sub_type: String
# Whether the Structure is passable by other entities.
var passable: bool


func _init(_id: String = "", data: Dictionary = {}):
	id = _id
	if data:
		from_dict(data)


func is_valid() -> bool:
	return id != "" and health > 0 and armor >= 0 and shield >= 0 and sensor_range > 0


func from_dict(data: Dictionary):
	if not data.has("name"):
		push_error("Invalid StructureTemplate data: Missing required fields")
		return

	structure_name = str(data["name"])
	size = Utils.string_to_enum(Enums.EntitySize, data["size"])
	health = int(data["health"])
	health_generation = int(data.get("health_generation", 0))
	armor = int(data["armor"])
	armor_generation = int(data.get("armor_generation", 0))
	shield = int(data["shield"])
	shield_generation = int(data["shield_generation"])
	power = int(data["power"])
	power_generation = int(data["power_generation"])
	speed = int(data["speed"])
	sensor_range = int(data["sensor_range"])
	slots = Utils.to_array_int(data["slots"])
	icon = data["icon"]
	structure_type = str(data["structure_type"])
	structure_sub_type = str(data["structure_sub_type"])
	passable = bool(data["passable"])


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": structure_name,
		"size": Utils.enum_to_string(Enums.EntitySize, size),
		"health": health,
		"health_generation": health_generation,
		"armor": armor,
		"armor_generation": armor_generation,
		"shield": shield,
		"shield_generation": shield_generation,
		"power": power,
		"power_generation": power_generation,
		"speed": speed,
		"sensor_range": sensor_range,
		"slots": slots,
		"icon": icon,
		"structure_type": structure_type,
		"structure_sub_type": structure_sub_type,
		"passable": passable,
	}
