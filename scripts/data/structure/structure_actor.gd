class_name StructureActor
extends "res://scripts/data/combat/combat_actor.gd"

var structure_name: String


func _init(
	p_structure_name: String,
	p_max_health: int,
	p_armor: int,
	p_items: Array[Item] = []
) -> void:
	structure_name = p_structure_name
	items = p_items
	slots = []
	active_effect_manager = ActiveEffectManager.new(self)
	cooldown_manager = CooldownManager.new(self)

	health = p_max_health
	max_health = p_max_health

	armor = p_armor
	max_armor = p_armor

	shield = 0
	max_shield = 0

	power = 0
	max_power = 0

	health_generation = 0
	armor_generation = 0
	shield_generation = 0
	power_generation = 0
	speed = 0

	damage_reduction_all = 0
	damage_reduction_kinetic = 0
	damage_reduction_energy = 0
	damage_reduction_explosive = 0
	damage_reduction_plasma = 0
	damage_reduction_corrosive = 0

	accuracy_modifier = 0
	range_modifier = 0
	cooldown_modifier = 0


func to_dict() -> Dictionary:
	return {
		"structure_name": structure_name,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"max_armor": max_armor,
		"shield": shield,
		"max_shield": max_shield,
		"power": power,
		"max_power": max_power,
		"items": Utils.convert_objects_to_dict(items),
	}


static func from_dict(data: Dictionary) -> StructureActor:
	if not data.has_all(["structure_name", "max_health", "armor", "items"]):
		push_error("Invalid StructureActor data: Missing required fields")
		return null

	var loaded_items: Array[Item] = []
	for item_data in data["items"]:
		loaded_items.append(Item.new(item_data))

	var actor := StructureActor.new(
		data["structure_name"],
		data["max_health"],
		data["armor"],
		loaded_items,
	)

	actor.health = int(data.get("health", actor.max_health))
	actor.max_armor = int(data.get("max_armor", actor.armor))
	actor.shield = int(data.get("shield", 0))
	actor.max_shield = int(data.get("max_shield", 0))
	actor.power = int(data.get("power", 0))
	actor.max_power = int(data.get("max_power", 0))

	return actor
