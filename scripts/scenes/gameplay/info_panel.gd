extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

const DAMAGE_TYPE_DESCRIPTIONS = {
	Enums.DamageType.KINETIC: "Shield  -, Armor  +, Health  =",
	Enums.DamageType.ENERGY: "Shield ++, Armor  -, Health  =",
	Enums.DamageType.EXPLOSIVE: "Shield  -, Armor ++, Health ++",
	Enums.DamageType.PLASMA: "Shield  +, Armor  +, Health  -",
	Enums.DamageType.CORROSIVE: "Shield --, Armor ++, Health  +"
}

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var entity: MapEntity

# =============================================================================
# COMPONENT REFERENCES
# =============================================================================

@onready var entity_info = $EntityInspector/ScrollContainer/EntityInfo
@onready var item_inspector = $EntityInspector/ItemInspector
@onready var item_list = $EntityInspector/ItemInspector/ItemList
@onready var item_info = $EntityInspector/ItemInspector/ScrollContainer/ItemInfo

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func setup(p_game_map: GameMap) -> void:
	"""
	Connects necessary signals and stores a reference to the game map.
	"""
	clear()
	# Set the variables.
	game_map = p_game_map
	# Connect the signals.
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	if not item_list.item_selected.is_connected(_on_item_selected):
		item_list.item_selected.connect(_on_item_selected)


func clear() -> void:
	"""
	Clears all UI elements and disconnects signals.
	"""
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	entity = null
	game_map = null

	item_list.clear()
	entity_info.clear()
	item_inspector.visible = false


func _on_turn_ended(_turn_number: int):
	# Called when the turn ends.
	update_panel()


# =============================================================================
# SET ENTITY
# =============================================================================


func set_entity(new_entity: MapEntity) -> void:
	"""
	Sets the currently selected entity and updates the panel.
	"""
	entity = new_entity
	update_panel()


# =============================================================================
# UI UPDATE
# =============================================================================


func update_panel() -> void:
	"""
	Refreshes all UI elements to reflect the current entity's state.
	"""
	if not is_instance_valid(entity):
		return

	item_list.clear()
	entity_info.clear()
	item_inspector.visible = false

	if is_instance_of(entity, MapMek):
		_load_mek_details(entity)

		item_inspector.visible = true

		for item in entity.combatant.items:
			var index = item_list.add_item(item.template.item_name)
			item_list.set_item_metadata(index, item)
			item_list.set_item_custom_fg_color(index, _get_slot_color(item.template.slot))


# =============================================================================
# ITEM SELECTION
# =============================================================================


func select_item_by_uuid(uuid: String) -> void:
	"""
	Selects an item in the list by its UUID and shows its details.
	"""
	if not is_instance_valid(entity) or not is_instance_of(entity, MapMek):
		return

	for i in item_list.item_count:
		var item: Item = item_list.get_item_metadata(i)
		if item and item.uuid == uuid:
			item_list.select(i)
			_load_item_details(item)
			break


func _on_item_selected(index: int) -> void:
	"""
	Handles when the user selects an item from the list.
	"""
	if index < 0 or index >= item_list.item_count:
		return

	var item: Item = item_list.get_item_metadata(index)
	if item:
		_load_item_details(item)


# =============================================================================
# PLACEHOLDER METHODS (assumed to exist elsewhere)
# =============================================================================


func _load_mek_details(map_mek: MapMek) -> void:
	if not is_instance_valid(map_mek):
		return
	# Get the mek.
	var mek: Mek = map_mek.combatant
	# Add the name.
	var s = "[center][b]" + mek.get_mek_name() + "[/b][/center]\n"
	# Add who is controlling the mek.
	if is_instance_of(map_mek.owner, PlayerOwned):
		s += "Player  : " + map_mek.owner.player.player_name + "\n"
	elif is_instance_of(map_mek.owner, NPCOwned):
		s += "NPC     : " + map_mek.owner.npc_name + "\n"
	# Add the clan.
	s += "Clan    : " + map_mek.owner.clan.clan_name + "\n"
	s += "Power   : " + str(mek.evaluate_mek_power()) + "\n"
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
	s += (
		"    all       : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_all)
		+"\n"
	)
	s += (
		"    kinetic   : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_kinetic)
		+"\n"
	)
	s += (
		"    energy    : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_energy)
		+"\n"
	)
	s += (
		"    explosive : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_explosive)
		+"\n"
	)
	s += (
		"    plasma    : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_plasma)
		+"\n"
	)
	s += (
		"    corrosive : "
		+ UIColor.apply("damage_reduction", "%3d" % mek.damage_reduction_corrosive)
		+"\n"
	)
	entity_info.clear()
	entity_info.append_text(s)


func _load_item_details(item: Item):
	"""Load details for a selected Item."""
	if not is_instance_valid(item):
		return
	var s: String = ""
	# Header
	s += "[center][b]" + item.template.item_name + "[/b][/center]\n"
	s += "Combat Power : " + str(item.evaluate_item_power()) + "\n"
	s += "Slot         : " + UIColor.apply("slot", Enums.SlotType.keys()[item.template.slot]) + "\n"
	s += "Power Usage  : " + UIColor.apply("power", item.template.base_power_usage) + "\n"
	if item.template.modules.is_empty():
		return
	# Process modules.
	s += "\n[center][b]Modules[/b][/center]\n"
	s += "[indent]"
	for module in item.template.modules:
		var module_line = "|"
		module_line += "[b]" + module.module_name + "[/b] "
		module_line += (
			"(" + UIColor.apply("module_type", "Passive" if module.passive else "Active") + ")"
		)
		s += module_line + "\n"
		# Active module details
		if not module.passive:
			var acrive_line = "|"
			if module.power_on_use > 0:
				acrive_line += (
					"Power on Use: " + UIColor.apply("power_on_use", str(module.power_on_use))
				)
			if module.cooldown > 0:
				acrive_line += " | Cooldown: " + UIColor.apply("cooldown", str(module.cooldown))
			if module.module_range > 0:
				acrive_line += (
					" | Range: " + UIColor.apply("module_range", str(module.module_range))
				)
			s += acrive_line + "\n"
		# Process effects within the module
		for effect in module.effects:
			var effect_line = "|"
			effect_line += (
				"[" + UIColor.apply("effect_type", Enums.EffectType.keys()[effect.type]) + "] -> "
			)
			effect_line += UIColor.apply(
				"effect_target_type", Enums.TargetType.keys()[effect.target]
			)
			effect_line += " | " + UIColor.apply("effect_amount", str(effect.amount))
			# Add damage type details with tooltip hint.
			if (
				effect.type == Enums.EffectType.DAMAGE
				or effect.type == Enums.EffectType.DAMAGE_OVER_TIME
			):
				var damage_type_name = Enums.DamageType.keys()[effect.damage_type]
				var damage_description = DAMAGE_TYPE_DESCRIPTIONS.get(
					effect.damage_type, "No description available."
				)
				# Wrap the damage type in a [hint] BBCode tag to show the description on hover.
				effect_line += (
					" [hint={"
					+ damage_description
					+"}]"
					+ UIColor.apply("effect_damage_type", damage_type_name)
					+"[/hint]"
				)
			# Add duration and chance details
			if effect.duration > 0:
				effect_line += (
					", " + UIColor.apply("effect_duration", str(effect.duration) + " rounds")
				)
			if effect.chance < 100:
				effect_line += ", " + UIColor.apply("effect_chance", str(effect.chance) + "%")
			# Area effects
			if effect.target == Enums.TargetType.AREA:
				effect_line += ", " + UIColor.apply("effect_radius", str(effect.radius))
				effect_line += (
					", "
					+ UIColor.apply(
						"effect_center_on_target",
						"Center on Target" if effect.center_on_target else "Center on Self"
					)
				)

			s += effect_line + "\n"
		s += "\n"
	s += "[/indent]"
	item_info.clear()
	item_info.append_text(s)


# =============================================================================
# SUPPORT
# =============================================================================


func _get_slot_color(slot: Enums.SlotType) -> Color:
	"""Returns a color for each slot type."""
	var slot_colors = {
		Enums.SlotType.SMALL: Color(0.6, 0.6, 1.0), # Light Blue
		Enums.SlotType.MEDIUM: Color(0.3, 0.8, 0.3), # Green
		Enums.SlotType.LARGE: Color(1.0, 0.5, 0.3), # Orange
		Enums.SlotType.UTILITY: Color(1.0, 1.0, 0.4) # Yellow
	}
	return slot_colors.get(slot, Color.WHITE)
