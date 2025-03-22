extends Node

class_name MapGenerator

var width: int
var height: int
var height_map: Array
var noise = FastNoiseLite.new()

# Constructor
func _init(p_width: int, p_height: int):
	width = p_width
	height = p_height
	_initialize_maps()

func _initialize_maps():
	"""Initialize empty maps."""
	height_map.clear()
	for y in range(height):
		height_map.append([])
		for x in range(width):
			height_map[y].append(0)

func generate(height_levels: Array = [10, 30, 60, 100]):
	"""Main function to generate the map with height level normalization."""
	_initialize_maps()
	_generate_mountains()
	_apply_noise(15.0)
	_normalize_heights()
	_generate_rivers(4)
	
	# Normalize height values to match the provided height levels
	return _flatten_to_height_levels(height_levels)

# ==========================
#    MAP GENERATION LOGIC
# ==========================

func _generate_mountains():
	"""Creates mountains using a radius-based approach."""
	var num_mountains = max(5, int((width * height) * 0.05))
	var radius_min = max(3, int(min(width, height) * 0.05))
	var radius_max = max(6, int(min(width, height) * 0.10))
	for i in range(num_mountains):
		var radius = randi() % (radius_max - radius_min + 1) + radius_min
		var xCenter = randi() % (width + radius) - (radius/2)
		var yCenter = randi() % (height + radius) - (radius/2)
		var xMin = max(xCenter - radius - 1, 0)
		var xMax = min(xCenter + radius + 1, width - 1)
		var yMin = max(yCenter - radius - 1, 0)
		var yMax = min(yCenter + radius + 1, height - 1)
		var squareRadius = radius * radius
		for x in range(xMin, xMax + 1):
			for y in range(yMin, yMax + 1):
				var distance = pow(xCenter - x, 2) + pow(yCenter - y, 2)
				var cell_height = ceil(squareRadius - distance)
				if cell_height > 0:
					height_map[y][x] += cell_height

func _apply_noise(amplitude: float):
	"""Applies FastNoiseLite to modify terrain heights."""
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX  # Simplex noise for natural terrain
	noise.frequency = 0.02  # Adjust frequency to match map size
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM  # Fractal Brownian Motion (FBM)
	noise.fractal_octaves = 5  # Number of layers
	noise.fractal_gain = 0.5  # Controls noise contrast
	noise.fractal_lacunarity = 2.0  # Controls detail level

	for x in range(width):
		for y in range(height):
			var noise_value = noise.get_noise_2d(x, y) * amplitude
			height_map[y][x] = max(0, height_map[y][x] + int(noise_value))

func _normalize_heights():
	"""Normalize the height values to fit the provided height levels properly."""
	var min_height = INF
	var max_height = -INF

	for y in range(height):
		for x in range(width):
			min_height = min(min_height, height_map[y][x])
			max_height = max(max_height, height_map[y][x])

	# Prevent division by zero
	if max_height - min_height < 5:
		max_height = min_height + 5

	for y in range(height):
		for x in range(width):
			# Normalize directly into the range [1, 9] instead of [0, 100]
			height_map[y][x] = int(remap(height_map[y][x], min_height, max_height, 1, 9))

func _generate_rivers(num_rivers: int):
	"""Generates rivers that flow downhill."""
	var river_starts = []
	
	for y in range(height):
		for x in range(width):
			if height_map[y][x] > 70:  # Rivers start from high elevations
				river_starts.append(Vector2(x, y))

	river_starts.shuffle()

	for i in range(min(num_rivers, len(river_starts))):
		var pos = river_starts[i]
		var river_path = []

		while true:
			var x = int(pos.x)
			var y = int(pos.y)

			river_path.append(pos)
			height_map[y][x] = 0  # Set to "water" level

			var lowest_neighbor = null
			var lowest_value = height_map[y][x]

			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var nx = x + dx
					var ny = y + dy

					if nx >= 0 and nx < width and ny >= 0 and ny < height:
						if height_map[ny][nx] < lowest_value:
							lowest_value = height_map[ny][nx]
							lowest_neighbor = Vector2(nx, ny)

			if lowest_neighbor == null:
				break  # End river

			pos = lowest_neighbor

# ==========================
#    NORMALIZATION
# ==========================

func _flatten_to_height_levels(height_levels: Array) -> Array:
	"""Convert generated height values to the nearest defined height level, ensuring mid-values are well-represented."""
	var terrain_map = []
	for y in range(height):
		terrain_map.append([])
		for x in range(width):
			terrain_map[y].append(_get_balanced_height_level(height_levels, height_map[y][x]))
	return terrain_map

func _get_balanced_height_level(height_levels: Array, value: int) -> int:
	"""Finds the closest value from height_levels, ensuring better mid-range distribution."""
	var closest = height_levels[0]
	var min_diff = INF

	for level in height_levels:
		var diff = abs(level - value)
		if diff < min_diff or (diff == min_diff and level > closest):
			closest = level
			min_diff = diff

	return closest

# ==========================
#    UTILITY FUNCTIONS
# ==========================

func get_height(x: int, y: int) -> int:
	"""Get the height value at a given coordinate."""
	if x >= 0 and x < width and y >= 0 and y < height:
		return height_map[y][x]
	return -1  # Invalid coordinate

func set_height(x: int, y: int, value: int):
	"""Set the height value at a given coordinate."""
	if x >= 0 and x < width and y >= 0 and y < height:
		height_map[y][x] = clamp(value, 0, 100)

func print_map():
	"""Prints the height map for debugging."""
	for row in height_map:
		print(row)
