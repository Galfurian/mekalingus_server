extends PopupPanel

signal spawn_requested(request: Dictionary)

var _target_cell: Vector2i = Vector2i(-1, -1)
var _game_map: GameMap = null

@onready var target_value: Label = $MarginContainer/Root/TargetRow/TargetValue
@onready var entity_type_option: OptionButton = $MarginContainer/Root/Form/EntityTypeOption
@onready var template_option: OptionButton = $MarginContainer/Root/Form/TemplateOption
@onready var quantity_spin: SpinBox = $MarginContainer/Root/Form/QuantitySpin
@onready var clan_option: OptionButton = $MarginContainer/Root/Form/ClanOption
@onready var owner_type_option: OptionButton = $MarginContainer/Root/Form/OwnerTypeOption
@onready var npc_mode_label: Label = $MarginContainer/Root/Form/NpcModeLabel
@onready var npc_mode_option: OptionButton = $MarginContainer/Root/Form/NpcModeOption
@onready var npc_name_label: Label = $MarginContainer/Root/Form/NpcNameLabel
@onready var npc_name_edit: LineEdit = $MarginContainer/Root/Form/NpcNameEdit
@onready var npc_existing_label: Label = $MarginContainer/Root/Form/NpcExistingLabel
@onready var npc_existing_option: OptionButton = $MarginContainer/Root/Form/NpcExistingOption
@onready var player_label: Label = $MarginContainer/Root/Form/PlayerLabel
@onready var player_option: OptionButton = $MarginContainer/Root/Form/PlayerOption
@onready var status_label: Label = $MarginContainer/Root/StatusLabel
@onready var spawn_button: Button = $MarginContainer/Root/Buttons/SpawnButton
@onready var cancel_button: Button = $MarginContainer/Root/Buttons/CancelButton


func _ready() -> void:
	spawn_button.pressed.connect(_on_spawn_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	entity_type_option.item_selected.connect(_on_entity_type_changed)
	clan_option.item_selected.connect(_on_clan_changed)
	owner_type_option.item_selected.connect(_on_owner_type_changed)
	npc_mode_option.item_selected.connect(_on_npc_mode_changed)


func open_for_cell(
	cell: Vector2i,
	game_map: GameMap,
	default_clan_id: String = "",
	default_owner: EntityOwner = null
) -> void:
	_target_cell = cell
	_game_map = game_map
	target_value.text = "(%d, %d)" % [cell.x, cell.y]

	_populate_entity_types()
	_populate_owner_types()
	_populate_clans(default_clan_id)
	_populate_npc_modes()
	_populate_existing_npc_owners(default_owner)
	_populate_players()
	_populate_templates()
	_apply_owner_field_visibility()

	if is_instance_of(default_owner, NPCOwned):
		npc_name_edit.text = default_owner.npc_name
		if npc_existing_option.item_count > 0:
			npc_mode_option.select(1)
	elif is_instance_of(default_owner, PlayerOwned):
		owner_type_option.select(1)

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


func _populate_npc_modes() -> void:
	npc_mode_option.clear()
	npc_mode_option.add_item("New Commander")
	npc_mode_option.set_item_metadata(0, "new")
	npc_mode_option.add_item("Existing Commander")
	npc_mode_option.set_item_metadata(1, "existing")
	npc_mode_option.select(0)


func _populate_existing_npc_owners(default_owner: EntityOwner = null) -> void:
	npc_existing_option.clear()
	if not _game_map:
		return
	var selected_clan_id: String = _get_selected_metadata(clan_option)
	if selected_clan_id.is_empty():
		return

	var commander_map: Dictionary[String, String] = {}
	var npcs: Array[MapCombatEntity] = []
	for unit: MapCombatEntity in _game_map.npc_units.values():
		npcs.append(unit)
	for structure: MapStructure in _game_map.structures.values():
		npcs.append(structure)

	for unit: MapCombatEntity in npcs:
		if unit and is_instance_of(unit.owner, NPCOwned) and unit.owner.clan:
			if unit.owner.clan.id != selected_clan_id:
				continue
			var key: String = "%s|%s" % [unit.owner.npc_name, unit.owner.clan.id]
			if not commander_map.has(key):
				commander_map[key] = "%s (%s)" % [unit.owner.npc_name, unit.owner.clan.clan_name]

	var keys: Array[String] = commander_map.keys()
	keys.sort_custom(func(a: String, b: String): return commander_map[a].to_lower() < commander_map[b].to_lower())

	var default_index: int = -1
	for index in range(keys.size()):
		var key: String = keys[index]
		npc_existing_option.add_item(commander_map[key])
		npc_existing_option.set_item_metadata(index, key)
		if is_instance_of(default_owner, NPCOwned):
			var expected_key: String = "%s|%s" % [default_owner.npc_name, default_owner.clan.id]
			if key == expected_key:
				default_index = index

	if default_index >= 0:
		npc_existing_option.select(default_index)
	elif npc_existing_option.item_count > 0:
		npc_existing_option.select(0)


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
	player_label.visible = is_player_owner
	player_option.visible = is_player_owner
	npc_mode_label.visible = not is_player_owner
	npc_mode_option.visible = not is_player_owner

	if not is_player_owner and _get_selected_metadata(npc_mode_option) == "existing" and npc_existing_option.item_count <= 0:
		npc_mode_option.select(0)

	var use_existing_npc: bool = _get_selected_metadata(npc_mode_option) == "existing"
	npc_name_label.visible = not is_player_owner and not use_existing_npc
	npc_name_edit.visible = not is_player_owner and not use_existing_npc
	npc_existing_label.visible = not is_player_owner and use_existing_npc
	npc_existing_option.visible = not is_player_owner and use_existing_npc

	if not is_player_owner:
		var existing_index: int = 1
		if npc_mode_option.item_count > existing_index:
			npc_mode_option.set_item_disabled(existing_index, npc_existing_option.item_count <= 0)


func _get_selected_metadata(option: OptionButton) -> String:
	if option.item_count <= 0:
		return ""
	var selected: int = option.get_selected()
	if selected < 0:
		return ""
	return str(option.get_item_metadata(selected))


func _on_entity_type_changed(_index: int) -> void:
	_populate_templates()
	_set_status("")


func _on_clan_changed(_index: int) -> void:
	_populate_existing_npc_owners()
	_apply_owner_field_visibility()
	_set_status("")


func _on_owner_type_changed(_index: int) -> void:
	_apply_owner_field_visibility()
	_set_status("")


func _on_npc_mode_changed(_index: int) -> void:
	_apply_owner_field_visibility()
	_set_status("")


func _on_cancel_pressed() -> void:
	hide()


func _on_spawn_pressed() -> void:
	var entity_type: String = _get_selected_metadata(entity_type_option)
	var template_id: String = _get_selected_metadata(template_option)
	var owner_type: String = _get_selected_metadata(owner_type_option)
	var npc_mode: String = _get_selected_metadata(npc_mode_option)
	var clan_id: String = _get_selected_metadata(clan_option)
	var player_uuid: String = _get_selected_metadata(player_option)
	var npc_name: String = npc_name_edit.text.strip_edges()
	var existing_npc_key: String = _get_selected_metadata(npc_existing_option)
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
	if owner_type == "npc":
		if npc_mode == "existing":
			if existing_npc_key.is_empty() or not existing_npc_key.contains("|"):
				_set_status("Select an existing NPC commander.")
				return
			var parts := existing_npc_key.split("|", false, 2)
			npc_name = parts[0]
			clan_id = parts[1]
		elif npc_name.is_empty():
			npc_name = NameGenerator.random_full_name()

	var request: Dictionary = {
		"position": _target_cell,
		"entity_type": entity_type,
		"template_id": template_id,
		"quantity": max(1, quantity),
		"owner_type": owner_type,
		"npc_mode": npc_mode,
		"clan_id": clan_id,
		"npc_name": npc_name,
		"player_uuid": player_uuid,
	}

	emit_signal("spawn_requested", request)
	hide()


func _set_status(message: String) -> void:
	status_label.text = message
