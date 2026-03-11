class_name SpawnUnitRow
extends HBoxContainer

## A single configurable unit row for the squad / outpost spawn form.
## Builds its own child controls and populates template lists from TemplateManager.

signal remove_requested

var entity_type_option: OptionButton
var template_option: OptionButton
var loadout_option: OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 4)

	entity_type_option = OptionButton.new()
	entity_type_option.custom_minimum_size = Vector2(90, 0)
	entity_type_option.add_item("Mek")
	entity_type_option.set_item_metadata(0, "mek")
	entity_type_option.add_item("Structure")
	entity_type_option.set_item_metadata(1, "structure")
	entity_type_option.item_selected.connect(_on_entity_type_changed)
	add_child(entity_type_option)

	template_option = OptionButton.new()
	template_option.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(template_option)

	loadout_option = OptionButton.new()
	loadout_option.custom_minimum_size = Vector2(90, 0)
	loadout_option.add_item("No Loadout")
	loadout_option.set_item_metadata(0, "none")
	loadout_option.add_item("Random")
	loadout_option.set_item_metadata(1, "random")
	add_child(loadout_option)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.custom_minimum_size = Vector2(28, 0)
	remove_button.pressed.connect(func(): remove_requested.emit())
	add_child(remove_button)

	_populate_templates()


## Selects the given entity type and refreshes the template list.
func init_with_type(entity_type: String) -> void:
	for i in entity_type_option.item_count:
		if str(entity_type_option.get_item_metadata(i)) == entity_type:
			entity_type_option.select(i)
			break
	_populate_templates()


## Returns the current row configuration as a plain dictionary.
func to_dict() -> Dictionary:
	return {
		"entity_type": _selected_meta(entity_type_option),
		"template_id": _selected_meta(template_option),
		"loadout": _selected_meta(loadout_option),
	}


func _on_entity_type_changed(_index: int) -> void:
	_populate_templates()


func _populate_templates() -> void:
	template_option.clear()
	var entity_type: String = _selected_meta(entity_type_option)
	var items: Array[Dictionary] = []

	if entity_type == "mek":
		for id: String in TemplateManager.mek_templates.keys():
			var tmpl: MekTemplate = TemplateManager.mek_templates[id]
			items.append({ "id": id, "name": tmpl.mek_name })
	elif entity_type == "structure":
		for id: String in TemplateManager.structure_templates.keys():
			var tmpl: StructureTemplate = TemplateManager.structure_templates[id]
			items.append({ "id": id, "name": tmpl.structure_name })

	items.sort_custom(func(a: Dictionary, b: Dictionary):
		return a["name"].to_lower() < b["name"].to_lower()
	)

	for i in range(items.size()):
		template_option.add_item(items[i]["name"])
		template_option.set_item_metadata(i, items[i]["id"])
	if template_option.item_count > 0:
		template_option.select(0)


func _selected_meta(option: OptionButton) -> String:
	if option.item_count <= 0 or option.get_selected() < 0:
		return ""
	return str(option.get_item_metadata(option.get_selected()))
