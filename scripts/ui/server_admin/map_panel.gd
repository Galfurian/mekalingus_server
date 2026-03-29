extends Node

@onready
var turn_management_panel = $LeftSidebarSplit/TopControlsSplit/TurnSection/TurnManagementPanel
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
	if map_hud and not map_hud.map_state_changed.is_connected(_on_map_hud_state_changed):
		map_hud.map_state_changed.connect(_on_map_hud_state_changed)
	map_management_panel.clear()
	turn_management_panel.clear()
	#GameServer.start()


func _on_server_start() -> void:
	map_management_panel.setup_from_data()


func _on_server_stop() -> void:
	map_management_panel.clear()
	map_hud.clear()
	turn_management_panel.clear()


func _on_map_selected(game_map: GameMap) -> void:
	if game_map:
		map_hud.setup(game_map)
	else:
		map_hud.clear()
	turn_management_panel.setup(game_map)


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
			turn_management_panel.refresh_state()
	elif Input.is_key_pressed(KEY_ESCAPE):
		map_hud.selected_entity = null
		map_hud.info_panel.clear()
		map_hud.grid_drawer.deselect_entity()


func _on_map_hud_state_changed(game_map: GameMap) -> void:
	var selected_map: GameMap = _get_current_selected_map()
	if selected_map:
		turn_management_panel.setup(selected_map)
		return
	if game_map:
		turn_management_panel.setup(game_map)
		return
	turn_management_panel.refresh_state()


func _on_turn_controls_changed(game_map: GameMap) -> void:
	if game_map:
		turn_management_panel.refresh_state()
