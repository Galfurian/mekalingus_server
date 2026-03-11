class_name Structure
extends "res://scripts/data/combat/combat_actor.gd"

var structure_id: String
var structure_name: String
var template = null


func _init(data: Dictionary = {}) -> void:
	items = []
	slots = []
	initialize_runtime_managers()
	from_dict(data)


func get_structure_name() -> String:
	if alias.is_empty():
		if structure_name.is_empty():
			return structure_id
		return structure_name
	return alias


func get_chat_tag() -> String:
	return "[url=structure:" + uuid + "]" + get_structure_name() + "[/url]"


func rebuild_combat_state() -> void:
	var base_stats := {
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"max_armor": max_armor,
		"shield": shield,
		"max_shield": max_shield,
		"power": power,
		"max_power": max_power,
		"health_generation": health_generation,
		"armor_generation": armor_generation,
		"shield_generation": shield_generation,
		"power_generation": power_generation,
		"speed": speed,
	}
	if template:
		base_stats = {
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
		rebuild_combat_state_with_items(base_stats, template.slots)
		return

	rebuild_combat_state_with_items(base_stats, slots)


func from_dict(data: Dictionary = {}) -> bool:
	if not data.has("uuid"):
		uuid = GameServer.generate_uuid()
	else:
		uuid = data["uuid"]
	alias = data.get("alias", "")
	structure_id = data.get("structure_id", "")
	items.clear()
	for item_data in data.get("items", []):
		items.append(Item.new(item_data))
	items.sort_custom(Item.compare_items)

	if not structure_id.is_empty():
		template = TemplateManager.get_structure_template(structure_id)
		if template:
			structure_name = template.structure_name

	if not template:
		structure_name = data.get("structure_name", structure_name)
		health = int(data.get("health", 0))
		max_health = int(data.get("max_health", health))
		armor = int(data.get("armor", 0))
		max_armor = int(data.get("max_armor", armor))
		shield = int(data.get("shield", 0))
		max_shield = int(data.get("max_shield", shield))
		power = int(data.get("power", 0))
		max_power = int(data.get("max_power", power))
		health_generation = int(data.get("health_generation", 0))
		armor_generation = int(data.get("armor_generation", 0))
		shield_generation = int(data.get("shield_generation", 0))
		power_generation = int(data.get("power_generation", 0))
		speed = int(data.get("speed", 0))
		slots = Utils.to_array_int(data.get("slots", []))

	rebuild_combat_state()
	GameServer.occupy_uuid(uuid)
	return true


func to_dict() -> Dictionary:
	return {
		"uuid": uuid,
		"alias": alias,
		"structure_id": structure_id,
		"structure_name": structure_name,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"max_armor": max_armor,
		"shield": shield,
		"max_shield": max_shield,
		"power": power,
		"max_power": max_power,
		"health_generation": health_generation,
		"armor_generation": armor_generation,
		"shield_generation": shield_generation,
		"power_generation": power_generation,
		"speed": speed,
		"slots": slots,
		"items": Utils.convert_objects_to_dict(items),
	}
