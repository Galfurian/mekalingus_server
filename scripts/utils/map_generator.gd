# MapGenerator.gd
# Generates a height map for a given biome.
class_name MapGenerator
extends Node

# The width of the map.
var width: int
# The height of the map.
var height: int
# The current biome.
var biome: Biome

# The height map.
var height_map: Array
# The noise generator.
var noise: FastNoiseLite


func _init(p_width: int, p_height: int, p_biome: Biome):
	width = p_width
	height = p_height
	biome = p_biome
	height_map = []
	noise = FastNoiseLite.new()
	_initialize_maps()


func _initialize_maps():
	height_map.clear()
	for y in range(height):
		height_map.append([])
		for x in range(width):
			height_map[y].append(0)


func generate(p_biome: Biome) -> Array:
	_initialize_maps()
	biome = p_biome

	match biome.biome_name.to_lower():
		"archipelago":
			_generate_mountains(0.1, 0.05, 0.15)
			_generate_islands()
			_apply_noise(5.0)
		"volcanic":
			_generate_mountains(0.6, 0.05, 0.10)
			_generate_volcano_core(1.6, 0.2, 60.0, -20.0, 2.0)
		"grassland":
			_generate_mountains(0.05, 0.05, 0.10)
			_apply_noise(22.5)
			_flatten_grassland_terrain(2)
		"mountain":
			_generate_mountains(0.1, 0.05, 0.15)
			_apply_noise(12.0)
		_:
			_generate_mountains()
			_apply_noise(7.5)

	_normalize_heights()
	return _flatten_to_biome_levels()


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


func _generate_volcano_core(
	peak_radius_control: float = 0.15,
	inner_crater_ratio: float = 0.3,
	peak_height: float = 50.0,
	crater_depth: float = -20.0,
	slope_exponent: float = 1.5
):
	# Random center near the middle of the map
	var x_min = int(width * 0.3)
	var x_max = int(width * 0.7)
	var y_min = int(height * 0.3)
	var y_max = int(height * 0.7)
	var core_x = x_min + randi() % (x_max - x_min + 1)
	var core_y = y_min + randi() % (y_max - y_min + 1)

	var peak_radius = max(5, int(min(width, height) * peak_radius_control))
	var crater_radius = int(peak_radius * inner_crater_ratio)

	for y in range(core_y - peak_radius, core_y + peak_radius):
		for x in range(core_x - peak_radius, core_x + peak_radius):
			if x < 0 or x >= width or y < 0 or y >= height:
				continue

			var dist = Vector2(core_x, core_y).distance_to(Vector2(x, y))
			if dist >= peak_radius:
				continue

			var height_value := 0.0

			if dist < crater_radius:
				# Inner crater: deeper near center
				height_value = crater_depth * (1.0 - dist / crater_radius)
			else:
				# Outer slope: tapering up to peak
				var slope_dist = dist - crater_radius
				var slope_range = peak_radius - crater_radius
				var normalized_slope = slope_dist / slope_range
				height_value = peak_height * pow(1.0 - normalized_slope, slope_exponent)

			height_map[y][x] += int(height_value)


func _generate_mountains(
	num_mountains_control: float = 0.05,
	min_radius_control: float = 0.05,
	max_radius_control: float = 0.10,
):
	var num_mountains = max(5, int((width * height) * num_mountains_control))
	var radius_min = max(3, int(min(width, height) * min_radius_control))
	var radius_max = max(6, int(min(width, height) * max_radius_control))
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


func _flatten_to_biome_levels() -> Array:
	var terrain_map := []
	for y in range(height):
		terrain_map.append([])
		for x in range(width):
			terrain_map[y].append(_get_closest_level_index(height_map[y][x]))
	return terrain_map


func _get_closest_level_index(value: int) -> int:
	var closest_index = 0
	var min_diff = INF
	for i in biome.biome_levels.size():
		var level = biome.get_level(i)
		if level == null:
			continue
		var diff = abs(level.height - value)
		if diff < min_diff or (diff == min_diff and i > closest_index):
			closest_index = i
			min_diff = diff
	return closest_index
