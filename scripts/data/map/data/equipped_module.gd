# This class keeps track of a module that is equipped to a Mek.
class_name EquippedModule extends RefCounted

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

# The Mek that has the module equipped.
var mek: Mek
# The item that is equipped.
var item: Item
# The module of that item.
var module: ItemModule

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_mek: Mek, p_item: Item, p_module: ItemModule) -> void:
	"""
	Initializes the EquippedModule.
	"""
	mek = p_mek
	item = p_item
	module = p_module


func validate() -> bool:
	"""
	Checks if the EquippedModule is valid.
	"""
	return is_instance_valid(mek) and is_instance_valid(item) and is_instance_valid(module)


func get_chat_tag() -> String:
	"""
	Returns a chat tag for the EquippedModule.
	"""
	if validate():
		return "[url=item:%s:%s]%s[/url]" % [mek.uuid, item.uuid, module.module_name]
	return ""


func _to_string() -> String:
	"""
	Returns a string representation of the EquippedModule.
	"""
	return "%s: %s (%s)" % [mek.alias, item.name, module.module_name]
