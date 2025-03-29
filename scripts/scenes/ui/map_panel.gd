extends Node

var grid_size: int = 50

@onready var advance_turn = $MapSelector/AdvanceTurn
@onready var save_map = $MapSelector/SaveMap
@onready var load_map = $MapSelector/LoadMap

@onready var generate = $MapSelector/Generate
@onready var delete = $MapSelector/Delete
@onready var map_list = $MapSelector/MapList

@onready var map_size = $MapSelector/HBoxContainer1/MapSize
@onready var map_difficulty = $MapSelector/HBoxContainer2/Difficulty
@onready var map_biome = $MapSelector/HBoxContainer3/Biome

@onready var map_hud = $MapHud


func _ready() -> void:
	GameServer.on_server_start.connect(_on_server_start)
	GameServer.on_server_stop.connect(_on_server_stop)
	advance_turn.pressed.connect(_on_advance_turn)
	generate.pressed.connect(_on_generate)
	delete.pressed.connect(_on_delete)
	save_map.pressed.connect(_on_save_map)
	load_map.pressed.connect(_on_load_map)
	map_list.item_selected.connect(_on_map_selected)
	var index = 0
	for difficulty_name in Enums.MapDifficulty:
		map_difficulty.add_item(difficulty_name, index)
		index += 1
	map_difficulty.select(0)
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
	map_list.clear()
	map_hud.clear()


func _on_generate():
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
			map_size.get_value(),
			map_difficulty.get_selected_id()
		)
		# Generate the map.
		game_map.generate_map()
		# Save the map to the data manager.
		DataManager.save_map(game_map)
		# Add the map to the map list.
		var index = map_list.add_item(game_map.map_uuid)
		# Set the map metadata.
		map_list.set_item_metadata(index, game_map)


func _on_delete():
	var index = _get_current_selected_map_index()
	if index >= 0:
		var game_map: GameMap = map_list.get_item_metadata(index)
		if game_map:
			DataManager.delete_map(game_map.map_uuid)
			map_list.remove_item(index)
			map_hud.clear()


func _on_map_selected(index: int):
	var game_map: GameMap = map_list.get_item_metadata(index)
	if game_map:
		map_hud.setup(game_map, grid_size)
		map_hud.zoom_out()


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


func _on_advance_turn():
	var game_map: GameMap = _get_current_selected_map()
	if game_map:
		game_map.process_round()


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
				map_hud.setup(game_map, grid_size)
				map_hud.zoom_out()
			else:
				map_list.remove_item(index)
	return null

func _input(_event):
	if Input.is_key_pressed(KEY_DELETE):
		var index = _get_current_selected_map_index()
		if index >= 0:
			var game_map: GameMap = map_list.get_item_metadata(index)
			if game_map:
				if map_hud.selected_entity:
					map_hud.info_panel.clear()
					map_hud.grid_drawer.deselect_entity()
					game_map.remove_entity(map_hud.selected_entity.entity.uuid)
					map_hud.mek_drawer.update_meks()
					map_hud.selected_entity = null
	elif Input.is_key_pressed(KEY_ESCAPE):
		map_hud.selected_entity = null
		map_hud.info_panel.clear()
		map_hud.grid_drawer.deselect_entity()
