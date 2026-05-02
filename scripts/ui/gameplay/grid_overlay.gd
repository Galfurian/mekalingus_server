extends Node2D

# --- SUN SETTINGS ---
const MIN_SUN_THICKNESS: float = 1.0
const MAX_SUN_THICKNESS: float = 6.0
const MIN_SUN_ALPHA: float = 0.15
const MAX_SUN_ALPHA: float = 0.5
const SUN_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0)  # Pure black

# --- MOON SETTINGS ---
const MIN_MOON_THICKNESS: float = 1.0
const MAX_MOON_THICKNESS: float = 4.0  # Moon shadows might be slightly shorter
const MIN_MOON_ALPHA: float = 0.05  # Much softer at midnight
const MAX_MOON_ALPHA: float = 0.25  # Softer at moonrise/moonset
const MOON_SHADOW_COLOR: Color = Color(0.05, 0.05, 0.15)  # Deep blue/purple tint

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var grid_size: int
var padding_tiles: int

# Actual overlay variables.
var overlay_texture: ImageTexture


func setup(p_game_map: GameMap, p_grid_size: int, p_padding_tiles: int):
	game_map = p_game_map
	grid_size = p_grid_size
	padding_tiles = p_padding_tiles
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	generate_overlay_texture()
	queue_redraw()


func clear() -> void:
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	game_map = null
	grid_size = 0
	padding_tiles = 0
	queue_redraw()


func get_draw_offset() -> Vector2:
	# Offset by the full outer padding in each direction.
	return Vector2(padding_tiles * grid_size, padding_tiles * grid_size)


func _ready() -> void:
	# Generate it once at the start!
	generate_overlay_texture()


func _draw() -> void:
	if not game_map:
		return
	if overlay_texture:
		# Draw the shadows ON TOP of the posterized base map
		var offset: Vector2 = get_draw_offset()
		draw_texture(overlay_texture, offset)


func _on_turn_ended(_turn_number: int):
	# Whenever a turn ends, we need to recalculate the shadows because the time of day might have
	# changed.
	generate_overlay_texture()


func generate_overlay_texture() -> void:
	if not game_map or not game_map.turn_manager:
		return

	var img_width: int = game_map.map_width * grid_size
	var img_height: int = game_map.map_height * grid_size
	var overlay_image: Image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	overlay_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var time: float = game_map.turn_manager.get_time_of_day()

	# 1. DETERMINE PHASE (DAY OR NIGHT)
	var is_daytime: bool = time >= 0.25 and time < 0.75

	var celestial_progress: float  # 0.0 (rise) to 1.0 (set)
	var zenith_distance: float  # 0.0 (highest point) to 1.0 (horizon)
	var current_thickness: float
	var shadow_color: Color

	if is_daytime:
		# --- SUN MATH ---
		# Map 0.25 -> 0.75 to 0.0 -> 1.0
		celestial_progress = (time - 0.25) / 0.5
		zenith_distance = abs(celestial_progress - 0.5) * 2.0

		current_thickness = lerp(MIN_SUN_THICKNESS, MAX_SUN_THICKNESS, zenith_distance)
		var current_alpha: float = lerp(MIN_SUN_ALPHA, MAX_SUN_ALPHA, zenith_distance)

		shadow_color = SUN_SHADOW_COLOR
		shadow_color.a = current_alpha
	else:
		# --- MOON MATH ---
		# The night wraps around 0.0.
		# From 0.75 to 1.0 (first half of night) AND 0.0 to 0.25 (second half)
		if time >= 0.75:
			celestial_progress = (time - 0.75) / 0.5  # Maps 0.75 -> 1.0 to 0.0 -> 0.5
		else:
			celestial_progress = (time + 0.25) / 0.5  # Maps 0.0 -> 0.25 to 0.5 -> 1.0

		zenith_distance = abs(celestial_progress - 0.5) * 2.0

		current_thickness = lerp(MIN_MOON_THICKNESS, MAX_MOON_THICKNESS, zenith_distance)
		var current_alpha: float = lerp(MIN_MOON_ALPHA, MAX_MOON_ALPHA, zenith_distance)

		shadow_color = MOON_SHADOW_COLOR
		shadow_color.a = current_alpha

	# 2. SHADOW DIRECTION (Both Sun and Moon sweep Left to Right)
	var shadow_dir_x: float = lerp(1.0, -1.0, celestial_progress)
	
	# Create a bounding box of the entire image to prevent out-of-bounds drawing crashes
	var img_rect: Rect2i = Rect2i(0, 0, img_width, img_height)

	# 3. BAKE THE SHADOWS
	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			var current_height: int = game_map.get_tile_height(x, y)

			if current_height <= 0:
				continue

			var x_pos: int = x * grid_size
			var y_pos: int = y * grid_size

			# --- SOUTH SHADOW (Projected DOWN onto the lower neighbor) ---
			if y < game_map.map_height - 1:
				var height_south: int = game_map.get_tile_height(x, y + 1)
				if height_south < current_height:
					var drop_size: int = current_height - height_south
					var thickness: int = int(current_thickness * drop_size)

					# Start exactly at the bottom edge of THIS tile, going DOWN
					var rect: Rect2i = Rect2i(x_pos, y_pos + grid_size, grid_size, thickness)

					# Clip the rect so we don't draw outside the image bounds
					rect = rect.intersection(img_rect)
					if rect.has_area():
						overlay_image.fill_rect(rect, shadow_color)

			# --- EAST SHADOW (Projected RIGHT onto the lower neighbor) ---
			if shadow_dir_x > 0.1 and x < game_map.map_width - 1:
				var height_east: int = game_map.get_tile_height(x + 1, y)
				if height_east < current_height:
					var drop_size: int = current_height - height_east
					var thickness: int = int(current_thickness * drop_size * abs(shadow_dir_x))

					# Start exactly at the right edge of THIS tile, going RIGHT
					var rect: Rect2i = Rect2i(x_pos + grid_size, y_pos, thickness, grid_size)

					rect = rect.intersection(img_rect)
					if rect.has_area():
						overlay_image.fill_rect(rect, shadow_color)

			# --- WEST SHADOW (Projected LEFT onto the lower neighbor) ---
			elif shadow_dir_x < -0.1 and x > 0:
				var height_west: int = game_map.get_tile_height(x - 1, y)
				if height_west < current_height:
					var drop_size: int = current_height - height_west
					var thickness: int = int(current_thickness * drop_size * abs(shadow_dir_x))

					# Start outside THIS tile to the left, ending exactly at its left edge
					var rect: Rect2i = Rect2i(x_pos - thickness, y_pos, thickness, grid_size)

					rect = rect.intersection(img_rect)
					if rect.has_area():
						overlay_image.fill_rect(rect, shadow_color)

	overlay_texture = ImageTexture.create_from_image(overlay_image)
	queue_redraw()
