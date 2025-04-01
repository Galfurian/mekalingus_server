class_name MoveOrder
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# The unit that is moving.
var source: MapMek
# The target position.
var destination: Vector2i

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_source: MapEntity, p_destination: Vector2i) -> void:
	source = p_source
	destination = p_destination


func _to_string() -> String:
	var s = ""
	if is_instance_of(source.mek, Mek):
		s += source.mek.template.mek_name
	else:
		s += str(source.mek)
	s += " is moving"
	s += " from (" + str(source.position.x) + ", " + str(source.position.y) + ")"
	s += " to (" + str(destination.x) + ", " + str(destination.y) + ")"
	return s
