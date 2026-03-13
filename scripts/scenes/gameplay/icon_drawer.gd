extends Node2D

# =============================================================================
# CONSTANTS
# =============================================================================

const DEFAULT_ICON_PATH = "res://assets/tileset/meks/mek.png"
const ICON_BASE_PATH = "res://assets/tileset/"
const CLAN_FRAME_TEXTURE_SIZE = 64
const CLAN_FRAME_CORNER_RADIUS = 12
const CLAN_FRAME_SIZE_RATIO = 0.92
const ICON_SIZE_RATIO = 0.76
const CLAN_FRAME_ALPHA = 0.48

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var grid_size: int
var padding_tiles: int
var entity_sprites: Dictionary
var _texture_cache: Dictionary
var _clan_frame_texture: Texture2D = null

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func setup(p_game_map: GameMap, p_grid_size: int, p_padding_tiles: int) -> void:
	clear()
	game_map = p_game_map
	grid_size = p_grid_size
	padding_tiles = p_padding_tiles
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	update_icons()


func clear() -> void:
	if game_map and game_map.turn_manager and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	game_map = null
	grid_size = 0
	padding_tiles = 0
	for sprite in entity_sprites.values():
		sprite.queue_free()

	entity_sprites.clear()
	_texture_cache.clear()


func _on_turn_ended(_turn_number: int) -> void:
	update_icons()


func _get_clan_color(entity_owner: EntityOwner) -> Color:
	var color := Color(1, 1, 1, CLAN_FRAME_ALPHA)
	if entity_owner and entity_owner.clan:
		color = entity_owner.clan.color
	color.a = CLAN_FRAME_ALPHA
	return color


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
			(padding_tiles + icon_position.x + 0.5) * grid_size,
			(padding_tiles + icon_position.y + 0.5) * grid_size
		)

		var holder: Node2D
		var frame_sprite: Sprite2D
		var icon_sprite: Sprite2D
		if entity_sprites.has(entity_key):
			holder = entity_sprites[entity_key]
			frame_sprite = holder.get_node("ClanFrame") as Sprite2D
			icon_sprite = holder.get_node("Icon") as Sprite2D
		else:
			holder = Node2D.new()
			holder.position = Vector2.ZERO

			frame_sprite = Sprite2D.new()
			frame_sprite.name = "ClanFrame"
			holder.add_child(frame_sprite)

			icon_sprite = Sprite2D.new()
			icon_sprite.name = "Icon"
			holder.add_child(icon_sprite)

			add_child(holder)
			entity_sprites[entity_key] = holder

		var texture: Texture2D = _load_icon_texture_for_entity(map_entity)
		if texture:
			var visual_profile: Dictionary = _get_visual_profile(map_entity)
			var frame_ratio: float = float(visual_profile.get("frame_ratio", CLAN_FRAME_SIZE_RATIO))
			var icon_ratio: float = float(visual_profile.get("icon_ratio", ICON_SIZE_RATIO))

			frame_sprite.texture = _get_clan_frame_texture()
			frame_sprite.modulate = _get_clan_color(map_entity.owner)

			icon_sprite.texture = texture
			icon_sprite.modulate = Color.WHITE

			var frame_size: float = grid_size * frame_ratio
			var icon_size: float = grid_size * icon_ratio
			frame_sprite.scale = Vector2.ONE * (frame_size / CLAN_FRAME_TEXTURE_SIZE)
			icon_sprite.scale = Vector2(icon_size / texture.get_size().x, icon_size / texture.get_size().y)

			holder.position = center


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
		push_error("Icon path '%s' does not exist. Using default icon." % icon_path)
		icon_path = DEFAULT_ICON_PATH

	if not _texture_cache.has(icon_path):
		_texture_cache[icon_path] = load(icon_path)

	return _texture_cache[icon_path]


func _get_clan_frame_texture() -> Texture2D:
	if _clan_frame_texture:
		return _clan_frame_texture

	var image := Image.create(CLAN_FRAME_TEXTURE_SIZE, CLAN_FRAME_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))

	var max_index: int = CLAN_FRAME_TEXTURE_SIZE - 1
	for x in range(CLAN_FRAME_TEXTURE_SIZE):
		for y in range(CLAN_FRAME_TEXTURE_SIZE):
			if _is_inside_rounded_square(x, y, max_index):
				image.set_pixel(x, y, Color.WHITE)

	_clan_frame_texture = ImageTexture.create_from_image(image)
	return _clan_frame_texture


func _is_inside_rounded_square(x: int, y: int, max_index: int) -> bool:
	var radius: int = CLAN_FRAME_CORNER_RADIUS

	if x >= radius and x <= max_index - radius:
		return true
	if y >= radius and y <= max_index - radius:
		return true

	var corner_center := Vector2(radius, radius)
	if x > max_index - radius:
		corner_center.x = max_index - radius
	if y > max_index - radius:
		corner_center.y = max_index - radius

	return Vector2(x, y).distance_to(corner_center) <= radius


func _get_visual_profile(map_entity: MapEntity) -> Dictionary:
	var profile := {
		"frame_ratio": CLAN_FRAME_SIZE_RATIO,
		"icon_ratio": ICON_SIZE_RATIO,
	}

	if not is_instance_of(map_entity, MapMek):
		return profile

	var map_mek: MapMek = map_entity
	if not map_mek.combatant or not map_mek.combatant.template:
		return profile

	match map_mek.combatant.template.size:
		Enums.EntitySize.LIGHT:
			profile["frame_ratio"] = 0.78
			profile["icon_ratio"] = 0.60
		Enums.EntitySize.MEDIUM:
			profile["frame_ratio"] = 0.90
			profile["icon_ratio"] = 0.72
		Enums.EntitySize.HEAVY:
			profile["frame_ratio"] = 1.10
			profile["icon_ratio"] = 0.90
		Enums.EntitySize.COLOSSAL:
			profile["frame_ratio"] = 1.32
			profile["icon_ratio"] = 1.08

	return profile
