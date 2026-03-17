extends Node


var game_map: GameMap
var entity: MapEntity
@onready var entity_info = $EntityInspector/EntityInfo
@onready var item_inspector = $EntityInspector/ItemInspector
@onready var plan_info: RichTextLabel = item_inspector.plan_info


func _ready() -> void:
	if not item_inspector.loadout_changed.is_connected(_on_item_inspector_loadout_changed):
		item_inspector.loadout_changed.connect(_on_item_inspector_loadout_changed)


func setup(p_game_map: GameMap) -> void:
	clear()
	game_map = p_game_map
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)


func clear() -> void:
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	entity = null
	game_map = null
	entity_info.clear()
	item_inspector.clear()


func _on_turn_ended(_turn_number: int) -> void:
	update_panel()


func set_entity(new_entity: MapEntity) -> void:
	entity = new_entity
	update_panel()


func update_panel() -> void:
	if not is_instance_valid(entity):
		entity_info.clear()
		item_inspector.clear()
		return

	if is_instance_of(entity, MapCombatEntity):
		var map_combat_entity: MapCombatEntity = entity
		entity_info.display_combat_entity(map_combat_entity)
		item_inspector.display_combat_entity(game_map, map_combat_entity)
		return

	entity_info.clear()
	item_inspector.clear()


func select_item_by_uuid(uuid: String) -> void:
	item_inspector.select_item_by_uuid(uuid)


func _on_item_inspector_loadout_changed() -> void:
	if not is_instance_valid(entity) or not is_instance_of(entity, MapCombatEntity):
		return

	entity_info.display_combat_entity(entity as MapCombatEntity)
