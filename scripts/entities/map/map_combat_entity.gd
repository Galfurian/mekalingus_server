class_name MapCombatEntity
extends MapEntity

# Runtime combat actor (Mek, Structure, etc.) represented on this map tile.
var combatant: CombatEntity


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_passable: bool,
	p_active: bool,
	p_combatant: CombatEntity,
) -> void:
	super(p_position, p_owner, p_passable, p_active)
	combatant = p_combatant


func is_alive() -> bool:
	return combatant and combatant.is_alive() and active


func is_dead() -> bool:
	return not is_alive()


func can_move() -> bool:
	return false


func get_icon_path() -> String:
	if not combatant:
		return ""
	return combatant.get_icon_path()


# =============================================================================
# SERIALIZATION
# =============================================================================


static func from_dict(_data: Dictionary) -> MapEntity:
	"""
	Loads item data from a dictionary.
	"""
	return null


func to_dict() -> Dictionary:
	"""Converts item data to a dictionary."""
	var data: Dictionary = super.to_dict()
	data["actor"] = combatant.to_dict()
	return data
