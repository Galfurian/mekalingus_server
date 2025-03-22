extends Node2D

var game_map: GameMap
var grid_size: int
var sector_size: int

# Dictionary to store Mek sprites { mek_uuid: Sprite2D }
var mek_sprites: Dictionary

func setup(p_game_map: GameMap, p_grid_size: int = 50, p_sector_size: int = 10):
	game_map    = p_game_map
	grid_size   = p_grid_size
	sector_size = p_sector_size
	if not game_map.on_round_end.is_connected(_on_round_end):
		game_map.on_round_end.connect(_on_round_end)
	update_meks()

func clear() -> void:
	game_map.on_round_end.disconnect(_on_round_end)
	game_map = null
	grid_size = 50
	for sprite in mek_sprites.values():
		sprite.queue_free()
	mek_sprites.clear()

func _on_round_end():
	update_meks()

func update_meks():
	"""Creates and updates Mek sprites based on game state."""
	if not game_map:
		return
	
	var sprite_texture = load("res://assets/tileset/meks/mek.png")
	var sprite_size = sprite_texture.get_size()
	
	# Keep track of Meks that should remain
	var active_meks = game_map.npc_units.keys()
	
	# Remove Meks that no longer exist
	for mek_uuid in mek_sprites.keys():
		if mek_uuid not in active_meks:
			mek_sprites[mek_uuid].queue_free()
			mek_sprites.erase(mek_uuid)

	# Update existing Mek positions or create new sprites
	for mek_uuid in active_meks:
		var map_entity: MapEntity = game_map.npc_units[mek_uuid]
		var mek_position: Vector2i = map_entity.position

		# Apply border offset
		var center = Vector2(
			(sector_size + mek_position.x + 0.5) * grid_size,
			(sector_size + mek_position.y + 0.5) * grid_size
		)
		
		var mek_sprite: Sprite2D
		if mek_uuid in mek_sprites:
			mek_sprite = mek_sprites[mek_uuid]
		else:
			# Create new sprite
			mek_sprite = Sprite2D.new()
			mek_sprite.texture = sprite_texture
			mek_sprites[mek_uuid] = mek_sprite
			add_child(mek_sprite)
		# Update position.
		mek_sprites[mek_uuid].position = center
		mek_sprites[mek_uuid].scale = Vector2(grid_size / sprite_size.x, grid_size / sprite_size.y)
