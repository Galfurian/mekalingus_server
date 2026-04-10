class_name AITurnContext
extends RefCounted

const SIZE_SCALE_FACTORS: Dictionary = {
	Enums.EntitySize.LIGHT: 0.4,
	Enums.EntitySize.MEDIUM: 0.6,
	Enums.EntitySize.HEAVY: 0.8,
	Enums.EntitySize.COLOSSAL: 1.0,
}

# ============================================================================
# DATA
# ============================================================================

# The game map reference for pathfinding and queries.
var game_map: GameMap

# ============================================================================
# CACHEs
# ============================================================================

# Cache of offensive modules for combat entities, keyed by combatant UUID.
var _offensive_modules: Dictionary = {}
# Cache of utility modules for combat entities, keyed by combatant UUID.
var _utility_modules: Dictionary = {}
# Cache of per-unit threat generated, keyed by combatant UUID.
var _threat_unit_cache: Dictionary = {}
# Cache of per-tile threat generated, keyed by a hash of the tile position and sensor range.
var _threat_tile_cache: Dictionary = {}
# Cache module threat scores, keyed by module UUID.
var _threat_module_cache: Dictionary = {}
# Cache of allies in range.
var _allies_in_range_cache: Dictionary = {}
# Cache of enemies in range.
var _enemies_in_range_cache: Dictionary = {}
# Cache the reachable tiles, keyed by combatant UUID.
var _reachable_tiles_cache: Dictionary = {}
# Cache squad entities for quick access, keyed by owner NAME.
var _squad_entities_cache: Dictionary = {}
# Cache line of sight checks, keyed by a hash of the source tile and target tile.
var _line_of_sight_cache: Dictionary[String, bool] = {}
# Cache pathfinding results, keyed by a hash of the source tile and target tile.
var _pathfinding_cache: Dictionary = {}

# ============================================================================
# PUBLIC METHODS
# ============================================================================


func _init(p_game_map: GameMap) -> void:
	assert(p_game_map, "AIPlanningContext requires a valid GameMap reference.")
	game_map = p_game_map


func get_turn_manager() -> TurnManager:
	"""
	Returns the turn manager associated with the current game map, if available.
	"""
	if not game_map:
		return null
	return game_map.turn_manager


func get_current_turn() -> int:
	"""
	Returns the current turn number, or -1 if no turn manager is available.
	"""
	var turn_manager: TurnManager = get_turn_manager()
	if not turn_manager:
		return -1
	return turn_manager.get_current_turn()


## Resets any cached data in the context. Should be called at the start of each new unit's planning
## to ensure fresh data.
func reset_context():
	_offensive_modules.clear()
	_utility_modules.clear()
	_reachable_tiles_cache.clear()
	_squad_entities_cache.clear()
	_allies_in_range_cache.clear()
	_enemies_in_range_cache.clear()
	_threat_tile_cache.clear()
	_line_of_sight_cache.clear()
	_pathfinding_cache.clear()
	# Do not reset:
	# - _threat_module_cache: Modules are static and their threat scores do not change.
	# - _threat_unit_cache: During combat unit modules do not change, so we consider them static. It
	#   is true that modules could be disabled or on cooldown, but recomputing the threat score for
	#   all units every turn would be expensive.


func get_allies(
	unit: MapCombatEntity,
	position: Vector2i,
	include_self: bool = false,
) -> Array[MapCombatEntity]:
	# Get the sensor range of the source unit.
	var sensor_range: int = unit.combatant.sensor_range
	# Get the hash of the tile for caching purposes.
	var tile_hash: String = _hash_position_range(unit, position, sensor_range)
	# Check if the allies for this tile are already cached.
	var allies: Array[MapCombatEntity] = []
	if tile_hash in _allies_in_range_cache:
		allies = _allies_in_range_cache[tile_hash]
	else:
		# Get the allies in range using the game map and cache the result.
		allies = AIUnitQueries.get_allies_in_range(game_map, unit, position, sensor_range)
		# Store the result in the cache for future queries.
		_allies_in_range_cache[tile_hash] = allies
	# If include_self is true, add the unit itself to the allies list.
	if include_self:
		allies.append(unit)
	return allies


func get_enemies(
	unit: MapCombatEntity,
	position: Vector2i,
) -> Array[MapCombatEntity]:
	# Get the sensor range of the source unit.
	var sensor_range: int = unit.combatant.sensor_range
	# Get the hash of the tile for caching purposes.
	var tile_hash: String = _hash_position_range(unit, position, sensor_range)
	# Check if the enemies for this tile are already cached.
	var enemies: Array[MapCombatEntity] = []
	if tile_hash in _enemies_in_range_cache:
		enemies = _enemies_in_range_cache[tile_hash]
	else:
		# Get the enemies in range using the game map and cache the result.
		enemies = AIUnitQueries.get_enemies_in_range(game_map, unit, position, sensor_range)
		# Store the result in the cache for future queries.
		_enemies_in_range_cache[tile_hash] = enemies
	return enemies


func get_reachable_tiles(
	unit: MapCombatEntity,
	position: Vector2i,
) -> Array[Vector2i]:
	# Get the hash of the tile for caching purposes.
	var tile_hash: String = _hash_position(unit, position)
	# Check if the reachable tiles for this unit are already cached.
	if tile_hash in _reachable_tiles_cache:
		return _reachable_tiles_cache[tile_hash]
	# Get the reachable tiles using the game map and cache the result.
	var raw_reachable_tiles: Array[Vector2i] = _get_reachable_tiles(unit)
	var reachable_tiles: Array[Vector2i] = []
	# Filter out occupied tiles (except the unit's current position) to avoid invalid move targets.
	for tile: Vector2i in raw_reachable_tiles:
		if game_map.is_occupied(tile) and tile != unit.position:
			continue
		reachable_tiles.append(tile)
	# Store the result in the cache for future queries.
	_reachable_tiles_cache[tile_hash] = reachable_tiles
	return reachable_tiles


func get_squad_entities(
	unit: MapCombatEntity,
) -> Array[MapCombatEntity]:
	# Get the hash for the squad entities cache based on the unit's owner.
	var owner_hash: String = _hash_owner(unit)
	# Check if the squad entities for this owner are already cached.
	if owner_hash in _squad_entities_cache:
		return _squad_entities_cache[owner_hash]
	# Get the squad entities using the game map and cache the result.
	var squad_entities: Array[MapCombatEntity] = _get_squad_entities(unit)
	# Store the result in the cache for future queries.
	_squad_entities_cache[owner_hash] = squad_entities
	return squad_entities


func get_squad_center(
	unit: MapCombatEntity,
) -> Vector2i:
	var entities: Array[MapCombatEntity] = get_squad_entities(unit)
	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y
	var squad_center: Vector2i = Vector2i(
		int(round(float(sum_x) / entities.size())),
		int(round(float(sum_y) / entities.size())),
	)
	return squad_center


func has_line_of_sight(
	from_tile: Vector2i,
	to_tile: Vector2i,
) -> bool:
	# If the source and target tiles are the same, we consider that there is line of sight.
	if from_tile == to_tile:
		return true
	# Get the hash for the line of sight check.
	var los_hash: String = _hash_tile_pair(from_tile, to_tile)
	if los_hash in _line_of_sight_cache:
		return _line_of_sight_cache[los_hash]

	# Perform the line of sight check using Bresenham's line algorithm and cache the result.
	var x0: int = from_tile.x
	var y0: int = from_tile.y
	var x1: int = to_tile.x
	var y1: int = to_tile.y
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var step_x: int = 1 if x0 < x1 else -1
	var step_y: int = 1 if y0 < y1 else -1
	var error: int = dx + dy

	var line_of_sight: bool = true
	while true:
		var tile: Vector2i = Vector2i(x0, y0)
		if tile != from_tile and tile != to_tile:
			if not game_map.is_in_bounds(tile):
				line_of_sight = false
				break
			if game_map.is_tile_blocked_for_pathfinding(tile):
				line_of_sight = false
				break
			if game_map.get_blocking_entity_at(tile):
				line_of_sight = false
				break

		if x0 == x1 and y0 == y1:
			break

		var e2: int = 2 * error
		if e2 >= dy:
			error += dy
			x0 += step_x
		if e2 <= dx:
			error += dx
			y0 += step_y

	# Cache the result for both directions to take advantage of LOS symmetry.
	_line_of_sight_cache[_hash_tile_pair(from_tile, to_tile)] = line_of_sight
	_line_of_sight_cache[_hash_tile_pair(to_tile, from_tile)] = line_of_sight
	return line_of_sight


func get_path(
	start: Vector2i,
	end: Vector2i,
) -> Array[Vector2i]:
	# Get the hash for the pathfinding result.
	var path_hash: String = _hash_tile_pair(start, end)
	if path_hash in _pathfinding_cache:
		return _pathfinding_cache[path_hash]
	# Get the path using the AIPathfinder.
	var path: Array[Vector2i] = AIPathfinder.get_shortest_path(game_map, start, end)
	# Store the result in the cache for future queries.
	_pathfinding_cache[path_hash] = path
	return path


func get_tile_threat_score(
	unit: MapCombatEntity,
	position: Vector2i,
) -> float:
	# Get the sensor range of the source unit.
	var sensor_range: int = unit.combatant.sensor_range
	# Get the hash of the tile for caching purposes.
	var tile_hash: String = _hash_position_range(unit, position, sensor_range)
	# Check if the threat score for this tile is already cached.
	if tile_hash in _threat_tile_cache:
		return _threat_tile_cache[tile_hash]
	# Compute the threat score for the tile based on the enemies in range and cache the result.
	var threat_score: float = 0.0
	# Get the enemies in range for the tile.
	var enemies: Array[MapCombatEntity] = get_enemies(unit, position)
	# Sum the threat scores of all enemies in range to get the total threat score for the tile.
	for enemy in enemies:
		threat_score += get_unit_threat_score(enemy)
	# Store the result in the cache for future queries.
	_threat_tile_cache[tile_hash] = threat_score
	return threat_score


func get_unit_threat_score(
	unit: MapCombatEntity,
) -> float:
	return _compute_unit_threat_score(unit)


func get_unit_offensive_modules(
	unit: MapCombatEntity,
) -> Array[EquippedModule]:
	return _get_unit_offensive_modules(unit)


func get_unit_utility_modules(
	unit: MapCombatEntity,
) -> Array[EquippedModule]:
	return _get_unit_utility_modules(unit)


func get_unit_modules(
	unit: MapCombatEntity,
) -> Array[EquippedModule]:
	var modules: Array[EquippedModule] = []
	modules += get_unit_offensive_modules(unit)
	modules += get_unit_utility_modules(unit)
	return modules


# ============================================================================
# PRIVATE METHODS
# ============================================================================


func _get_unit_offensive_modules(unit: MapCombatEntity) -> Array[EquippedModule]:
	# Get the hash for the unit.
	var unit_hash: String = _hash_unit(unit)
	# Check if the offensive modules for this unit are already cached.
	if unit_hash in _offensive_modules:
		return _offensive_modules[unit_hash]
	# Get the offensive modules for the unit and cache the result.
	var offensive_modules: Array[EquippedModule] = AIUtils.find_matching_modules(
		unit.combatant, true, false, false
	)
	# Store the result in the cache for future queries.
	_offensive_modules[unit_hash] = offensive_modules
	return offensive_modules


func _get_unit_utility_modules(unit: MapCombatEntity) -> Array[EquippedModule]:
	# Get the hash for the unit.
	var unit_hash: String = _hash_unit(unit)
	# Check if the utility modules for this unit are already cached.
	if unit_hash in _utility_modules:
		return _utility_modules[unit_hash]
	# Get the utility modules for the unit and cache the result.
	var utility_modules: Array[EquippedModule] = AIUtils.find_matching_modules(
		unit.combatant, false, false, false
	)
	# Store the result in the cache for future queries.
	_utility_modules[unit_hash] = utility_modules
	return utility_modules


func _compute_unit_threat_score(unit: MapCombatEntity) -> float:
	# Get the hash for the unit to check the threat cache.
	var unit_hash: String = _hash_unit(unit)
	# Check if the threat score for this unit is already cached.
	if unit_hash in _threat_unit_cache:
		return _threat_unit_cache[unit_hash]
	# Compute the threat score for the unit.
	var threat_score: float = 0.0
	for equipped_module: EquippedModule in _get_unit_offensive_modules(unit):
		threat_score += _score_module_threat(equipped_module)
	# Get the unit maximum survivability (full durability from max stats).
	var max_durability: float = unit.combatant.get_total_max_durability()
	max_durability = 1.0 if max_durability > 0.0 else 0.0
	# Get the unit current durability (health + armor + shield).
	var current_durability: float = unit.combatant.get_total_current_durability()
	current_durability = current_durability if max_durability > 0.0 else 0.0
	# Add to the threat score a factor based on the unit's current durability.
	threat_score += current_durability / max_durability
	# Store the result in the cache for future queries.
	_threat_unit_cache[unit_hash] = threat_score
	return threat_score


func _score_module_threat(equipped_module: EquippedModule) -> float:
	# Get the hash for the module to check the threat cache.
	var module_hash: String = hash_equipped_module(equipped_module)
	# Check if the threat score for this module is already cached.
	if module_hash in _threat_module_cache:
		return _threat_module_cache[module_hash]
	# Compute the threat score for the module. Remember that the threat score of an effect goes from
	# 0 to 1.
	var score := 0.0
	for effect: BaseEffect in equipped_module.effects:
		score += effect.get_threat_score()
	# Store the result in the cache for future queries.
	_threat_module_cache[module_hash] = score
	return score


func _get_reachable_tiles(unit: MapCombatEntity) -> Array[Vector2i]:
	return AIPathfinder.get_reachable_tiles(game_map, unit.position, unit.combatant.speed)


func _get_squad_entities(unit: MapCombatEntity) -> Array[MapCombatEntity]:
	return game_map.get_owned_combat_entities(unit.owner)


func _hash_unit(unit: MapCombatEntity) -> String:
	assert(unit, "Cannot hash a null unit.")
	assert(unit.combatant, "Cannot hash a unit without a combatant reference.")
	return unit.combatant.uuid


func _hash_owner(unit: MapCombatEntity) -> String:
	assert(unit, "Cannot hash a null unit.")
	return unit.owner.get_name()


func _hash_position(unit: MapCombatEntity, position: Vector2i) -> String:
	assert(unit, "Cannot hash a null unit.")
	assert(unit.combatant, "Cannot hash a unit without a combatant reference.")
	return "%s_%d_%d" % [unit.combatant.uuid, position.x, position.y]


func _hash_position_range(unit: MapCombatEntity, position: Vector2i, sensor_range: int) -> String:
	assert(unit, "Cannot hash a null unit.")
	assert(unit.combatant, "Cannot hash a unit without a combatant reference.")
	return "%s_%d_%d_%d" % [unit.combatant.uuid, position.x, position.y, sensor_range]


func hash_equipped_module(equipped_module: EquippedModule) -> String:
	assert(equipped_module, "Cannot hash a null module.")
	assert(equipped_module.item, "Cannot hash an equipped module without an item reference.")
	assert(equipped_module.module, "Cannot hash an equipped module without a module reference.")
	return "%s_%s" % [equipped_module.item.uuid, equipped_module.module.module_name]


func _hash_tile(position: Vector2i) -> String:
	return "%d_%d" % [position.x, position.y]


func _hash_tile_pair(from_tile: Vector2i, to_tile: Vector2i) -> String:
	return "%d_%d_%d_%d" % [from_tile.x, from_tile.y, to_tile.x, to_tile.y]
