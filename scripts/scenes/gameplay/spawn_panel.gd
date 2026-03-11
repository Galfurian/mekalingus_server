extends PopupPanel

signal spawn_requested(request: Dictionary)

const _UNIT_ROW := preload("res://scripts/scenes/gameplay/spawn_unit_row.gd")

var _target_cell: Vector2i = Vector2i(-1, -1)
var _game_map: GameMap = null

@onready var target_value: Label = $MarginContainer/Root/TargetRow/TargetValue
@onready var spawn_mode_option: OptionButton = $MarginContainer/Root/SpawnModeRow/SpawnModeOption
# Left panel — Owner
@onready var clan_option: OptionButton = $MarginContainer/Root/Panels/Left/LeftForm/ClanOption
@onready var owner_type_option: OptionButton = $MarginContainer/Root/Panels/Left/LeftForm/OwnerTypeOption
@onready var npc_commander_label: Label = $MarginContainer/Root/Panels/Left/LeftForm/NpcCommanderLabel
@onready var npc_commander_option: OptionButton = $MarginContainer/Root/Panels/Left/LeftForm/NpcCommanderOption
@onready var npc_name_label: Label = $MarginContainer/Root/Panels/Left/LeftForm/NpcNameLabel
@onready var npc_name_edit: LineEdit = $MarginContainer/Root/Panels/Left/LeftForm/NpcNameEdit
@onready var player_label: Label = $MarginContainer/Root/Panels/Left/LeftForm/PlayerLabel
@onready var player_option: OptionButton = $MarginContainer/Root/Panels/Left/LeftForm/PlayerOption
# Right panel — Content
@onready var entity_type_option: OptionButton = $MarginContainer/Root/Panels/Right/SingleForm/EntityTypeOption
@onready var template_option: OptionButton = $MarginContainer/Root/Panels/Right/SingleForm/TemplateOption
@onready var quantity_spin: SpinBox = $MarginContainer/Root/Panels/Right/SingleForm/QuantitySpin
@onready var loadout_option: OptionButton = $MarginContainer/Root/Panels/Right/SingleForm/LoadoutOption
@onready var single_form: GridContainer = $MarginContainer/Root/Panels/Right/SingleForm
@onready var multi_form: VBoxContainer = $MarginContainer/Root/Panels/Right/MultiForm
@onready var unit_list: VBoxContainer = $MarginContainer/Root/Panels/Right/MultiForm/MultiScroll/UnitList
@onready var add_unit_button: Button = $MarginContainer/Root/Panels/Right/MultiForm/AddUnitRow/AddUnitButton
@onready var status_label: Label = $MarginContainer/Root/StatusLabel
@onready var spawn_button: Button = $MarginContainer/Root/Buttons/SpawnButton
@onready var cancel_button: Button = $MarginContainer/Root/Buttons/CancelButton


func _ready() -> void:
	spawn_button.pressed.connect(_on_spawn_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	spawn_mode_option.item_selected.connect(_on_spawn_mode_changed)
	entity_type_option.item_selected.connect(_on_entity_type_changed)
	clan_option.item_selected.connect(_on_clan_changed)
	owner_type_option.item_selected.connect(_on_owner_type_changed)
	npc_commander_option.item_selected.connect(_on_npc_commander_changed)
	add_unit_button.pressed.connect(_on_add_unit_pressed)


func open_for_cell(
	cell: Vector2i,
	game_map: GameMap,
	default_clan_id: String = "",
	default_owner: EntityOwner = null
) -> void:
	_target_cell = cell
	_game_map = game_map
	target_value.text = "(%d, %d)" % [cell.x, cell.y]

	_populate_spawn_modes()
	_populate_owner_types()
	_populate_clans(default_clan_id)
	_populate_npc_commander_option(default_owner)
	_populate_players()
	_populate_entity_types()
	_populate_templates()
	_populate_loadout_options()

	if is_instance_of(default_owner, NPCOwned):
		npc_name_edit.text = default_owner.npc_name
	elif is_instance_of(default_owner, PlayerOwned):
		owner_type_option.select(1)

	_apply_owner_field_visibility()
	_apply_content_visibility()

	quantity_spin.value = 1
	_set_status("")
	popup_centered_ratio(0.35)


func _populate_spawn_modes() -> void:
	spawn_mode_option.clear()
	spawn_mode_option.add_item("Single Entity")
	spawn_mode_option.set_item_metadata(0, "single")
	spawn_mode_option.add_item("Squad")
	spawn_mode_option.set_item_metadata(1, "squad")
	spawn_mode_option.add_item("Outpost")
	spawn_mode_option.set_item_metadata(2, "outpost")
	spawn_mode_option.select(0)


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


func _populate_npc_commander_option(default_owner: EntityOwner = null) -> void:
	npc_commander_option.clear()
	npc_commander_option.add_item("New Commander")
	npc_commander_option.set_item_metadata(0, "new")

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
				commander_map[key] = unit.owner.npc_name

	if commander_map.is_empty():
		return

	var keys: Array[String] = commander_map.keys()
	keys.sort_custom(func(a: String, b: String): return commander_map[a].to_lower() < commander_map[b].to_lower())

	npc_commander_option.add_separator()

	var default_index: int = -1
	for key: String in keys:
		var item_index: int = npc_commander_option.item_count
		npc_commander_option.add_item(commander_map[key])
		npc_commander_option.set_item_metadata(item_index, key)
		if is_instance_of(default_owner, NPCOwned) and default_owner.clan:
			var expected_key: String = "%s|%s" % [default_owner.npc_name, default_owner.clan.id]
			if key == expected_key:
				default_index = item_index

	if default_index >= 0:
		npc_commander_option.select(default_index)


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
		var grouped: Dictionary = {
			Enums.MekSize.LIGHT: [],
			Enums.MekSize.MEDIUM: [],
			Enums.MekSize.HEAVY: [],
			Enums.MekSize.COLOSSAL: [],
		}
		for template_id: String in TemplateManager.mek_templates.keys():
			var template: MekTemplate = TemplateManager.mek_templates[template_id]
			grouped[template.size].append({ "id": template_id, "name": template.mek_name })

		var size_order: Array[int] = [
			Enums.MekSize.LIGHT,
			Enums.MekSize.MEDIUM,
			Enums.MekSize.HEAVY,
			Enums.MekSize.COLOSSAL,
		]
		var added_group: bool = false
		for size_class: int in size_order:
			var group: Array[Dictionary] = grouped[size_class]
			if group.is_empty():
				continue
			group.sort_custom(func(a: Dictionary, b: Dictionary):
				return a["name"].to_lower() < b["name"].to_lower()
			)
			if added_group:
				template_option.add_separator()
			added_group = true
			for entry: Dictionary in group:
				template_option.add_item(entry["name"])
				template_option.set_item_metadata(template_option.item_count - 1, entry["id"])
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
	npc_commander_label.visible = not is_player_owner
	npc_commander_option.visible = not is_player_owner

	var is_new_commander: bool = _get_selected_metadata(npc_commander_option) == "new"
	npc_name_label.visible = not is_player_owner and is_new_commander
	npc_name_edit.visible = not is_player_owner and is_new_commander


func _get_selected_metadata(option: OptionButton) -> String:
	if option.item_count <= 0:
		return ""
	var selected: int = option.get_selected()
	if selected < 0:
		return ""
	return str(option.get_item_metadata(selected))


func _populate_loadout_options() -> void:
	loadout_option.clear()
	loadout_option.add_item("None")
	loadout_option.set_item_metadata(0, "none")
	loadout_option.add_item("Random")
	loadout_option.set_item_metadata(1, "random")
	loadout_option.select(0)


func _on_spawn_mode_changed(_index: int) -> void:
	_apply_content_visibility()
	var new_mode: String = _get_selected_metadata(spawn_mode_option)
	if new_mode in ["squad", "outpost"]:
		_clear_unit_list()
		_add_unit_row(_default_unit_type_for_mode())
	_set_status("")


func _on_entity_type_changed(_index: int) -> void:
	_populate_templates()
	_set_status("")


func _on_clan_changed(_index: int) -> void:
	_populate_npc_commander_option()
	_apply_owner_field_visibility()
	_set_status("")


func _on_owner_type_changed(_index: int) -> void:
	_apply_owner_field_visibility()
	_set_status("")


func _on_npc_commander_changed(_index: int) -> void:
	_apply_owner_field_visibility()
	_set_status("")


func _apply_content_visibility() -> void:
	var is_single: bool = _get_selected_metadata(spawn_mode_option) == "single"
	single_form.visible = is_single
	multi_form.visible = not is_single


func _clear_unit_list() -> void:
	for child in unit_list.get_children():
		child.queue_free()


func _add_unit_row(default_type: String = "mek") -> void:
	var row := _UNIT_ROW.new()
	row.remove_requested.connect(func(): _remove_unit_row(row))
	unit_list.add_child(row)
	row.init_with_type(default_type)


func _remove_unit_row(row: Node) -> void:
	row.queue_free()


func _default_unit_type_for_mode() -> String:
	return "structure" if _get_selected_metadata(spawn_mode_option) == "outpost" else "mek"


func _on_add_unit_pressed() -> void:
	_add_unit_row(_default_unit_type_for_mode())


func _on_cancel_pressed() -> void:
	hide()


func _on_spawn_pressed() -> void:
	var owner_request: Dictionary = _build_owner_request()
	if owner_request.is_empty():
		return

	var spawn_mode: String = _get_selected_metadata(spawn_mode_option)
	match spawn_mode:
		"single":
			_submit_single(owner_request)
		"squad", "outpost":
			_submit_multi(owner_request, spawn_mode)


func _build_owner_request() -> Dictionary:
	var owner_type: String = _get_selected_metadata(owner_type_option)
	var clan_id: String = _get_selected_metadata(clan_option)
	var player_uuid: String = _get_selected_metadata(player_option)
	var commander_meta: String = _get_selected_metadata(npc_commander_option)
	var npc_mode: String = "new" if commander_meta == "new" else "existing"
	var npc_name: String = npc_name_edit.text.strip_edges()

	if clan_id.is_empty():
		_set_status("Select a clan for ownership.")
		return {}
	if owner_type == "player" and player_uuid.is_empty():
		_set_status("Select a player for Player Owner mode.")
		return {}
	if owner_type == "npc":
		if npc_mode == "existing":
			if commander_meta.is_empty() or not commander_meta.contains("|"):
				_set_status("Select an existing NPC commander.")
				return {}
			var parts := commander_meta.split("|", false, 2)
			npc_name = parts[0]
			clan_id = parts[1]
		elif npc_name.is_empty():
			npc_name = NameGenerator.random_full_name()

	return {
		"owner_type": owner_type,
		"npc_mode": npc_mode,
		"clan_id": clan_id,
		"npc_name": npc_name,
		"player_uuid": player_uuid,
	}


func _submit_single(owner_request: Dictionary) -> void:
	var entity_type: String = _get_selected_metadata(entity_type_option)
	var template_id: String = _get_selected_metadata(template_option)
	if entity_type.is_empty() or template_id.is_empty():
		_set_status("Select a valid type and template.")
		return

	var request: Dictionary = owner_request.duplicate()
	request["position"] = _target_cell
	request["spawn_mode"] = "single"
	request["entity_type"] = entity_type
	request["template_id"] = template_id
	request["loadout"] = _get_selected_metadata(loadout_option)
	request["quantity"] = max(1, int(quantity_spin.value))
	spawn_requested.emit(request)
	hide()


func _submit_multi(owner_request: Dictionary, spawn_mode: String) -> void:
	var units: Array[Dictionary] = []
	for child in unit_list.get_children():
		if child is _UNIT_ROW:
			var entry: Dictionary = child.to_dict()
			if entry["entity_type"].is_empty() or entry["template_id"].is_empty():
				_set_status("Each unit must have a valid template selected.")
				return
			units.append(entry)

	if units.is_empty():
		_set_status("Add at least one unit.")
		return

	var request: Dictionary = owner_request.duplicate()
	request["position"] = _target_cell
	request["spawn_mode"] = spawn_mode
	request["units"] = units
	spawn_requested.emit(request)
	hide()


func _set_status(message: String) -> void:
	status_label.text = message
