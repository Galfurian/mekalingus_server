class_name TerrainSmoother
extends RefCounted

## Applies local filter smoothing passes to a 2D height map array.

enum SmoothType {
	MEAN,
	MEDIAN,
	GAUSSIAN,
}


static func smooth(
	height_map: Array,
	map_width: int,
	map_height: int,
	type: int = SmoothType.MEAN,
	radius: int = 1,
	iterations: int = 1,
	blend: float = 1.0
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
		for y in range(map_height):
			new_map.append([])
			for x in range(map_width):
				var values := []

				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height:
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

		for y in range(map_height):
			for x in range(map_width):
				height_map[y][x] = int(round(new_map[y][x]))
