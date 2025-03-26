# This script loads biome data from a JSON file and provides methods to access it.
class_name Biome

extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

# The name of the biome.
var biome_name: String
# The levels of the biome.
var biome_levels: Array[BiomeLevel]
# The minimum height of the biome.
var min_height: int
# The maximum height of the biome.
var max_height: int

# =============================================================================
# GENERAL
# =============================================================================


func _init(data: Dictionary = {}):
	if data:
		from_dict(data)


func has_level(index: int) -> bool:
	"""Check if a level exists."""
	return index >= 0 and index < biome_levels.size()


func get_level(index: int) -> BiomeLevel:
	"""Returns the data for a specific level of the biome."""
	return biome_levels[index] if has_level(index) else null


func get_movement_cost(index: int) -> int:
	"""Returns the movement cost for a specific level of the biome."""
	var level = get_level(index)
	if level:
		return level.movement_cost
	return -1


func get_color(index: int) -> Color:
	"""Returns the color for a specific level of the biome."""
	var level = get_level(index)
	if level:
		return level.color
	return Color.GRAY


func get_height(index: int) -> int:
	"""Returns the height for a specific level of the biome."""
	var level = get_level(index)
	if level:
		return level.height
	return -1


# =============================================================================
# SERIALIZATION
# =============================================================================


func _to_string() -> String:
	"""Returns the data as a string."""
	return "Biome: " + biome_name


func from_dict(data: Dictionary):
	"""Loads data from a dictionary."""
	biome_name = data["name"]
	biome_levels.clear()
	for level_data in data["levels"]:
		biome_levels.append(BiomeLevel.new(level_data))
	# Update the height range.
	min_height = biome_levels[0].height
	max_height = biome_levels[biome_levels.size() - 1].height


func to_dict() -> Dictionary:
	"""Returns the data as a dictionary."""
	var levels = []
	for level in biome_levels:
		levels.append(level.to_dict())
	return {"name": biome_name, "levels": levels}
