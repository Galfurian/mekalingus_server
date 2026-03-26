# This class keeps track of a module that is equipped to a Mek.
class_name EquippedModule extends RefCounted

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

# The combat actor that has the module equipped.
var mek: CombatEntity
# The item that is equipped.
var item: Item
# The module of that item.
var module: ItemModule

# =============================================================================
# PROPERTIES
# =============================================================================

var module_name: String:
	get:
		assert(is_instance_valid(module))
		return module.module_name

var passive: bool:
	get:
		assert(is_instance_valid(module))
		return module.passive

var power_on_use: int:
	get:
		assert(is_instance_valid(module))
		return module.power_on_use

var cooldown: int:
	get:
		assert(is_instance_valid(mek) and is_instance_valid(module))
		if module.cooldown > 0:
			return max(1, module.cooldown + mek.cooldown_modifier)
		return 0

var module_range: int:
	get:
		assert(is_instance_valid(mek) and is_instance_valid(module))
		return max(0, module.module_range + mek.range_modifier)

var repeats: int:
	get:
		assert(is_instance_valid(module))
		return module.repeats

var effects: Array[BaseEffect]:
	get:
		assert(is_instance_valid(module))
		return module.effects

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_mek: CombatEntity, p_item: Item, p_module: ItemModule) -> void:
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
		return MetaTag.item_tag(item.uuid, module.module_name, mek.uuid)
	return ""


func _to_string() -> String:
	"""
	Returns a string representation of the EquippedModule.
	"""
	var actor_name: String = "Unknown"
	if validate():
		if mek.has_method("get_mek_name"):
			actor_name = str(mek.call("get_mek_name"))
		elif not mek.alias.is_empty():
			actor_name = mek.alias
		else:
			actor_name = mek.name
	return "%s: %s (%s)" % [actor_name, item.name, module.module_name]
