extends Control


signal item_selected(item)
signal loadout_changed(selected_item)


const SLOT_ORDER: Array[int] = [
	Enums.SlotType.SMALL,
	Enums.SlotType.MEDIUM,
	Enums.SlotType.LARGE,
	Enums.SlotType.UTILITY,
]


var _actor: CombatActor = null
var _slot_editor_rows: Dictionary = {}
var _is_rebuilding_editors: bool = false


@onready var slot_editor_container: VBoxContainer = $SlotEditorScroll/SlotEditorContainer


func clear() -> void:
	_actor = null
	_clear_slot_editor_container()
	_slot_editor_rows.clear()


func display_combatant(actor: CombatActor) -> void:
	_actor = actor
	_rebuild_slot_editors()


func _rebuild_slot_editors() -> void:
	_is_rebuilding_editors = true
	_clear_slot_editor_container()
	_slot_editor_rows.clear()

	if not _actor:
		_is_rebuilding_editors = false
		return

	var templates_by_slot: Dictionary = _build_templates_by_slot()
	var equipped_by_slot: Dictionary = _build_equipped_items_by_slot(_actor)
	var capacities: Dictionary = _build_slot_capacities(_actor, equipped_by_slot)

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

	var available_power: int = _available_power_for_slot(current_item)
	for template: ItemTemplate in templates:
		# Filter out templates that exceed currently available power.
		if template.base_power_usage > available_power:
			continue
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


func _available_power_for_slot(current_item: Item) -> int:
	"""Returns how much power is available for selecting a new item in this slot.

	This excludes the power cost of the currently-equipped item in the slot so
	the user can freely swap without being blocked by a removed item's cost.
	"""
	if not _actor:
		return 0

	var used_power: int = 0
	for item in _actor.items:
		if not item or not item.template:
			continue
		if item == current_item:
			continue
		used_power += int(item.template.base_power_usage)

	return max(0, _actor.max_power - used_power)


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
	item_selected.emit(row_data.get("item", null))


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
	if not _actor:
		return

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

	_actor.items = new_items
	_actor.items.sort_custom(Item.compare_items)
	_actor.rebuild_combat_state()
	display_combatant(_actor)

	loadout_changed.emit(_find_selected_item(selected_template_id))


func _find_selected_item(selected_template_id: String) -> Item:
	if not _actor or selected_template_id.is_empty():
		return null

	for item: Item in _actor.items:
		if item and item.template and item.template.id == selected_template_id:
			return item
	return null


func _get_slot_color(slot: Enums.SlotType) -> Color:
	var slot_colors = {
		Enums.SlotType.SMALL: Color(0.6, 0.6, 1.0),
		Enums.SlotType.MEDIUM: Color(0.3, 0.8, 0.3),
		Enums.SlotType.LARGE: Color(1.0, 0.5, 0.3),
		Enums.SlotType.UTILITY: Color(1.0, 1.0, 0.4),
	}
	return slot_colors.get(slot, Color.WHITE)