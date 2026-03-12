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
const SLOT_ORDER: Array[int] = [
	Enums.SlotType.SMALL,
	Enums.SlotType.MEDIUM,
	Enums.SlotType.LARGE,
	Enums.SlotType.UTILITY,
]

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var entity: MapEntity
var _slot_editor_rows: Dictionary = {}
var _is_rebuilding_editors: bool = false
var _last_selected_tab: int = 0

# =============================================================================
# COMPONENT REFERENCES
# =============================================================================

@onready var entity_info = $EntityInspector/ScrollContainer/EntityInfo
@onready var item_inspector = $EntityInspector/ItemInspector
@onready var tabs = $EntityInspector/ItemInspector/Tabs
@onready var slot_editor_container = $EntityInspector/ItemInspector/Tabs/Equipment/SlotEditorScroll/SlotEditorContainer
@onready var plan_info = $EntityInspector/ItemInspector/Tabs/Plan/ScrollContainer/PlanInfo
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
	if not plan_info.meta_clicked.is_connected(_on_plan_meta_clicked):
		plan_info.meta_clicked.connect(_on_plan_meta_clicked)
	# Connect the tabs signal.
	if not tabs.tab_changed.is_connected(_on_tab_changed):
		tabs.tab_changed.connect(_on_tab_changed)

func clear() -> void:
	"""
	Clears all UI elements and disconnects signals.
	"""
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	entity = null
	game_map = null

	_clear_slot_editor_container()
	_slot_editor_rows.clear()
	entity_info.clear()
	plan_info.clear()
	item_info.clear()
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

	_clear_slot_editor_container()
	_slot_editor_rows.clear()
	entity_info.clear()
	plan_info.clear()
	item_info.clear()
	item_inspector.visible = false

	if is_instance_of(entity, MapCombatEntity):
		var map_combat_entity: MapCombatEntity = entity
		_load_combat_entity_details(map_combat_entity)
		item_inspector.visible = true
		tabs.current_tab = _last_selected_tab
		_rebuild_slot_editors(map_combat_entity.combatant)
		_update_plan_tab(map_combat_entity)

func _on_tab_changed(tab_index: int) -> void:
	_last_selected_tab = tab_index

# =============================================================================
# ITEM SELECTION
# =============================================================================


func select_item_by_uuid(uuid: String) -> void:
	"""
	Selects an item in the list by its UUID and shows its details.
	"""
	if not is_instance_valid(entity) or not is_instance_of(entity, MapCombatEntity):
		return

	var map_combat_entity: MapCombatEntity = entity
	for item: Item in map_combat_entity.combatant.items:
		if item and item.uuid == uuid:
			_load_item_details(item)
			return


func _rebuild_slot_editors(actor: CombatActor) -> void:
	_is_rebuilding_editors = true
	_clear_slot_editor_container()
	_slot_editor_rows.clear()

	var templates_by_slot: Dictionary = _build_templates_by_slot()
	var equipped_by_slot: Dictionary = _build_equipped_items_by_slot(actor)
	var capacities: Dictionary = _build_slot_capacities(actor, equipped_by_slot)

	for slot_type: int in SLOT_ORDER:
		var capacity: int = int(capacities.get(slot_type, 0))
		if capacity <= 0:
			continue

		_create_slot_header(slot_type)
		var rows: Array[Dictionary] = []
		var equipped: Array[Item] = _as_item_array(equipped_by_slot.get(slot_type, []))
		var templates: Array[ItemTemplate] = _as_item_template_array(
			templates_by_slot.get(slot_type, [])
		)
		for row_index in range(capacity):
			var existing_item: Item = null
			if row_index < equipped.size():
				existing_item = equipped[row_index]

			var row_data: Dictionary = _create_slot_editor_row(
				slot_type,
				row_index,
				existing_item,
				templates
			)
			rows.append(row_data)
		_slot_editor_rows[slot_type] = rows

	if slot_editor_container.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "No equip slots available for this unit."
		slot_editor_container.add_child(empty_label)

	_is_rebuilding_editors = false


func _clear_slot_editor_container() -> void:
	for child in slot_editor_container.get_children():
		child.queue_free()


func _create_slot_header(slot_type: int) -> void:
	var header := Label.new()
	header.text = Utils.enum_to_string(Enums.SlotType, slot_type)
	slot_editor_container.add_child(header)


func _create_slot_editor_row(
	slot_type: int,
	row_index: int,
	current_item: Item,
	templates: Array[ItemTemplate]
) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	slot_editor_container.add_child(row)

	var selected_template_id: String = ""
	if current_item and current_item.template:
		selected_template_id = current_item.template.id

	var item_name_button := Button.new()
	item_name_button.flat = true
	item_name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name_button.text = "None"
	item_name_button.add_theme_color_override("font_color", _get_slot_color(slot_type))
	if current_item and current_item.template:
		item_name_button.text = current_item.template.item_name
	item_name_button.pressed.connect(func():
		_on_slot_item_name_pressed(slot_type, row_index)
	)
	row.add_child(item_name_button)

	var change_button := MenuButton.new()
	change_button.text = "Change"
	change_button.custom_minimum_size = Vector2(90, 0)
	var popup: PopupMenu = change_button.get_popup()
	popup.clear()
	popup.add_item("None", 0)
	popup.set_item_metadata(0, "")
	for template: ItemTemplate in templates:
		popup.add_item(template.item_name)
		popup.set_item_metadata(popup.item_count - 1, template.id)
	popup.id_pressed.connect(func(item_id: int):
		_on_slot_change_selected(slot_type, row_index, item_id)
	)
	row.add_child(change_button)

	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.custom_minimum_size = Vector2(24, 0)
	remove_button.pressed.connect(func():
		_on_slot_remove_pressed(slot_type, row_index)
	)
	row.add_child(remove_button)

	return {
		"name_button": item_name_button,
		"change_button": change_button,
		"remove": remove_button,
		"templates": templates,
		"selected_template_id": selected_template_id,
		"item": current_item,
	}


func _build_templates_by_slot() -> Dictionary:
	var templates_by_slot: Dictionary = {}
	for slot_type: int in SLOT_ORDER:
		templates_by_slot[slot_type] = []

	for template: ItemTemplate in TemplateManager.item_templates.values():
		if not templates_by_slot.has(template.slot):
			continue
		templates_by_slot[template.slot].append(template)

	for slot_type: int in SLOT_ORDER:
		var templates: Array[ItemTemplate] = _as_item_template_array(
			templates_by_slot.get(slot_type, [])
		)
		templates.sort_custom(func(a: ItemTemplate, b: ItemTemplate):
			return a.item_name.to_lower() < b.item_name.to_lower()
		)
		templates_by_slot[slot_type] = templates

	return templates_by_slot


func _build_equipped_items_by_slot(actor: CombatActor) -> Dictionary:
	var equipped_by_slot: Dictionary = {}
	for slot_type: int in SLOT_ORDER:
		equipped_by_slot[slot_type] = []

	for item: Item in actor.items:
		if item and item.template and equipped_by_slot.has(item.template.slot):
			equipped_by_slot[item.template.slot].append(item)

	for slot_type: int in SLOT_ORDER:
		var equipped: Array[Item] = _as_item_array(equipped_by_slot.get(slot_type, []))
		equipped.sort_custom(Item.compare_items)
		equipped_by_slot[slot_type] = equipped

	return equipped_by_slot


func _build_slot_capacities(actor: CombatActor, equipped_by_slot: Dictionary) -> Dictionary:
	var capacities: Dictionary = {}
	for slot_type: int in SLOT_ORDER:
		var equipped_count: int = _as_item_array(equipped_by_slot.get(slot_type, [])).size()
		var free_slots: int = 0
		if slot_type < actor.slots.size():
			free_slots = max(0, int(actor.slots[slot_type]))
		capacities[slot_type] = equipped_count + free_slots
	return capacities


func _as_item_template_array(raw_array: Array) -> Array[ItemTemplate]:
	var typed: Array[ItemTemplate] = []
	for entry in raw_array:
		if entry is ItemTemplate:
			typed.append(entry)
	return typed


func _as_item_array(raw_array: Array) -> Array[Item]:
	var typed: Array[Item] = []
	for entry in raw_array:
		if entry is Item:
			typed.append(entry)
	return typed


func _on_slot_item_name_pressed(slot_type: int, row_index: int) -> void:
	if not _slot_editor_rows.has(slot_type):
		return

	var rows: Array[Dictionary] = _slot_editor_rows[slot_type]
	if row_index < 0 or row_index >= rows.size():
		return

	var row_data: Dictionary = rows[row_index]
	var current_item: Item = row_data.get("item", null)
	if current_item:
		_load_item_details(current_item)
	else:
		item_info.clear()


func _on_slot_change_selected(slot_type: int, row_index: int, menu_id: int) -> void:
	if _is_rebuilding_editors:
		return
	if not _slot_editor_rows.has(slot_type):
		return

	var rows: Array[Dictionary] = _slot_editor_rows[slot_type]
	if row_index < 0 or row_index >= rows.size():
		return

	var row_data: Dictionary = rows[row_index]
	var change_button: MenuButton = row_data.get("change_button", null)
	if not change_button:
		return

	var popup: PopupMenu = change_button.get_popup()
	if menu_id < 0 or menu_id >= popup.item_count:
		return

	row_data["selected_template_id"] = str(popup.get_item_metadata(menu_id))
	_apply_loadout_from_slot_editors(slot_type, row_index)


func _on_slot_remove_pressed(slot_type: int, row_index: int) -> void:
	if _is_rebuilding_editors:
		return
	if not _slot_editor_rows.has(slot_type):
		return

	var rows: Array[Dictionary] = _slot_editor_rows[slot_type]
	if row_index < 0 or row_index >= rows.size():
		return

	rows[row_index]["selected_template_id"] = ""
	_apply_loadout_from_slot_editors(slot_type, row_index)


func _apply_loadout_from_slot_editors(focus_slot: int, focus_row: int) -> void:
	if not is_instance_valid(entity) or not is_instance_of(entity, MapCombatEntity):
		return

	var actor: CombatActor = (entity as MapCombatEntity).combatant
	var new_items: Array[Item] = []
	var selected_template_id: String = ""

	for slot_type: int in SLOT_ORDER:
		if not _slot_editor_rows.has(slot_type):
			continue
		var rows: Array[Dictionary] = _slot_editor_rows[slot_type]
		for row_index in range(rows.size()):
			var template_id: String = str(rows[row_index].get("selected_template_id", ""))
			if slot_type == focus_slot and row_index == focus_row:
				selected_template_id = template_id
			if template_id.is_empty():
				continue
			var template: ItemTemplate = TemplateManager.item_templates.get(template_id, null)
			if template:
				new_items.append(template.build_item())

	actor.items = new_items
	actor.items.sort_custom(Item.compare_items)
	actor.rebuild_combat_state()

	update_panel()

	if selected_template_id.is_empty():
		item_info.clear()
		return

	for item: Item in actor.items:
		if item and item.template and item.template.id == selected_template_id:
			_load_item_details(item)
			return

	item_info.clear()


func _update_plan_tab(map_entity: MapCombatEntity) -> void:
	if not game_map or not map_entity:
		plan_info.clear()
		return

	var plan: AIPlan = game_map.ai_controller.get_current_plan(map_entity)
	if not plan:
		plan_info.clear()
		plan_info.append_text("[center][b]Plan[/b][/center]\nNo current plan.")
		return

	var s: String = "[center][b]Plan[/b][/center]\n"
	s += "Intent    : %s\n" % AIPlan.Intent.keys()[plan.intent]
	s += "Completed : %s\n" % str(plan.completed)
	s += "Score     : %.2f\n" % plan.score

	if plan.source and plan.source.combatant:
		s += "Source    : [url=entity:%s]%s[/url]\n" % [
			plan.source.combatant.uuid,
			plan.source.combatant.get_chat_tag(),
		]

	if plan.target and plan.target.combatant:
		s += "Target    : [url=entity:%s]%s[/url]\n" % [
			plan.target.combatant.uuid,
			plan.target.combatant.get_chat_tag(),
		]

	if plan.equipped_module and plan.equipped_module.validate():
		var module_item: Item = plan.equipped_module.item
		var module_name: String = plan.equipped_module.module.module_name
		s += "Module    : [url=item:%s]%s[/url] -> %s\n" % [
			module_item.uuid,
			module_item.template.item_name,
			module_name,
		]

	if plan.destination != Vector2i.ZERO:
		s += "Move To   : %s\n" % GameMap.format_pos_tag(plan.destination)

	if map_entity.position:
		s += "Now At    : %s\n" % GameMap.format_pos_tag(map_entity.position)

	if plan.target:
		var distance: float = map_entity.position.distance_to(plan.target.position)
		s += "Air Dist  : %.1f\n" % distance

	plan_info.clear()
	plan_info.append_text(s)


func _on_plan_meta_clicked(meta: Variant) -> void:
	if not game_map:
		return

	var meta_text: String = str(meta)
	if meta_text.begins_with("item:"):
		var item_uuid: String = meta_text.substr(5)
		if not is_instance_valid(entity) or not is_instance_of(entity, MapCombatEntity):
			return
		for item: Item in (entity as MapCombatEntity).combatant.items:
			if item and item.uuid == item_uuid:
				_load_item_details(item)
				return
		return

	if meta_text.begins_with("entity:"):
		var entity_uuid: String = meta_text.substr(7)
		var target_entity: MapEntity = game_map.get_entity(entity_uuid)
		if target_entity:
			set_entity(target_entity)
		return

	if meta_text.begins_with("pos:"):
		var coord_text: String = meta_text.substr(4)
		var coords: PackedStringArray = coord_text.split(",")
		if coords.size() != 2:
			return
		var x: int = int(coords[0])
		var y: int = int(coords[1])
		if not is_instance_valid(entity) or not is_instance_of(entity, MapEntity):
			return
		# We cannot pan from this panel alone, so selecting nearest entity is most useful fallback.
		var at_pos: MapEntity = game_map.get_entity_at(Vector2i(x, y))
		if at_pos:
			set_entity(at_pos)


func _get_slot_color(slot: Enums.SlotType) -> Color:
	var slot_colors = {
		Enums.SlotType.SMALL: Color(0.6, 0.6, 1.0),
		Enums.SlotType.MEDIUM: Color(0.3, 0.8, 0.3),
		Enums.SlotType.LARGE: Color(1.0, 0.5, 0.3),
		Enums.SlotType.UTILITY: Color(1.0, 1.0, 0.4),
	}
	return slot_colors.get(slot, Color.WHITE)


# =============================================================================
# PLACEHOLDER METHODS (assumed to exist elsewhere)
# =============================================================================


func _load_combat_entity_details(map_entity: MapCombatEntity) -> void:
	if not is_instance_valid(map_entity):
		return
	# Get the combat actor.
	var actor: CombatActor = map_entity.combatant
	# Add the name.
	var s = "[center][b]" + _combatant_name(actor) + "[/b][/center]\n"
	# Add who is controlling the entity.
	if is_instance_of(map_entity.owner, PlayerOwned):
		s += "Player  : " + map_entity.owner.player.player_name + "\n"
	elif is_instance_of(map_entity.owner, NPCOwned):
		s += "NPC     : " + map_entity.owner.npc_name + "\n"
	# Add the clan.
	s += "Clan    : " + map_entity.owner.clan.clan_name + "\n"
	if is_instance_of(actor, Mek):
		s += "Power   : " + str((actor as Mek).evaluate_mek_power()) + "\n"
		s += "Size    : " + Utils.enum_to_string(Enums.MekSize, (actor as Mek).template.size) + "\n"
	else:
		s += "Power   : " + str(actor.evaluate_combat_power()) + "\n"
	s += "Health  : " + UIColor.apply("health", "%3d" % actor.health) + " / "
	s += UIColor.apply("health", "%3d" % actor.max_health)
	if actor.health_generation > 0:
		s += " [" + UIColor.apply("health", "%3d" % actor.health_generation) + "]"
	s += "\n"
	s += "Armor   : " + UIColor.apply("armor", "%3d" % actor.armor) + " / "
	s += UIColor.apply("armor", "%3d" % actor.max_armor)
	if actor.armor_generation > 0:
		s += " [" + UIColor.apply("armor_generation", "%3d" % actor.armor_generation) + "]"
	s += "\n"
	s += "Shield  : " + UIColor.apply("shield", "%3d" % actor.shield) + " / "
	s += UIColor.apply("shield", "%3d" % actor.max_shield)
	if actor.shield_generation > 0:
		s += " [" + UIColor.apply("shield_generation", "%3d" % actor.shield_generation) + "]"
	s += "\n"
	s += "Power   : " + UIColor.apply("power", "%3d" % actor.power) + " / "
	s += UIColor.apply("power", "%3d" % actor.max_power)
	if actor.power_generation > 0:
		s += " [" + UIColor.apply("power_generation", "%3d" % actor.power_generation) + "]"
	s += "\n"
	s += "Speed   : " + UIColor.apply("speed", "%3d" % actor.speed) + "\n"
	s += "Damage reductions :\n"
	s += (
		"    all       : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_all)
		+"\n"
	)
	s += (
		"    kinetic   : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_kinetic)
		+"\n"
	)
	s += (
		"    energy    : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_energy)
		+"\n"
	)
	s += (
		"    explosive : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_explosive)
		+"\n"
	)
	s += (
		"    plasma    : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_plasma)
		+"\n"
	)
	s += (
		"    corrosive : "
		+ UIColor.apply("damage_reduction", "%3d" % actor.damage_reduction_corrosive)
		+"\n"
	)
	entity_info.clear()
	entity_info.append_text(s)


func _combatant_name(actor: CombatActor) -> String:
	if not actor:
		return "Unknown"
	if actor.has_method("get_mek_name"):
		return str(actor.call("get_mek_name"))
	if actor.has_method("get_structure_name"):
		return str(actor.call("get_structure_name"))
	if not actor.alias.is_empty():
		return actor.alias
	return actor.uuid


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
