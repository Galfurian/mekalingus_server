class_name MapCombatEntity
extends MapEntity

# Runtime combat actor (Mek, Structure, etc.) represented on this map tile.
var combatant: CombatActor


func _init(
	p_position: Vector2i,
	p_owner: EntityOwner,
	p_combatant: CombatActor,
	p_blocking: bool = true
) -> void:
	super(p_position, p_owner, p_blocking)
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
