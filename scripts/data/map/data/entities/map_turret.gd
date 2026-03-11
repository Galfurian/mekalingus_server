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
# Cooldown remaining (in turns)
var cooldown_remaining: int

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
		"cooldown_remaining": cooldown_remaining,
		"active": active
	}
