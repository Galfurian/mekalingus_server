class_name HeightNormalizer
extends RefCounted

## Normalizes a raw height map into biome height ranges and maps it to biome level indices.


static func normalize(
	height_map: Array,
	map_width: int,
	map_height: int,
	biome_min: float,
	biome_max: float,
	round_result: bool = true,
	min_range_threshold: float = 1.0
) -> void:
	"""
	Remaps all values in height_map from their current min/max range into
	[biome_min, biome_max]. Modifies height_map in-place.
	"""
	var map_min := INF
	var map_max := -INF
	for y in range(map_height):
		for x in range(map_width):
			var h = height_map[y][x]
			if h < map_min:
				map_min = h
			if h > map_max:
				map_max = h

	if (map_max - map_min) < min_range_threshold:
		map_max = map_min + min_range_threshold

	for y in range(map_height):
		for x in range(map_width):
			var h := float(height_map[y][x])
			var t: float = clamp((h - map_min) / (map_max - map_min), 0.0, 1.0)
			var final: float = lerp(biome_min, biome_max, t)
			height_map[y][x] = round(final) if round_result else final


static func flatten_to_biome_levels(
	height_map: Array, map_width: int, map_height: int, biome: Biome
) -> Array:
	"""
	Converts the normalized height map to a terrain map of biome level indices.
	"""
	var terrain_map := []
	for y in range(map_height):
		terrain_map.append([])
		for x in range(map_width):
			terrain_map[y].append(_get_closest_level_index(height_map[y][x], biome))
	return terrain_map


static func _get_closest_level_index(value: int, biome: Biome) -> int:
	"""
	Returns the index of the closest biome level to the given value.
	"""
	var closest_index := 0
	var min_diff := INF
	for i in biome.biome_levels.size():
		var level = biome.get_level(i)
		if level == null:
			continue
		var diff: float = abs(level.height - value)
		if diff < min_diff or (diff == min_diff and i > closest_index):
			closest_index = i
			min_diff = diff
	return closest_index
