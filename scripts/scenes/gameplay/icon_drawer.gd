extends Node2D

# =============================================================================
# CONSTANTS
# =============================================================================

const DEFAULT_ICON_PATH = "res://assets/tileset/meks/mek.png"
const ICON_BASE_PATH = "res://assets/tileset/"

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var grid_size: int
var sector_size: int
var entity_sprites: Dictionary
var _texture_cache: Dictionary

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func setup(p_game_map: GameMap, p_grid_size: int, p_sector_size: int) -> void:
	clear()
	game_map = p_game_map
	grid_size = p_grid_size
	sector_size = p_sector_size
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	update_icons()


func clear() -> void:
	if game_map and game_map.turn_manager and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	game_map = null
	grid_size = 0
	sector_size = 0
	for sprite in entity_sprites.values():
		sprite.queue_free()

	entity_sprites.clear()
	_texture_cache.clear()


func _on_turn_ended(_turn_number: int) -> void:
	update_icons()


func _get_clan_color(entity_owner: EntityOwner) -> Color:
	if entity_owner and entity_owner.clan:
		return entity_owner.clan.color
	return Color(1, 1, 1, 0.4)


func update_icons() -> void:
	"""Creates and updates map entity icons based on game state."""
	if not game_map:
		return

	var active_entities: Dictionary = _collect_drawable_entities()

	for entity_key in entity_sprites.keys():
		if not active_entities.has(entity_key):
			entity_sprites[entity_key].queue_free()
			entity_sprites.erase(entity_key)

	for entity_key in active_entities.keys():
		var map_entity: MapEntity = active_entities[entity_key]
		var icon_position: Vector2i = map_entity.position
		var center := Vector2(
			(sector_size + icon_position.x + 0.5) * grid_size,
			(sector_size + icon_position.y + 0.5) * grid_size
		)

		var sprite: Sprite2D
		if entity_sprites.has(entity_key):
			sprite = entity_sprites[entity_key]
		else:
			sprite = Sprite2D.new()
			sprite.position = Vector2.ZERO
			sprite.modulate = _get_clan_color(map_entity.owner)
			add_child(sprite)
			entity_sprites[entity_key] = sprite

		var texture: Texture2D = _load_icon_texture_for_entity(map_entity)
		if texture:
			sprite.texture = texture
			sprite.scale = Vector2(grid_size / texture.get_size().x, grid_size / texture.get_size().y)
			sprite.position = center
			sprite.modulate = _get_clan_color(map_entity.owner)


func _collect_drawable_entities() -> Dictionary:
	var entities: Dictionary = {}

	for unit_uuid in game_map.player_units.keys():
		var unit: MapCombatEntity = game_map.player_units[unit_uuid]
		if unit and unit.active:
			entities["player:" + unit_uuid] = unit

	for unit_uuid in game_map.npc_units.keys():
		var unit: MapCombatEntity = game_map.npc_units[unit_uuid]
		if unit and unit.active:
			entities["npc:" + unit_uuid] = unit

	for structure_uuid in game_map.structures.keys():
		var structure: MapStructure = game_map.structures[structure_uuid]
		if structure and structure.active:
			entities["structure:" + structure_uuid] = structure

	return entities


func _load_icon_texture_for_entity(entity: MapEntity) -> Texture2D:
	var icon_path: String = str(entity.get_icon_path()).strip_edges()
	if icon_path.is_empty():
		icon_path = DEFAULT_ICON_PATH
	elif not icon_path.begins_with("res://"):
		icon_path = ICON_BASE_PATH + icon_path

	if not ResourceLoader.exists(icon_path):
		icon_path = DEFAULT_ICON_PATH

	if not _texture_cache.has(icon_path):
		_texture_cache[icon_path] = load(icon_path)

	return _texture_cache[icon_path]
