extends RefCounted

class_name UseModuleOrder

# =============================================================================
# PROPERTIES
# =============================================================================

# The unit using the module.
var source: MapEntity
# The entity affected (can be `source`, an ally, or an enemy).
var target: MapEntity
# The item containing the module.
var item: Item
# The specific module being activated.
var module: ItemModule

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================

func _init(p_source: MapEntity, p_target: MapEntity, p_item: Item, p_module: ItemModule) -> void:
	source = p_source
	target = p_target
	item   = p_item
	module = p_module

func _to_string() -> String:
	if not module or module.effects.is_empty():
		return "UseModuleOrder<source: %s, item: %s, module: %s, target: %s>" % [
			str(source.entity), str(item), str(module), str(target.entity)
		]

	# Check for offensive effects
	var has_damage = false
	var has_healing = false
	var has_modifier = false

	for effect in module.effects:
		match effect.type:
			Enums.EffectType.DAMAGE, Enums.EffectType.DAMAGE_OVER_TIME:
				has_damage = true
			Enums.EffectType.HEALTH_REPAIR, Enums.EffectType.SHIELD_REPAIR, Enums.EffectType.ARMOR_REPAIR:
				has_healing = true
			_:
				has_modifier = true  # Any other effect is a buff/debuff

	# Determine the action type
	var action_desc = "using"
	if has_damage:
		action_desc = "attacking with"
	elif has_healing:
		action_desc = "supporting with"
	elif has_modifier:
		action_desc = "buffing with"

	# Determine the target type
	if source == target:
		return "%s is using %s on itself" % [str(source.entity.template.name), str(module.name)]
	else:
		return "%s is %s %s on %s" % [
			str(source.entity.template.name), action_desc, str(module.name), str(target.entity.template.name)
		]
