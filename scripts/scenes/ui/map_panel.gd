extends Node

@onready var advance_turn  = $MapSelector/AdvanceTurn

@onready var generate = $MapSelector/Generate
@onready var delete   = $MapSelector/Delete
@onready var map_list = $MapSelector/MapList

@onready var map_size       = $MapSelector/HBoxContainer1/MapSize
@onready var map_difficulty = $MapSelector/HBoxContainer2/Difficulty
@onready var map_biome      = $MapSelector/HBoxContainer3/Biome

@onready var map_hud  = $MapHud

var grid_size: int = 50

func _ready() -> void:
	GameServer.on_server_start.connect(_on_server_start)
	GameServer.on_server_stop.connect(_on_server_stop)
	advance_turn.pressed.connect(_on_advance_turn)
	generate.pressed.connect(_on_generate)
	delete.pressed.connect(_on_delete)
	map_list.item_selected.connect(_on_map_selected)
	var difficulty_level = 0
	for difficulty_name in Enums.MapDifficulty:
		map_difficulty.add_item(difficulty_name, difficulty_level)
		difficulty_level += 1
	map_difficulty.select(0)
	
	GameServer.start()

func _on_server_start():
	for map_uuid in DataManager.maps:
		var game_map: GameMap = DataManager.maps[map_uuid]
		var index = map_list.add_item(game_map.map_uuid)
		map_list.set_item_metadata(index, game_map)
	
func _on_server_stop():
	map_list.clear()
	map_hud.clear()

func _on_generate():
	var game_map = GameMap.new(
		GameServer.generate_uuid(),
		map_biome.get_item_text(map_biome.get_selected_id()),
		map_size.get_value(),
		map_size.get_value()
	)
	game_map.generate_terrain()
	game_map.spawn_enemies_on_map(map_difficulty.get_selected_id())
	DataManager.save_map(game_map)
	var index = map_list.add_item(game_map.map_uuid)
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

func _input(_event):
	if Input.is_key_pressed(KEY_DELETE):
		var index = _get_current_selected_map_index()
		if index >= 0:
			var game_map: GameMap = map_list.get_item_metadata(index)
			if game_map:
				DataManager.delete_map(game_map.map_uuid)
				map_list.remove_item(index)
				map_hud.clear()
