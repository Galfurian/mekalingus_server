extends VBoxContainer

signal map_selection_changed(game_map: GameMap)

@onready var save_map: Button = $Section/Inner/StorageButtons/SaveMap
@onready var load_map: Button = $Section/Inner/StorageButtons/LoadMap
@onready var map_list: ItemList = $Section/Inner/MapList
@onready var map_size: SpinBox = $Section/Inner/HBoxContainer1/MapSize
@onready var map_biome: OptionButton = $Section/Inner/HBoxContainer3/Biome
@onready var generate: Button = $Section/Inner/ControlButtons/Generate
@onready var delete: Button = $Section/Inner/ControlButtons/Delete


func _ready() -> void:
	save_map.pressed.connect(_on_save_map)
	load_map.pressed.connect(_on_load_map)
	generate.pressed.connect(_on_generate_map)
	delete.pressed.connect(_on_delete)
	map_list.item_selected.connect(_on_map_selected)
	clear()


func clear() -> void:
	map_biome.clear()
	map_list.clear()


func setup_from_data() -> void:
	clear()

	var index: int = 0
	for map_uuid in DataManager.maps:
		var game_map: GameMap = DataManager.maps[map_uuid]
		index = map_list.add_item(game_map.map_uuid)
		map_list.set_item_metadata(index, game_map)

	index = 0
	for biome in TemplateManager.biomes.values():
		map_biome.add_item(biome.biome_name, index)
		index += 1

	if map_biome.item_count > 0:
		map_biome.select(0)


func get_current_selected_map() -> GameMap:
	var index: int = _get_current_selected_map_index()
	if index >= 0:
		return map_list.get_item_metadata(index)
	return null


func _get_current_selected_map_index() -> int:
	var selected_items: PackedInt32Array = map_list.get_selected_items()
	if selected_items.is_empty():
		return -1
	return selected_items[0]


func _on_map_selected(index: int) -> void:
	var game_map: GameMap = map_list.get_item_metadata(index)
	map_selection_changed.emit(game_map)


func _on_generate_map() -> void:
	if map_biome.item_count <= 0:
		return

	# Resolve selected biome and create a new map from panel inputs.
	var biome_name: String = map_biome.get_item_text(map_biome.get_selected_id())
	var biome = TemplateManager.get_biome(biome_name)
	if not biome:
		return

	var map_uuid: String = GameServer.generate_uuid()
	var map_dimension: int = int(map_size.value)
	var game_map := GameMap.new(map_uuid, biome, map_dimension, map_dimension)
	game_map.generate_map()

	DataManager.save_map(game_map)
	DataManager.add_map(game_map)

	var index: int = map_list.add_item(game_map.map_uuid)
	map_list.set_item_metadata(index, game_map)
	map_list.select(index)
	map_selection_changed.emit(game_map)


func _on_save_map() -> void:
	var game_map: GameMap = get_current_selected_map()
	if game_map:
		DataManager.save_map(game_map)


func _on_load_map() -> void:
	var index: int = _get_current_selected_map_index()
	if index < 0:
		return

	var game_map: GameMap = map_list.get_item_metadata(index)
	if not game_map:
		return

	var map_uuid: String = game_map.map_uuid
	map_list.set_item_metadata(index, null)

	DataManager.reload_map(map_uuid)
	game_map = DataManager.get_map(map_uuid)
	if game_map:
		map_list.set_item_metadata(index, game_map)
		map_list.select(index)
		map_selection_changed.emit(game_map)
		return

	map_list.remove_item(index)
	map_selection_changed.emit(get_current_selected_map())


func _on_delete() -> void:
	var index: int = _get_current_selected_map_index()
	if index < 0:
		return

	var game_map: GameMap = map_list.get_item_metadata(index)
	if not game_map:
		return

	DataManager.delete_map(game_map.map_uuid)
	map_list.remove_item(index)

	if map_list.item_count > 0:
		var next_index: int = mini(index, map_list.item_count - 1)
		map_list.select(next_index)

	map_selection_changed.emit(get_current_selected_map())
