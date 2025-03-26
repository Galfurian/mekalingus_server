# MapGenerator.gd
# Generates a height map for a given biome.
class_name MapGenerator
extends Node

enum SmoothType {
	MEAN,
	MEDIAN,
	GAUSSIAN,
}

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
			_generate_islands(12, 0.05, 0.40, 0.4, 2.0)
			_apply_noise(8.0, 0.05, 5, 0.5, 2.0)
		"volcanic":
			_generate_volcano_core(0.75, 0.3, 1.0, 0.2, 2.0)
			_generate_mountains(0.05, 0.05, 0.10, 0.2, 0.4)
			# Apply noise to the terrain.
			_apply_noise(2.0, 0.05, 5, 0.5, 2.0)
			# Soften with a mild average, applied once
			_smooth_terrain(SmoothType.MEAN, 1, 1, 1.0)
		"grassland":
			_generate_mountains(0.05, 0.05, 0.10, 0.2, 0.4)
			_apply_noise(2.0, 0.05, 5, 0.5, 2.0)
			# Soften with a mild average, applied once
			# _smooth_terrain(SmoothType.MEAN, 1, 1, 1.0)
			# Soften aggressively with median filter (good for removing sharp edges)
			_smooth_terrain(SmoothType.MEDIAN, 2, 2)
			# Light Gaussian-like smoothing (mean + low blend)
			# _smooth_terrain(SmoothType.MEAN, 2, 3, 0.3)
		"mountain":
			_generate_mountains(0.15, 0.05, 0.15, 0.6, 0.4)
			_apply_noise(2.0, 0.05, 5, 0.5, 2.0)
			_generate_mountain_peak(0.60, 0.80, 1.0, 2.0)
			_smooth_terrain(SmoothType.MEAN, 1, 1, 1.0)
			# _smooth_terrain(SmoothType.MEDIAN, 2, 2)
			# _smooth_terrain(SmoothType.MEAN, 2, 3, 0.3)
		_:
			_generate_mountains()
			_apply_noise(7.5)

	_normalize_height_map()

	return _flatten_to_biome_levels()


# --- Biome-specific generation functions ---


func _generate_islands(
	num_islands: int = 5,
	min_radius_ratio: float = 0.05,
	max_radius_ratio: float = 0.15,
	peak_height_ratio: float = 0.5,
	slope_exponent: float = 2.0
):
	var biome_height_range = biome.max_height - biome.min_height

	for i in range(num_islands):
		var radius = clamped_range(
			int(min(width, height) * min_radius_ratio), int(min(width, height) * max_radius_ratio)
		)

		var center = get_random_point_in_bounds(0.0, 1.0, 0.0, 1.0)
		var cx = int(center.x)
		var cy = int(center.y)

		var x_min = max(cx - radius - 1, 0)
		var x_max = min(cx + radius + 1, width - 1)
		var y_min = max(cy - radius - 1, 0)
		var y_max = min(cy + radius + 1, height - 1)

		var island_peak = peak_height_ratio * biome_height_range

		for y in range(y_min, y_max + 1):
			for x in range(x_min, x_max + 1):
				var dist = Vector2(x, y).distance_to(Vector2(cx, cy))
				if dist >= radius:
					continue

				var t = dist / radius
				var falloff = pow(1.0 - t, slope_exponent)
				var added_height = island_peak * falloff

				height_map[y][x] += int(round(added_height))


func _generate_volcano_core(
	peak_radius_ratio: float = 0.15,  # 0.0 = no peak, 1.0 = whole map
	inner_crater_ratio: float = 0.3,  # 0.0 = no crater, 1.0 = all peak
	peak_height_ratio: float = 1.0,  # 0.0 = no height, 1.0 = max biome height
	crater_depth_ratio: float = 0.5,  # 0.0 = flat crater, 1.0 = max crater depth
	slope_exponent: float = 2.5
):
	peak_radius_ratio = clamp(peak_radius_ratio, 0.0, 1.0)
	inner_crater_ratio = clamp(inner_crater_ratio, 0.0, 1.0)
	peak_height_ratio = clamp(peak_height_ratio, 0.0, 1.0)
	crater_depth_ratio = clamp(crater_depth_ratio, 0.0, 1.0)

	# Scale to real values
	var peak_height = peak_height_ratio * biome.max_height
	var crater_depth = -crater_depth_ratio * biome.max_height
	var peak_radius = int(peak_radius_ratio * min(width, height))
	var crater_radius = int(inner_crater_ratio * peak_radius)

	# Early exit if radius is too small
	if peak_radius <= 0:
		return

	# Random center near the middle of the map.
	var center = get_random_point_in_bounds(0.3, 0.7, 0.3, 0.7)

	for y in range(center.y - peak_radius, center.y + peak_radius):
		for x in range(center.x - peak_radius, center.x + peak_radius):
			if x < 0 or x >= width or y < 0 or y >= height:
				continue

			var dist = Vector2(center.x, center.y).distance_to(Vector2(x, y))
			if dist >= peak_radius:
				continue

			var height_value := 0.0

			if dist < crater_radius:
				var t = dist / crater_radius
				var inner_curve = t * t * (3.0 - 2.0 * t)  # smoothstep
				height_value = crater_depth * (1.0 - inner_curve)
			else:
				var slope_dist = dist - crater_radius
				var slope_range = peak_radius - crater_radius
				var t = slope_dist / slope_range
				var outer_curve = pow(1.0 - t, slope_exponent)
				height_value = peak_height * outer_curve

			height_map[y][x] += int(round(height_value))


func _generate_mountains(
	num_mountains_control: float = 0.05,
	min_radius_control: float = 0.05,
	max_radius_control: float = 0.10,
	min_height_ratio: float = 0.2,
	max_height_ratio: float = 1.0,
	slope_exponent: float = 2.0
):
	var biome_height_range = biome.max_height - biome.min_height

	var num_mountains = max(5, int((width * height) * num_mountains_control))
	var radius_min = max(3, int(min(width, height) * min_radius_control))
	var radius_max = max(6, int(min(width, height) * max_radius_control))

	for i in range(num_mountains):
		var radius = randi() % (radius_max - radius_min + 1) + radius_min

		# Get a random center point within the map bounds.
		var center = get_random_point_in_bounds(0.0, 1.0, 0.0, 1.0)

		var x_min = max(center.x - radius - 1, 0)
		var x_max = min(center.x + radius + 1, width - 1)
		var y_min = max(center.y - radius - 1, 0)
		var y_max = min(center.y + radius + 1, height - 1)

		for x in range(x_min, x_max + 1):
			for y in range(y_min, y_max + 1):
				var dist = Vector2(x, y).distance_to(Vector2(center.x, center.y))
				if dist >= radius:
					continue

				var t = dist / radius
				var height_factor = pow(1.0 - t, slope_exponent)
				var peak_height_ratio = randf_range(min_height_ratio, max_height_ratio)
				var peak_height = peak_height_ratio * biome_height_range
				var added_height = peak_height * height_factor
				height_map[y][x] += int(round(added_height))


func _generate_mountain_peak(
	min_radius_control: float = 0.05,
	max_radius_control: float = 0.10,
	peak_height_ratio: float = 0.5,
	slope_exponent: float = 2.0
) -> void:
	
	var center = get_random_point_in_bounds(0.2, 0.8, 0.2, 0.8)

	var biome_span = biome.max_height - biome.min_height
	var peak_height = peak_height_ratio * biome_span

	var radius_min = max(3, int(min(width, height) * min_radius_control))
	var radius_max = max(6, int(min(width, height) * max_radius_control))

	var radius = randi() % (radius_max - radius_min + 1) + radius_min

	var x_min = max(center.x - radius - 1, 0)
	var x_max = min(center.x + radius + 1, width - 1)
	var y_min = max(center.y - radius - 1, 0)
	var y_max = min(center.y + radius + 1, height - 1)

	for y in range(y_min, y_max + 1):
		for x in range(x_min, x_max + 1):
			var dist = Vector2(x, y).distance_to(center)
			if dist >= radius:
				continue
			var t = dist / radius
			var falloff = pow(1.0 - t, slope_exponent)
			var added_height = peak_height * falloff
			height_map[y][x] += int(round(added_height))


# --- Shared generation helpers ---


func _apply_noise(
	amplitude: float,
	frequency: float = 0.02,
	octaves: int = 5,
	gain: float = 0.5,
	lacunarity: float = 2.0,
	noise_seed: int = randi(),
	noise_type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX,
	fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM
):
	noise.seed = noise_seed
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_type = fractal_type
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain
	noise.fractal_lacunarity = lacunarity
	for x in range(width):
		for y in range(height):
			var noise_value = noise.get_noise_2d(x, y) * amplitude
			height_map[y][x] = max(0, height_map[y][x] + int(noise_value))


func _normalize_height_map(round_result: bool = true, min_range_threshold: float = 1.0) -> void:
	# Compute actual map min/max
	var map_min = INF
	var map_max = -INF
	for y in range(height):
		for x in range(width):
			var h = height_map[y][x]
			if h < map_min:
				map_min = h
			if h > map_max:
				map_max = h

	# Avoid flat terrain issues
	if (map_max - map_min) < min_range_threshold:
		map_max = map_min + min_range_threshold

	for y in range(height):
		for x in range(width):
			var h = float(height_map[y][x])
			# Normalize to [0,1] based on map min/max
			var t = (h - map_min) / (map_max - map_min)
			t = clamp(t, 0.0, 1.0)
			# Remap to biome range
			var final = lerp(biome.min_height, biome.max_height, t)
			height_map[y][x] = round(final) if round_result else final


func _flatten_to_biome_levels() -> Array:
	"""
	Converts the height map to a terrain map using the biome levels.
	"""
	var terrain_map := []
	for y in range(height):
		terrain_map.append([])
		for x in range(width):
			terrain_map[y].append(_get_closest_level_index(height_map[y][x]))
	return terrain_map


func _get_closest_level_index(value: int) -> int:
	"""
	Returns the index of the closest biome level to the given value.
	"""
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


func _smooth_terrain(
	type: int = SmoothType.MEAN, radius: int = 1, iterations: int = 1, blend: float = 1.0
) -> void:
	"""
	Smooths the terrain by applying a local filter.
	type		: The smoothing method: mean, median, etc.
	radius		: How far to sample neighbors (1 = 3x3, 2 = 5x5, etc.)
	iterations	: How many times to apply the smoothing pass.
	blend		: How much to blend the smoothed value with the original [0-1]
	"""
	for _pass in range(iterations):
		var new_map := []
		for y in range(height):
			new_map.append([])
			for x in range(width):
				var values := []

				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < width and ny >= 0 and ny < height:
							values.append(height_map[ny][nx])
				var result = height_map[y][x]
				if values.size() > 0:
					match type:
						SmoothType.MEAN:
							var sum := 0
							for v in values:
								sum += v
							result = float(sum) / values.size()

						SmoothType.MEDIAN:
							values.sort()
							result = values[values.size() / 2.0]
						_:
							pass  # fallback = original value

				var blended = lerp(float(height_map[y][x]), float(result), blend)
				new_map[y].append(blended)

		for y in range(height):
			for x in range(width):
				height_map[y][x] = int(round(new_map[y][x]))


func get_random_point_in_bounds(
	x_ratio_min: float, x_ratio_max: float, y_ratio_min: float, y_ratio_max: float
) -> Vector2:
	"""
	Returns a random point within the given bounds.
	"""

	var x_min = int(width * clamp(x_ratio_min, 0.0, 1.0))
	var x_max = int(width * clamp(x_ratio_max, 0.0, 1.0))
	var y_min = int(height * clamp(y_ratio_min, 0.0, 1.0))
	var y_max = int(height * clamp(y_ratio_max, 0.0, 1.0))
	if x_min > x_max:
		var tmp = x_min
		x_min = x_max
		x_max = tmp
	if y_min > y_max:
		var tmp = y_min
		y_min = y_max
		y_max = tmp
	var x = x_min + randi() % (x_max - x_min + 1)
	var y = y_min + randi() % (y_max - y_min + 1)
	return Vector2(x, y)


func clamped_range(min_val: int, max_val: int) -> int:
	return randi() % (max_val - min_val + 1) + min_val
