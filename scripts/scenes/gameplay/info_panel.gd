extends Node

@onready var entity_info = $EntityInspector/ScrollContainer/EntityInfo

@onready var item_inspector = $EntityInspector/ItemInspector
@onready var item_list = $EntityInspector/ItemInspector/ItemList
@onready var item_info = $EntityInspector/ItemInspector/ScrollContainer/ItemInfo

var game_map: GameMap
var entity: MapEntity

func setup(p_game_map: GameMap):
	game_map    = p_game_map
	if not game_map.on_round_end.is_connected(update_panel):
		game_map.on_round_end.connect(update_panel)

func clear() -> void:
	game_map.on_round_end.disconnect(update_panel)
	entity = null
	game_map = null
	item_list.clear()
	entity_info.clear()
	item_inspector.visible = false

func set_entity(new_entity: MapEntity):
	entity = new_entity
	update_panel()

func update_panel() -> void:
	if not entity:
		return
		
	item_list.clear()
	entity_info.clear()
	item_inspector.visible = false
	
	if is_instance_of(entity.entity, Mek):
		_print_mek_info(entity.entity)
		# Set the item inspector to visible.
		item_inspector.visible = true
		# Populate the list of items.
		for item in entity.entity.items:
			var index = item_list.add_item(item.template.name)
			# Save the UUID.
			item_list.set_item_metadata(index, item.uuid)
			# Set color based on slot type.
			item_list.set_item_custom_fg_color(index, _get_slot_color(item.template.slot))

func _print_mek_info(mek: Mek) -> void:
	var s = "[center][b]" + mek.template.name + "[/b][/center]\n"
	
	s += "Size    : " + Utils.enum_to_string(Enums.MekSize, mek.template.size) + "\n"
	
	s += "Health  : " + UIColor.apply("health", "%3d" % mek.health) + " / "
	s += UIColor.apply("health", "%3d" % mek.max_health)
	if mek.health_generation > 0:
		s += " [" + UIColor.apply("health", "%3d" % mek.health_generation) + "]"
	s += "\n"
	
	s += "Armor   : " + UIColor.apply("armor", "%3d" % mek.armor) + " / "
	s += UIColor.apply("armor", "%3d" % mek.max_armor)
	if mek.armor_generation > 0:
		s += " [" + UIColor.apply("armor_generation", "%3d" % mek.armor_generation) + "]"
	s += "\n"
	
	s += "Shield  : " + UIColor.apply("shield", "%3d" % mek.shield) + " / "
	s += UIColor.apply("shield", "%3d" % mek.max_shield)
	if mek.shield_generation > 0:
		s += " [" + UIColor.apply("shield_generation", "%3d" % mek.shield_generation) + "]"
	s += "\n"
	
	s += "Power   : " + UIColor.apply("power", "%3d" % mek.power) + " / "
	s += UIColor.apply("power", "%3d" % mek.max_power)
	if mek.power_generation > 0:
		s += " [" + UIColor.apply("power_generation", "%3d" % mek.power_generation) + "]"
	s += "\n"
	
	s += "Speed   : " + UIColor.apply("speed", "%3d" % mek.speed) + "\n"
	s += "Damage reductions :\n"
	s += "    all       : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_all) + "\n"
	s += "    kinetic   : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_kinetic) + "\n"
	s += "    energy    : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_energy) + "\n"
	s += "    explosive : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_explosive) + "\n"
	s += "    plasma    : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_plasma) + "\n"
	s += "    corrosive : " + UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_corrosive) + "\n"
	
	entity_info.clear()
	entity_info.append_text(s)

func _load_item_details(item: Item):
	"""Load details for a selected Item."""
	
	var s: String = ""
	# Header
	s += "[center][b]" + item.template.name + "[/b][/center]\n"
	s += "Slot         : " + UIColor.apply("slot", Enums.SlotType.keys()[item.template.slot]) + "\n"
	s += "Power Usage  : " + UIColor.apply("power", item.template.base_power_usage) + "\n"

	if item.template.modules.is_empty():
		return
	
	# Process modules.
	s += "\n[center][b]Modules[/b][/center]\n"
	s += "[indent]"
	
	for module in item.template.modules:
		var module_line = "|"
		module_line += "[b]" + module.name + "[/b] "
		module_line += "(" + UIColor.apply("module_type", "Passive" if module.passive else "Active") + ")"
		s += module_line + "\n"
		
		# Active module details
		if not module.passive:
			var acrive_line = "|"
			if module.power_on_use > 0:
				acrive_line += "Power on Use: " + UIColor.apply("power_on_use", str(module.power_on_use))
			if module.cooldown > 0:
				acrive_line += " | Cooldown: " + UIColor.apply("cooldown", str(module.cooldown))
			if module.module_range > 0:
				acrive_line += " | Range: " + UIColor.apply("module_range", str(module.module_range))
			s += acrive_line + "\n"

		# Process effects within the module
		for effect in module.effects:
			var effect_line = "|"
			effect_line += "[" + UIColor.apply("effect_type", Enums.EffectType.keys()[effect.type]) + "] → "
			effect_line += UIColor.apply("effect_target_type", Enums.TargetType.keys()[effect.target])
			effect_line += " | " + UIColor.apply("effect_amount", str(effect.amount))

			# Add damage type details with tooltip hint.
			if effect.type == Enums.EffectType.DAMAGE or effect.type == Enums.EffectType.DAMAGE_OVER_TIME:
				var damage_type_name = Enums.DamageType.keys()[effect.damage_type]
				var damage_description = DAMAGE_TYPE_DESCRIPTIONS.get(effect.damage_type, "No description available.")
				# Wrap the damage type in a [hint] BBCode tag to show the description on hover.
				effect_line += " [hint={" + damage_description + "}]" + UIColor.apply("effect_damage_type", damage_type_name) + "[/hint]"
			
			# Add duration and chance details
			if effect.duration > 0:
				effect_line += ", " + UIColor.apply("effect_duration", str(effect.duration) + " rounds")
			if effect.chance < 100:
				effect_line += ", " + UIColor.apply("effect_chance", str(effect.chance) + "%")
			
			# Area effects
			if effect.target == Enums.TargetType.AREA:
				effect_line += ", " + UIColor.apply("effect_radius", str(effect.radius))
				effect_line += ", " + UIColor.apply("effect_center_on_target", "Center on Target" if effect.center_on_target else "Center on Self")

			s += effect_line + "\n"
		s += "\n"
	s += "[/indent]"
	entity_info.clear()
	entity_info.append_text(s)

# =============================================================================
# SUPPORT
# =============================================================================

func _get_mek_size_color(size: Enums.MekSize) -> Color:
	"""Returns the color associated with a Mek's size category."""
	var size_colors = {
		Enums.MekSize.LIGHT: Color("4A90E2"),   # Light Blue
		Enums.MekSize.MEDIUM: Color("50C878"),  # Green
		Enums.MekSize.HEAVY: Color("E67E22"),   # Orange
		Enums.MekSize.COLOSSAL: Color("B22222") # Dark Red
	}
	return size_colors.get(size, Color.WHITE)

func _get_slot_color(slot: Enums.SlotType) -> Color:
	"""Returns a color for each slot type."""
	var slot_colors = {
		Enums.SlotType.SMALL: Color(0.6, 0.6, 1.0),   # Light Blue
		Enums.SlotType.MEDIUM: Color(0.3, 0.8, 0.3),  # Green
		Enums.SlotType.LARGE: Color(1.0, 0.5, 0.3),   # Orange
		Enums.SlotType.UTILITY: Color(1.0, 1.0, 0.4)  # Yellow
	}
	return slot_colors.get(slot, Color.WHITE)

const DAMAGE_TYPE_DESCRIPTIONS = {
	Enums.DamageType.KINETIC  : "Shield  -, Armor  +, Health  =",
	Enums.DamageType.ENERGY   : "Shield ++, Armor  -, Health  =",
	Enums.DamageType.EXPLOSIVE: "Shield  -, Armor ++, Health ++",
	Enums.DamageType.PLASMA   : "Shield  +, Armor  +, Health  -",
	Enums.DamageType.CORROSIVE: "Shield --, Armor ++, Health  +"
}
