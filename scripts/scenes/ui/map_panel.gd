extends Node

@onready var turn_management_panel = $LeftSidebarSplit/TopControlsSplit/TurnSection/TurnInner/TurnManagementPanel
@onready var npc_directive_panel = $LeftSidebarSplit/TopControlsSplit/DirectiveSection/DirectiveInner/NpcDirectivePanel
@onready var save_map = $LeftSidebarSplit/MapManagerSection/MapManagerInner/StorageButtons/SaveMap
@onready var load_map = $LeftSidebarSplit/MapManagerSection/MapManagerInner/StorageButtons/LoadMap

@onready var generate = $LeftSidebarSplit/MapManagerSection/MapManagerInner/Generate
@onready var delete = $LeftSidebarSplit/MapManagerSection/MapManagerInner/Delete
@onready var map_list = $LeftSidebarSplit/MapManagerSection/MapManagerInner/MapList

@onready var map_size = $LeftSidebarSplit/MapManagerSection/MapManagerInner/HBoxContainer1/MapSize
@onready var map_biome = $LeftSidebarSplit/MapManagerSection/MapManagerInner/HBoxContainer3/Biome

@onready var map_hud = $MapHud


func _ready() -> void:
	GameServer.on_server_start.connect(_on_server_start)
	GameServer.on_server_stop.connect(_on_server_stop)
	generate.pressed.connect(_on_generate_map)
	delete.pressed.connect(_on_delete)
	save_map.pressed.connect(_on_save_map)
	load_map.pressed.connect(_on_load_map)
	map_list.item_selected.connect(_on_map_selected)
	if turn_management_panel and not turn_management_panel.turn_controls_changed.is_connected(_on_turn_controls_changed):
		turn_management_panel.turn_controls_changed.connect(_on_turn_controls_changed)
	if npc_directive_panel and not npc_directive_panel.directives_changed.is_connected(_on_directives_changed):
		npc_directive_panel.directives_changed.connect(_on_directives_changed)
	if npc_directive_panel and not npc_directive_panel.ai_overlay_toggled.is_connected(_on_ai_overlay_toggled):
		npc_directive_panel.ai_overlay_toggled.connect(_on_ai_overlay_toggled)
	if map_hud and not map_hud.map_state_changed.is_connected(_on_map_hud_state_changed):
		map_hud.map_state_changed.connect(_on_map_hud_state_changed)
	if map_hud and npc_directive_panel:
		map_hud.set_ai_overlay_enabled(npc_directive_panel.is_ai_overlay_enabled())
	turn_management_panel.clear()
	npc_directive_panel.clear()
	#GameServer.start()


func _on_server_start():
	var index: int
	for map_uuid in DataManager.maps:
		var game_map: GameMap = DataManager.maps[map_uuid]
		index = map_list.add_item(game_map.map_uuid)
		map_list.set_item_metadata(index, game_map)
	index = 0
	for biome in TemplateManager.biomes.values():
		map_biome.add_item(biome.biome_name, index)
		index += 1
	map_biome.select(0)


func _on_server_stop():
	map_biome.clear()
	map_list.clear()
	map_hud.clear()
	turn_management_panel.clear()
	npc_directive_panel.clear()


func _on_map_selected(index: int):
	var game_map: GameMap = map_list.get_item_metadata(index)
	if game_map:
		map_hud.setup(game_map)
	turn_management_panel.setup(game_map)
	npc_directive_panel.setup(game_map)


func _get_current_selected_map_index() -> int:
	"""Retrieves the currently selected GameMap index."""
	var index = map_list.get_selected_items()
	if index.is_empty():
		return -1
	return index[0]


func _get_current_selected_map() -> GameMap:
	"""Retrieves the currently selected GameMap index."""
	var index = _get_current_selected_map_index()
	if index >= 0:
		return map_list.get_item_metadata(index)
	return null


func _on_generate_map():
	# Get the biome name.
	var biome_name = map_biome.get_item_text(map_biome.get_selected_id())
	# Get the actual biome object.
	var biome = TemplateManager.get_biome(biome_name)
	# Check if the biome is valid.
	if biome:
		# Generate a unique map UUID.
		var map_uuid = GameServer.generate_uuid()
		# Create a new GameMap object.
		var game_map = GameMap.new(
			map_uuid,
			biome,
			map_size.get_value(),
			map_size.get_value()
		)
		# Generate the map.
		game_map.generate_map()
		# Save the map to the data manager.
		DataManager.save_map(game_map)
		# Add the map to the data manager.
		DataManager.add_map(game_map)
		# Add the map to the map list.
		var index = map_list.add_item(game_map.map_uuid)
		# Set the map metadata.
		map_list.set_item_metadata(index, game_map)
		turn_management_panel.setup(game_map)
		npc_directive_panel.setup(game_map)


func _on_save_map():
	var game_map: GameMap = _get_current_selected_map()
	if game_map:
		DataManager.save_map(game_map)


func _on_load_map():
	var index = _get_current_selected_map_index()
	if index >= 0:
		# Get the map.
		var game_map: GameMap = map_list.get_item_metadata(index)
		if game_map:
			# Get the map uuid.
			var map_uuid = game_map.map_uuid
			# Clear the map variable.
			game_map = null
			# Remove the reference to the map from the list.
			map_list.set_item_metadata(index, null)
			# Reload
			DataManager.reload_map(map_uuid)
			# Get the map again.
			game_map = DataManager.get_map(map_uuid)
			if game_map:
				# Set the map metadata.
				map_list.set_item_metadata(index, game_map)
				# Setup the map hud.
				map_hud.setup(game_map)
				turn_management_panel.setup(game_map)
				npc_directive_panel.setup(game_map)
			else:
				map_list.remove_item(index)
				turn_management_panel.clear()
				npc_directive_panel.clear()
	return null


func _on_delete():
	var index = _get_current_selected_map_index()
	if index >= 0:
		var game_map: GameMap = map_list.get_item_metadata(index)
		if game_map:
			DataManager.delete_map(game_map.map_uuid)
			map_list.remove_item(index)
			map_hud.clear()
			turn_management_panel.clear()
			npc_directive_panel.clear()


func _input(_event):
	if Input.is_key_pressed(KEY_DELETE):
		var index = _get_current_selected_map_index()
		if index >= 0:
			var game_map: GameMap = map_list.get_item_metadata(index)
			if game_map:
				if map_hud.selected_entity:
					map_hud.info_panel.clear()
					map_hud.grid_drawer.deselect_entity()
					game_map.remove_map_entity(map_hud.selected_entity)
					map_hud.icon_drawer.update_icons()
					map_hud.entity_list_panel.refresh()
					map_hud.selected_entity = null
					turn_management_panel.refresh_state()
					npc_directive_panel.refresh_state()
	elif Input.is_key_pressed(KEY_ESCAPE):
		map_hud.selected_entity = null
		map_hud.info_panel.clear()
		map_hud.grid_drawer.deselect_entity()


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


func _on_ai_overlay_toggled(enabled: bool) -> void:
	if map_hud:
		map_hud.set_ai_overlay_enabled(enabled)
