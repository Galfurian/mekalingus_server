extends "res://scripts/data/combat/combat_actor.gd"

class_name Mek

const MekPowerEvaluatorScript = preload("res://scripts/data/mek/power/mek_power_evaluator.gd")

# =============================================================================
# PROPERTIES
# =============================================================================

# Unique identifier of the Mek template.
var mek_id: String
# Reference to the Mek template.
var template: MekTemplate

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	"""Initializes a Mek instance from a dictionary."""
	items = []
	slots = []
	active_effect_manager = ActiveEffectManager.new(self)
	cooldown_manager = CooldownManager.new(self)
	from_dict(data)


static func compare_meks(a: Mek, b: Mek) -> bool:
	"""Sorts meks first by size, then by name alphabetically."""
	if a.template.size == b.template.size:
		return a.get_mek_name().to_lower() > b.get_mek_name().to_lower()
	return a.template.size < b.template.size


# =============================================================================
# ACTIVE EFFECTS
# =============================================================================


func add_effect(module: ItemModule, effect: ItemEffect, source: MapEntity) -> void:
	"""
	Adds a new time-based effect to this Mek.
	Creates an ActiveEffect instance and registers it in the ActiveEffectManager.
	"""
	var active = ActiveEffect.new(module, effect, source, effect.duration)
	active_effect_manager.add_active_effect(active)


func has_effect_type(effect_type: Enums.EffectType) -> bool:
	"""Returns true if this Mek currently has an active effect of the given type."""
	return active_effect_manager.has_effect_type(effect_type)


func clear_active_effects() -> void:
	"""Clears all ongoing active effects (used at end of combat)."""
	active_effect_manager.clear()


# =============================================================================
# PASSIVE EFFECTs MANAGEMENT
# =============================================================================


func _toggle_module_passive_effect_modifiers(module: ItemModule, enable: bool):
	"""Applies or removes passive or active effects for a module."""
	if module.passive:
		for effect in module.effects:
			effect.toggle_effect(self, enable)


func _toggle_item_passive_effect_modifiers(item: Item, enable: bool):
	"""Applies or removes passive or active effects for an item."""
	for module in item.template.modules:
		_toggle_module_passive_effect_modifiers(module, enable)


func _update_static_values():
	"""Recalculates max values, regen rates, and speed. Called only when necessary."""
	# Reset to template base values
	health = template.health
	armor = template.armor
	shield = template.shield
	power = template.power
	max_health = template.health
	max_armor = template.armor
	max_shield = template.shield
	max_power = template.power
	health_generation = 0
	armor_generation = 0
	shield_generation = template.shield_generation
	power_generation = template.power_generation
	speed = template.speed
	damage_reduction_all = 0
	damage_reduction_kinetic = 0
	damage_reduction_energy = 0
	damage_reduction_explosive = 0
	damage_reduction_plasma = 0
	damage_reduction_corrosive = 0
	accuracy_modifier = 0
	range_modifier = 0
	cooldown_modifier = 0

	# Apply effects from equipped items.
	for item in items:
		_enable_item_passive_modifiers(item)

	# Update the slots.
	slots = template.slots.duplicate()
	for item in items:
		slots[item.template.slot] -= 1


# =============================================================================
# ITEMS
# =============================================================================


func _enable_item_passive_modifiers(item: Item):
	"""Deactivates any passive and non-passive modules modifiers."""
	_toggle_item_passive_effect_modifiers(item, true)
	power -= item.template.base_power_usage
	max_power -= item.template.base_power_usage


func _disable_item_passive_modifiers(item: Item):
	"""Deactivates any passive and non-passive modules modifiers."""
	_toggle_item_passive_effect_modifiers(item, false)
	power += item.template.base_power_usage
	max_power += item.template.base_power_usage


func can_equip_item(item: Item) -> bool:
	"""Checks if the item can be equipped."""
	return slots[item.template.slot] > 0 and max_power > item.template.base_power_usage


func add_item(item: Item) -> bool:
	"""Attempts to equip an item if a slot is available."""
	if can_equip_item(item):
		items.append(item)
		items.sort_custom(Item.compare_items)
		slots[item.template.slot] -= 1
		_enable_item_passive_modifiers(item)
		return true
	return false


func remove_item(item: Item) -> bool:
	"""Removes an equipped item, freeing up the slot."""
	if item in items:
		items.erase(item)
		items.sort_custom(Item.compare_items)
		slots[item.template.slot] += 1
		_disable_item_passive_modifiers(item)
		return true
	return false


func get_item(item_uuid: String) -> Variant:
	"""Retrieves an equipped item by UUID."""
	for entry in items:
		if entry.uuid == item_uuid:
			return entry
	return null


func clear_items() -> void:
	"""
	Safely removes and frees all items currently equipped on this Mek.
	Ensures no memory leaks or dangling references remain.
	"""
	for item in items:
		# Free the UUID if tracked
		GameServer.free_uuid(item.uuid)
	items.clear()


# =============================================================================
# POWER COMPUTATION
# =============================================================================


func evaluate_mek_power() -> float:
	"""
	Computes the total power level of the Mek instance based on:
	- Power contribution of equipped items.
	- Base stats retrieved from the MekTemplate.
	"""
	return MekPowerEvaluatorScript.evaluate(self)


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
	return "[url=mek:" + uuid + "]" + get_mek_name() + "[/url]"


func _to_string() -> String:
	return "Mek<" + mek_id + ", " + uuid + ">"


func from_dict(data: Dictionary = {}) -> bool:
	"""Loads Mek instance data from a dictionary."""
	if not data.has("mek_id") or not data.has("uuid"):
		push_error("Invalid Mek data: Missing required fields")
		return false

	mek_id = data["mek_id"]
	uuid = data["uuid"]
	alias = data.get("alias", "")
	items.clear()
	for item_data in data.get("items", []):
		items.append(Item.new(item_data))
	items.sort_custom(Item.compare_items)

	# Mark the UUID as used.
	GameServer.occupy_uuid(uuid)

	# Load the template.
	template = TemplateManager.get_mek_template(mek_id)
	assert(template, "Cannot find the template: " + mek_id + "\n")

	_update_static_values()

	return true


func to_dict() -> Dictionary:
	"""Converts Mek instance data to a dictionary."""
	return {
		"mek_id": mek_id,
		"uuid": uuid,
		"alias": alias,
		"items": Utils.convert_objects_to_dict(items),
	}


func to_client_dict() -> Dictionary:
	"""Converts Mek instance data to a dictionary."""
	return {
		"mek_id": mek_id,
		"uuid": uuid,
		"alias": alias,
		"items": Utils.convert_objects_to_client_dict(items),
		"health": health,
		"armor": armor,
		"shield": shield,
		"power": power,
		"max_health": max_health,
		"max_armor": max_armor,
		"max_shield": max_shield,
		"max_power": max_power,
		"health_generation": health_generation,
		"armor_generation": armor_generation,
		"shield_generation": shield_generation,
		"power_generation": power_generation,
		"speed": speed,
		"damage_reduction_all": damage_reduction_all,
		"damage_reduction_kinetic": damage_reduction_kinetic,
		"damage_reduction_energy": damage_reduction_energy,
		"damage_reduction_explosive": damage_reduction_explosive,
		"damage_reduction_plasma": damage_reduction_plasma,
		"damage_reduction_corrosive": damage_reduction_corrosive,
		"slots": slots
	}
