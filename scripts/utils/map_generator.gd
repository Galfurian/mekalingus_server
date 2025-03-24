class_name MapGenerator

extends Node

var width: int
var height: int
var height_map: Array
var noise = FastNoiseLite.new()


func _init(p_width: int, p_height: int):
	width = p_width
	height = p_height
	height_map = []
	_initialize_maps()


func _initialize_maps():
	height_map.clear()
	for y in range(height):
		height_map.append([])
		for x in range(width):
			height_map[y].append(0)


func generate(biome: String = "default") -> Array:
	_initialize_maps()
	biome = biome.to_lower()

	var height_levels = get_height_levels_for_biome(biome)

	match biome:
		"archipelago":
			_generate_islands()
			_apply_noise(5.0)
		"volcanic":
			_generate_volcano_core()
			_apply_noise(10.0)
		"grassland":
			_generate_mountains()
			_apply_noise(22.5)
			_flatten_grassland_terrain(2)
		"mountain":
			_generate_mountains()
			_apply_noise(12.0)
		_:
			_generate_mountains()
			_apply_noise(7.5)

	_normalize_heights()
	return _flatten_to_height_levels(height_levels)


# --- Biome-specific generation functions ---


func _generate_islands():
	for i in range(5):
		var cx = randi() % width
		var cy = randi() % height
		var radius = int(min(width, height) * 0.1)
		for y in range(cy - radius, cy + radius):
			for x in range(cx - radius, cx + radius):
				if x >= 0 and x < width and y >= 0 and y < height:
					var dist = Vector2(cx, cy).distance_to(Vector2(x, y))
					if dist < radius:
						height_map[y][x] += int((radius - dist) * 1.5)


func _generate_volcano_core():
	var cx = width / 2.0
	var cy = height / 2.0
	var peak_radius = int(min(width, height) * 0.15)
	for y in range(cy - peak_radius, cy + peak_radius):
		for x in range(cx - peak_radius, cx + peak_radius):
			if x >= 0 and x < width and y >= 0 and y < height:
				var dist = Vector2(cx, cy).distance_to(Vector2(x, y))
				if dist < peak_radius:
					height_map[y][x] += int(pow(peak_radius - dist, 1.5))


func _generate_mountains():
	var num_mountains = max(5, int((width * height) * 0.05))
	var radius_min = max(3, int(min(width, height) * 0.05))
	var radius_max = max(6, int(min(width, height) * 0.10))
	for i in range(num_mountains):
		var radius = randi() % (radius_max - radius_min + 1) + radius_min
		var x_center = randi() % (width + radius) - (radius / 2)
		var y_center = randi() % (height + radius) - (radius / 2)
		var x_min = max(x_center - radius - 1, 0)
		var x_max = min(x_center + radius + 1, width - 1)
		var y_min = max(y_center - radius - 1, 0)
		var y_max = min(y_center + radius + 1, height - 1)
		var square_radius = radius * radius
		for x in range(x_min, x_max + 1):
			for y in range(y_min, y_max + 1):
				var distance = pow(x_center - x, 2) + pow(y_center - y, 2)
				var cell_height = ceil(square_radius - distance)
				if cell_height > 0:
					height_map[y][x] += cell_height


func _flatten_grassland_terrain(strength: int = 2):
	"""
	Softens the terrain by averaging nearby values.
	Strength determines how many times the filter is applied.
	"""
	for _i in range(strength):
		var new_map := []
		for y in range(height):
			new_map.append([])
			for x in range(width):
				var total = 0
				var count = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < width and ny >= 0 and ny < height:
							total += height_map[ny][nx]
							count += 1
				new_map[y].append(total / count)
		for y in range(height):
			for x in range(width):
				height_map[y][x] = int(new_map[y][x])


# --- Shared generation helpers ---


func _apply_noise(amplitude: float):
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	for x in range(width):
		for y in range(height):
			var noise_value = noise.get_noise_2d(x, y) * amplitude
			height_map[y][x] = max(0, height_map[y][x] + int(noise_value))


func _normalize_heights():
	var min_height = INF
	var max_height = -INF
	for y in range(height):
		for x in range(width):
			min_height = min(min_height, height_map[y][x])
			max_height = max(max_height, height_map[y][x])
	if max_height - min_height < 5:
		max_height = min_height + 5
	for y in range(height):
		for x in range(width):
			height_map[y][x] = int(remap(height_map[y][x], min_height, max_height, 1, 9))


func _flatten_to_height_levels(height_levels: Array) -> Array:
	var terrain_map = []
	for y in range(height):
		terrain_map.append([])
		for x in range(width):
			terrain_map[y].append(_get_closest_height(height_levels, height_map[y][x]))
	return terrain_map


func _get_closest_height(height_levels: Array, value: int) -> int:
	var closest = height_levels[0]
	var min_diff = INF
	for level in height_levels:
		var diff = abs(level - value)
		if diff < min_diff or (diff == min_diff and level > closest):
			closest = level
			min_diff = diff
	return closest


static func get_height_levels_for_biome(biome: String) -> Array:
	match biome.to_lower():
		"archipelago":
			return [1, 2, 3, 4, 5]
		"volcanic":
			return [1, 3, 5, 7, 9]
		"grassland":
			return [1, 3, 5, 7, 9]
		"mountain":
			return [1, 3, 5, 7, 9]
		_:
			return [1, 3, 5, 7, 9]


static func get_movement_cost_for_tile(tile_height: int, biome: String) -> int:
	match biome.to_lower():
		"archipelago":
			return {1: -1, 3: 3, 5: 1, 7: 2, 9: 3}.get(tile_height, -1)
		"volcanic":
			return {1: -1, 3: 3, 5: 2, 7: 3, 9: 4}.get(tile_height, -1)
		"grassland":
			return {1: -1, 3: 2, 5: 1, 7: 2, 9: 3}.get(tile_height, -1)
		"mountain":
			return {1: -1, 3: 2, 5: 1, 7: 2, 9: 4}.get(tile_height, -1)
		_:
			return -1  # Default: impassable


static func get_color_for_tile(tile_height: int, biome: String) -> Color:
	match biome.to_lower():
		"archipelago":
			return (
				{
					1: Color8(0, 102, 170),  # Deep ocean
					3: Color8(51, 187, 170),  # Shallow water
					5: Color8(255, 221, 136),  # Beach
					7: Color8(34, 136, 34),  # Jungle
					9: Color8(85, 68, 51)  # Highlands
				}
				. get(tile_height, Color.BLACK)
			)
		"volcanic":
			return (
				{
					1: Color8(51, 0, 0),  # Lava lake
					3: Color8(85, 34, 0),  # Cooled lava
					5: Color8(136, 136, 136),  # Ash plain
					7: Color8(68, 68, 68),  # Rocky field
					9: Color8(30, 30, 30)  # Peak
				}
				. get(tile_height, Color.BLACK)
			)
		"grassland":
			return (
				{
					1: Color8(34, 68, 136),  # River/lake
					3: Color8(85, 119, 85),  # Swamp
					5: Color8(136, 204, 68),  # Grass
					7: Color8(102, 153, 51),  # Hill
					9: Color8(51, 102, 34)  # Ridge
				}
				. get(tile_height, Color.BLACK)
			)
		"mountain":
			return (
				{
					1: Color8(26, 51, 102),  # Lake
					3: Color8(119, 153, 119),  # Meadow
					5: Color8(204, 204, 170),  # Flat highland
					7: Color8(170, 170, 170),  # Scree
					9: Color8(238, 238, 238)  # Snowy peak
				}
				. get(tile_height, Color.BLACK)
			)
		_:
			return Color.GRAY
