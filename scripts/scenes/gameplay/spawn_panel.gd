extends PopupPanel

signal spawn_requested(request: Dictionary)

var _target_cell: Vector2i = Vector2i(-1, -1)

@onready var target_value: Label = $MarginContainer/Root/TargetRow/TargetValue
@onready var entity_type_option: OptionButton = $MarginContainer/Root/Form/EntityTypeOption
@onready var template_option: OptionButton = $MarginContainer/Root/Form/TemplateOption
@onready var quantity_spin: SpinBox = $MarginContainer/Root/Form/QuantitySpin
@onready var owner_type_option: OptionButton = $MarginContainer/Root/Form/OwnerTypeOption
@onready var clan_option: OptionButton = $MarginContainer/Root/Form/ClanOption
@onready var npc_name_edit: LineEdit = $MarginContainer/Root/Form/NpcNameEdit
@onready var player_option: OptionButton = $MarginContainer/Root/Form/PlayerOption
@onready var status_label: Label = $MarginContainer/Root/StatusLabel
@onready var spawn_button: Button = $MarginContainer/Root/Buttons/SpawnButton
@onready var cancel_button: Button = $MarginContainer/Root/Buttons/CancelButton


func _ready() -> void:
	spawn_button.pressed.connect(_on_spawn_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	entity_type_option.item_selected.connect(_on_entity_type_changed)
	owner_type_option.item_selected.connect(_on_owner_type_changed)


func open_for_cell(cell: Vector2i, default_clan_id: String = "") -> void:
	_target_cell = cell
	target_value.text = "(%d, %d)" % [cell.x, cell.y]

	_populate_entity_types()
	_populate_owner_types()
	_populate_clans(default_clan_id)
	_populate_players()
	_populate_templates()
	_apply_owner_field_visibility()

	quantity_spin.value = 1
	_set_status("")
	popup_centered_ratio(0.35)


func _populate_entity_types() -> void:
	entity_type_option.clear()
	entity_type_option.add_item("Mek")
	entity_type_option.set_item_metadata(0, "mek")
	entity_type_option.add_item("Structure")
	entity_type_option.set_item_metadata(1, "structure")
	entity_type_option.select(0)


func _populate_owner_types() -> void:
	owner_type_option.clear()
	owner_type_option.add_item("NPC Owner")
	owner_type_option.set_item_metadata(0, "npc")
	owner_type_option.add_item("Player Owner")
	owner_type_option.set_item_metadata(1, "player")
	owner_type_option.select(0)


func _populate_clans(default_clan_id: String) -> void:
	clan_option.clear()
	var clan_ids: Array[String] = []
	for clan_id: String in DataManager.clans.keys():
		clan_ids.append(clan_id)
	clan_ids.sort_custom(func(a: String, b: String):
		var clan_a: Clan = DataManager.clans[a]
		var clan_b: Clan = DataManager.clans[b]
		return clan_a.clan_name.to_lower() < clan_b.clan_name.to_lower()
	)

	var default_index: int = -1
	for index in range(clan_ids.size()):
		var clan_id: String = clan_ids[index]
		var clan: Clan = DataManager.clans[clan_id]
		clan_option.add_item(clan.clan_name)
		clan_option.set_item_metadata(index, clan_id)
		if clan_id == default_clan_id:
			default_index = index

	if default_index >= 0:
		clan_option.select(default_index)
	elif clan_option.item_count > 0:
		clan_option.select(0)


func _populate_players() -> void:
	player_option.clear()
	var players: Array[Player] = DataManager.players.values()
	players.sort_custom(func(a: Player, b: Player): return a.player_name.to_lower() < b.player_name.to_lower())
	for index in range(players.size()):
		var player: Player = players[index]
		player_option.add_item(player.player_name)
		player_option.set_item_metadata(index, player.player_uuid)
	if player_option.item_count > 0:
		player_option.select(0)


func _populate_templates() -> void:
	template_option.clear()
	var entity_type: String = _get_selected_metadata(entity_type_option)
	if entity_type == "mek":
		var ids: Array[String] = []
		for template_id: String in TemplateManager.mek_templates.keys():
			ids.append(template_id)
		ids.sort_custom(func(a: String, b: String):
			var ta: MekTemplate = TemplateManager.mek_templates[a]
			var tb: MekTemplate = TemplateManager.mek_templates[b]
			return ta.mek_name.to_lower() < tb.mek_name.to_lower()
		)
		for index in range(ids.size()):
			var template_id: String = ids[index]
			var template: MekTemplate = TemplateManager.mek_templates[template_id]
			template_option.add_item(template.mek_name)
			template_option.set_item_metadata(index, template_id)
	elif entity_type == "structure":
		var structure_ids: Array[String] = []
		for template_id: String in TemplateManager.structure_templates.keys():
			structure_ids.append(template_id)
		structure_ids.sort_custom(func(a: String, b: String):
			var sa: StructureTemplate = TemplateManager.structure_templates[a]
			var sb: StructureTemplate = TemplateManager.structure_templates[b]
			return sa.structure_name.to_lower() < sb.structure_name.to_lower()
		)
		for index in range(structure_ids.size()):
			var template_id: String = structure_ids[index]
			var template: StructureTemplate = TemplateManager.structure_templates[template_id]
			template_option.add_item(template.structure_name)
			template_option.set_item_metadata(index, template_id)

	if template_option.item_count > 0:
		template_option.select(0)


func _apply_owner_field_visibility() -> void:
	var owner_type: String = _get_selected_metadata(owner_type_option)
	var is_player_owner: bool = owner_type == "player"
	player_option.visible = is_player_owner
	npc_name_edit.visible = not is_player_owner


func _get_selected_metadata(option: OptionButton) -> String:
	if option.item_count <= 0:
		return ""
	var selected: int = option.get_selected()
	if selected < 0:
		return ""
	return str(option.get_item_metadata(selected))


func _on_entity_type_changed(_index: int) -> void:
	_populate_templates()


func _on_owner_type_changed(_index: int) -> void:
	_apply_owner_field_visibility()


func _on_cancel_pressed() -> void:
	hide()


func _on_spawn_pressed() -> void:
	var entity_type: String = _get_selected_metadata(entity_type_option)
	var template_id: String = _get_selected_metadata(template_option)
	var owner_type: String = _get_selected_metadata(owner_type_option)
	var clan_id: String = _get_selected_metadata(clan_option)
	var player_uuid: String = _get_selected_metadata(player_option)
	var npc_name: String = npc_name_edit.text.strip_edges()
	var quantity: int = int(quantity_spin.value)

	if entity_type.is_empty() or template_id.is_empty():
		_set_status("Select a valid type and template.")
		return
	if clan_id.is_empty():
		_set_status("Select a clan for ownership.")
		return
	if owner_type == "player" and player_uuid.is_empty():
		_set_status("Select a player for Player Owner mode.")
		return
	if owner_type == "npc" and npc_name.is_empty():
		npc_name = NameGenerator.random_full_name()

	var request: Dictionary = {
		"position": _target_cell,
		"entity_type": entity_type,
		"template_id": template_id,
		"quantity": max(1, quantity),
		"owner_type": owner_type,
		"clan_id": clan_id,
		"npc_name": npc_name,
		"player_uuid": player_uuid,
	}

	emit_signal("spawn_requested", request)
	hide()


func _set_status(message: String) -> void:
	status_label.text = message
