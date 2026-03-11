class_name MapCombatEntity
extends MapEntity

var combatant


func _init(p_position: Vector2i, p_owner: EntityOwner, p_combatant) -> void:
	position = p_position
	owner = p_owner
	combatant = p_combatant
	active = true


func is_alive() -> bool:
	return combatant and combatant.is_alive() and active


func is_dead() -> bool:
	return not is_alive()
