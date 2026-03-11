# Represents a turret on the map. Turrets are stationary defensive structures
# that can automatically attack hostile units within range.

class_name MapTurret
extends MapStructure

# =============================================================================
# PROPERTIES
# =============================================================================

var turret_name: String
# Attack range in tiles
var fire_range: int
# Base damage per attack
var damage: int
# Optional data-driven weapon configuration.
var weapon_item_id: String = ""
var weapon_module_name: String = ""
var weapon_effect_index: int = 0
# Cooldown remaining (in turns)
var cooldown_remaining: int

var _cached_fire_effect: ItemEffect

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_turret_name: String,
	p_max_health: int,
	p_armor: int,
	p_fire_range: int,
	p_damage: int
) -> void:
	super(p_position, p_owner, p_turret_name, p_max_health, p_armor, true)
	turret_name = p_turret_name
	fire_range = p_fire_range
	damage = p_damage
	cooldown_remaining = 0


func can_fire() -> bool:
	"""Check if turret is ready to fire (cooldown expired)."""
	return cooldown_remaining <= 0


func start_cooldown(cooldown_turns: int) -> void:
	"""Begin cooldown for the given number of turns."""
	cooldown_remaining = cooldown_turns


func tick_cooldown() -> void:
	"""Decrement cooldown by one turn."""
	if cooldown_remaining > 0:
		cooldown_remaining -= 1


func configure_weapon(
	p_item_id: String,
	p_module_name: String,
	p_effect_index: int = 0
) -> bool:
	"""
	Configures turret weapon from item template module effect data.
	"""
	weapon_item_id = p_item_id
	weapon_module_name = p_module_name
	weapon_effect_index = p_effect_index
	_cached_fire_effect = _resolve_effect_from_template()
	return _cached_fire_effect != null


func get_fire_effect() -> ItemEffect:
	"""
	Returns the cached turret fire effect. Uses configured template data when present,
	or falls back to the legacy direct-damage effect.
	"""
	if _cached_fire_effect:
		return _cached_fire_effect

	if weapon_item_id != "" and weapon_module_name != "":
		_cached_fire_effect = _resolve_effect_from_template()
		if _cached_fire_effect:
			return _cached_fire_effect

	_cached_fire_effect = ItemEffect.new({
		"type": Enums.EffectType.DAMAGE,
		"target": Enums.TargetType.ENEMY,
		"damage_type": Enums.DamageType.KINETIC,
		"amount": damage,
		"duration": 0,
		"chance": 100,
		"radius": 0,
		"center_on_target": true,
	})
	return _cached_fire_effect


func _resolve_effect_from_template() -> ItemEffect:
	"""
	Loads a fire effect from configured item/module/effect indices.
	"""
	if weapon_item_id == "" or weapon_module_name == "":
		return null

	var template: ItemTemplate = TemplateManager.get_item_template(weapon_item_id)
	if not template:
		push_warning("MapTurret: unknown weapon_item_id '%s'" % weapon_item_id)
		return null

	for module: ItemModule in template.modules:
		if module.module_name != weapon_module_name:
			continue
		if weapon_effect_index < 0 or weapon_effect_index >= module.effects.size():
			push_warning("MapTurret: invalid weapon_effect_index %d for module '%s'" % [
				weapon_effect_index,
				weapon_module_name,
			])
			return null
		return module.effects[weapon_effect_index]

	push_warning("MapTurret: module '%s' not found in item '%s'" % [
		weapon_module_name,
		weapon_item_id,
	])
	return null


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(data: Dictionary) -> MapTurret:
	"""
	Loads turret data from a dictionary.
	"""
	if (
		not data.has("position")
		or not data.has("owner")
		or not data.has("turret_name")
		or not data.has("max_health")
		or not data.has("current_health")
		or not data.has("armor")
		or not data.has("fire_range")
		or not data.has("damage")
		or not data.has("cooldown_remaining")
		or not data.has("active")
	):
		push_error("Invalid MapTurret data: Missing required fields")
		return null

	var parsed_owner: EntityOwner = EntityOwner.from_dict(data["owner"])
	if not parsed_owner:
		push_error("Invalid MapTurret data: failed to deserialize owner")
		return null

	var loaded_turret := MapTurret.new(
		Utils.deserialize_position(data["position"]),
		parsed_owner,
		data["turret_name"],
		data["max_health"],
		data["armor"],
		data["fire_range"],
		data["damage"]
	)
	loaded_turret.current_health = data["current_health"]
	loaded_turret.cooldown_remaining = data["cooldown_remaining"]
	loaded_turret.active = bool(data["active"])
	loaded_turret.blocking = bool(data.get("blocking", true))
	loaded_turret.weapon_item_id = str(data.get("weapon_item_id", ""))
	loaded_turret.weapon_module_name = str(data.get("weapon_module_name", ""))
	loaded_turret.weapon_effect_index = int(data.get("weapon_effect_index", 0))
	loaded_turret._cached_fire_effect = loaded_turret._resolve_effect_from_template()
	return loaded_turret


func to_dict() -> Dictionary:
	"""Converts turret data to a dictionary."""
	return {
		"position": Utils.serialize_position(position),
		"owner": owner.to_dict(),
		"turret_name": turret_name,
		"max_health": max_health,
		"current_health": current_health,
		"armor": armor,
		"blocking": blocking,
		"fire_range": fire_range,
		"damage": damage,
		"weapon_item_id": weapon_item_id,
		"weapon_module_name": weapon_module_name,
		"weapon_effect_index": weapon_effect_index,
		"cooldown_remaining": cooldown_remaining,
		"active": active
	}
