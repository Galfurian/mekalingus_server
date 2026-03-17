extends Node

@onready
var turn_management_panel = $LeftSidebarSplit/TopControlsSplit/TurnSection/TurnManagementPanel
@onready
var npc_directive_panel = $LeftSidebarSplit/TopControlsSplit/DirectiveSection/NpcDirectivePanel
@onready
var map_management_panel = $LeftSidebarSplit/TopControlsSplit/MapManagerSection/MapManagementPanel

@onready var map_hud = $MapHud


func _ready() -> void:
	GameServer.on_server_start.connect(_on_server_start)
	GameServer.on_server_stop.connect(_on_server_stop)
	if (
		map_management_panel
		and not map_management_panel.map_selection_changed.is_connected(_on_map_selected)
	):
		map_management_panel.map_selection_changed.connect(_on_map_selected)
	if (
		turn_management_panel
		and not turn_management_panel.turn_controls_changed.is_connected(_on_turn_controls_changed)
	):
		turn_management_panel.turn_controls_changed.connect(_on_turn_controls_changed)
	if (
		npc_directive_panel
		and not npc_directive_panel.directives_changed.is_connected(_on_directives_changed)
	):
		npc_directive_panel.directives_changed.connect(_on_directives_changed)
	if (
		npc_directive_panel
		and not npc_directive_panel.ai_overlay_toggled.is_connected(_on_ai_overlay_toggled)
	):
		npc_directive_panel.ai_overlay_toggled.connect(_on_ai_overlay_toggled)
	if (
		npc_directive_panel
		and not npc_directive_panel.anchor_pick_mode_changed.is_connected(
			_on_anchor_pick_mode_changed
		)
	):
		npc_directive_panel.anchor_pick_mode_changed.connect(_on_anchor_pick_mode_changed)
	if map_hud and not map_hud.map_state_changed.is_connected(_on_map_hud_state_changed):
		map_hud.map_state_changed.connect(_on_map_hud_state_changed)
	if map_hud and not map_hud.map_cell_clicked.is_connected(_on_map_cell_clicked):
		map_hud.map_cell_clicked.connect(_on_map_cell_clicked)
	if map_hud and not map_hud.selected_entity_changed.is_connected(_on_selected_entity_changed):
		map_hud.selected_entity_changed.connect(_on_selected_entity_changed)
	if map_hud and npc_directive_panel:
		map_hud.set_ai_overlay_enabled(npc_directive_panel.is_ai_overlay_enabled())
		map_hud.set_anchor_pick_mode_enabled(npc_directive_panel.is_anchor_pick_mode_enabled())
	map_management_panel.clear()
	turn_management_panel.clear()
	npc_directive_panel.clear()
	#GameServer.start()


func _on_server_start() -> void:
	map_management_panel.setup_from_data()


func _on_server_stop() -> void:
	map_management_panel.clear()
	map_hud.clear()
	turn_management_panel.clear()
	npc_directive_panel.clear()


func _on_map_selected(game_map: GameMap) -> void:
	if game_map:
		map_hud.setup(game_map)
	else:
		map_hud.clear()
	turn_management_panel.setup(game_map)
	npc_directive_panel.setup(game_map)
	npc_directive_panel.set_selected_entity(map_hud.selected_entity)


func _get_current_selected_map() -> GameMap:
	if not map_management_panel:
		return null
	return map_management_panel.get_current_selected_map()


func _input(_event):
	if Input.is_key_pressed(KEY_DELETE):
		var game_map: GameMap = _get_current_selected_map()
		if game_map and map_hud.selected_entity:
			map_hud.info_panel.clear()
			map_hud.grid_drawer.deselect_entity()
			game_map.remove_map_entity(map_hud.selected_entity)
			map_hud.icon_drawer.update_icons()
			map_hud.entity_list_panel.refresh()
			map_hud.selected_entity = null
			npc_directive_panel.set_selected_entity(null)
			turn_management_panel.refresh_state()
			npc_directive_panel.refresh_state()
	elif Input.is_key_pressed(KEY_ESCAPE):
		map_hud.selected_entity = null
		map_hud.info_panel.clear()
		map_hud.grid_drawer.deselect_entity()
		npc_directive_panel.set_selected_entity(null)


func _on_map_hud_state_changed(game_map: GameMap) -> void:
	var selected_map: GameMap = _get_current_selected_map()
	if selected_map:
		turn_management_panel.setup(selected_map)
		npc_directive_panel.setup(selected_map)
		return
	if game_map:
		turn_management_panel.setup(game_map)
		npc_directive_panel.setup(game_map)
		return
	turn_management_panel.refresh_state()
	npc_directive_panel.refresh_state()


func _on_turn_controls_changed(game_map: GameMap) -> void:
	if game_map:
		turn_management_panel.refresh_state()
		npc_directive_panel.refresh_state()


func _on_directives_changed(game_map: GameMap) -> void:
	if game_map:
		npc_directive_panel.refresh_state()
		map_hud.entity_list_panel.refresh()
		map_hud.refresh_ai_overlay()
		map_hud.info_panel.update_panel()


func _on_ai_overlay_toggled(enabled: bool) -> void:
	if map_hud:
		map_hud.set_ai_overlay_enabled(enabled)


func _on_anchor_pick_mode_changed(enabled: bool) -> void:
	if map_hud:
		map_hud.set_anchor_pick_mode_enabled(enabled)


func _on_map_cell_clicked(cell_position: Vector2i) -> void:
	if npc_directive_panel:
		npc_directive_panel.apply_anchor_from_map(cell_position)


func _on_selected_entity_changed(entity: MapEntity) -> void:
	if npc_directive_panel:
		npc_directive_panel.set_selected_entity(entity)
