# This class represents an order given to a unit in the game.
class_name Order
extends RefCounted

# =============================================================================
# INTERFACE FUNCTIONS
# =============================================================================


func execute(_game_map) -> bool:
	push_error("execute() not implemented in subclass: %s" % self)
	return false


func validate() -> bool:
	push_warning("validate() not implemented in subclass: %s" % self)
	return false


func _to_string() -> String:
	return "<Order base class>"
