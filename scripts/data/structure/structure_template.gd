class_name StructureTemplate
extends Node

const StructureScript = preload("res://scripts/data/structure/structure.gd")

var id: String
var structure_name: String
var health: int
var armor: int
var shield: int
var shield_generation: int
var power: int
var power_generation: int
var speed: int
var slots: Array[int]
var icon: String


func _init(_id: String = "", data: Dictionary = {}):
	id = _id
	if data:
		from_dict(data)


func is_valid() -> bool:
	return id != "" and structure_name != "" and health > 0 and armor >= 0 and shield >= 0


func build_structure(uuid: String = GameServer.generate_uuid()):
	return StructureScript.new({"structure_id": id, "uuid": uuid})


func from_dict(data: Dictionary):
	if not data.has("name"):
		push_error("Invalid StructureTemplate data: Missing required fields")
		return

	structure_name = data["name"]
	health = int(data.get("health", 0))
	armor = int(data.get("armor", 0))
	shield = int(data.get("shield", 0))
	shield_generation = int(data.get("shield_generation", 0))
	power = int(data.get("power", 0))
	power_generation = int(data.get("power_generation", 0))
	speed = int(data.get("speed", 0))
	slots = Utils.to_array_int(data.get("slots", []))
	icon = data.get("icon", "")


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": structure_name,
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
