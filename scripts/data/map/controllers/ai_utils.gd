extends Node

# =====================================================================
# PRIORITY CALCULATION FUNCTIONS
# =====================================================================

func evaluate_utility_effect_priority(target: MapMek, effect: ItemEffect) -> int:
	"""
	Calculates a priority score for a specific effect on a specific target.
	"""
	# Initialize the priority score.
	var priority = 0
	# Check the effect type and assign a score.
	match effect.type:
		# Repairs (High priority if the related stat is low)
		Enums.EffectType.HEALTH_REPAIR:
			if target.mek.health < target.mek.max_health * 0.4:
				priority += 16
			elif target.mek.health < target.mek.max_health * 0.7:
				priority += 8
		Enums.EffectType.SHIELD_REPAIR:
			if target.mek.shield < target.mek.max_shield * 0.4:
				priority += 16
			elif target.mek.shield < target.mek.max_shield * 0.7:
				priority += 8
		Enums.EffectType.ARMOR_REPAIR:
			if target.mek.armor < target.mek.max_armor * 0.4:
				priority += 16
			elif target.mek.armor < target.mek.max_armor * 0.7:
				priority += 8
		# Max stat modifiers (Lower priority than direct repairs)
		Enums.EffectType.HEALTH_MODIFIER:
			priority += 4 if target.mek.health < target.mek.max_health * 0.4 else 2
		Enums.EffectType.SHIELD_MODIFIER:
			priority += 4 if target.mek.shield < target.mek.max_shield * 0.4 else 2
		Enums.EffectType.ARMOR_MODIFIER:
			priority += 4 if target.mek.armor < target.mek.max_armor * 0.4 else 2
		Enums.EffectType.POWER_MODIFIER:
			priority += 3 if target.mek.power < target.mek.max_power * 0.4 else 1
		# Speed modifier (Always useful, moderate priority)
		Enums.EffectType.SPEED_MODIFIER:
			priority += 8
		# Combat performance modifiers (Medium priority)
		Enums.EffectType.ACCURACY_MODIFIER:
			priority += 12
		Enums.EffectType.RANGE_MODIFIER:
			priority += 12
		Enums.EffectType.COOLDOWN_MODIFIER:
			priority += 12
		# Regeneration effects (Lower than direct repair but useful)
		Enums.EffectType.HEALTH_REGEN:
			priority += 5 if target.mek.health < target.mek.max_health * 0.3 else 3
		Enums.EffectType.SHIELD_REGEN:
			priority += 5 if target.mek.shield < target.mek.max_shield * 0.3 else 3
		Enums.EffectType.ARMOR_REGEN:
			priority += 5 if target.mek.armor < target.mek.max_armor * 0.3 else 3
		Enums.EffectType.POWER_REGEN:
			priority += 5 if target.mek.power < target.mek.max_power * 0.3 else 3
		# Damage Reduction (Always useful, medium priority)
		Enums.EffectType.DAMAGE_REDUCTION_ALL:
			priority += 12
		Enums.EffectType.DAMAGE_REDUCTION_KINETIC:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_ENERGY:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_PLASMA:
			priority += 6
		Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE:
			priority += 6
	return priority


func evaluate_offensive_effect_priority(target: MapMek, effect: ItemEffect) -> int:
	"""
	Assigns a priority value to an offensive effect targeting a specific entity.
	"""
	var priority = 0

	# Factor 1: Threat level by size (larger = more threatening)

	priority += (target.mek.template.size + 1) * (target.mek.template.size + 1)

	# Factor 2: Target state sensitivity.

	if target.mek.health < target.mek.max_health * 0.25:
		priority += 10
	elif target.mek.health < target.mek.max_health * 0.5:
		priority += 5

	if target.mek.shield < target.mek.max_shield * 0.25:
		priority += 6
	elif target.mek.shield < target.mek.max_shield * 0.5:
		priority += 3

	if target.mek.armor < target.mek.max_armor * 0.25:
		priority += 4
	elif target.mek.armor < target.mek.max_armor * 0.5:
		priority += 2

	# Factor 3: Effect-Specific Logic
	
	match effect.type:
		Enums.EffectType.DAMAGE:
			# Scale based on raw damage amount.
			priority += clamp(effect.amount / 10.0, 1, 10)

		Enums.EffectType.DAMAGE_OVER_TIME:
			var existing_effects: Array[ActiveEffect] = target.mek.active_effect_manager.get_effects_by_type(effect.type)
			if existing_effects.size() > 0:
				# If the target already has this effect, prioritize it based on
				# how much time it has left.
				for existing_effect: ActiveEffect in existing_effects:
					priority -= 10.0 * (1 - (existing_effect.effect.duration - existing_effect.remaining_duration))
			else:
				# Scale based on damage per second and duration.
				priority += clamp((effect.amount * effect.duration) / 5.0, 1, 8)

		Enums.EffectType.ACCURACY_MODIFIER, Enums.EffectType.RANGE_MODIFIER, Enums.EffectType.COOLDOWN_MODIFIER:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 4, 16)

		Enums.EffectType.POWER_MODIFIER, Enums.EffectType.HEALTH_MODIFIER, Enums.EffectType.ARMOR_MODIFIER, Enums.EffectType.SHIELD_MODIFIER:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 1, 8)

		Enums.EffectType.SPEED_MODIFIER:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 4, 16)

		Enums.EffectType.HEALTH_REGEN, Enums.EffectType.SHIELD_REGEN, Enums.EffectType.ARMOR_REGEN, Enums.EffectType.POWER_REGEN:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 3, 12)

		Enums.EffectType.DAMAGE_REDUCTION_ALL:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 3, 12)

		Enums.EffectType.DAMAGE_REDUCTION_KINETIC, Enums.EffectType.DAMAGE_REDUCTION_ENERGY, Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE, Enums.EffectType.DAMAGE_REDUCTION_PLASMA, Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE:
			if effect.amount < 0: priority += clamp(abs(effect.amount), 2, 8)

		# Ignore healing, or buffs (they should never appear here).
		_:
			priority += 0

	# Cap to prevent over-prioritization.
	return clamp(priority, 0, 25)


func score_utility_module_on_target(
	module: ItemModule,
	source: MapMek,
	target: MapMek
) -> int:
	"""
	Calculates the total priority score for a module on a target.
	"""
	var total: int = 0
	for effect in module.effects:
		if effect.target == Enums.TargetType.SELF and target != source:
			continue
		if effect.target == Enums.TargetType.ALLY and target == source:
			continue
		if effect.target == Enums.TargetType.ENEMY and target == source:
			continue
		total += evaluate_utility_effect_priority(target, effect)
	return total


func score_offensive_module_on_target(module: ItemModule, target: MapMek) -> int:
	"""
	Calculates the total priority score for a module on a target.
	"""
	var total: int = 0
	for effect in module.effects:
		total += evaluate_offensive_effect_priority(target, effect)
	return total


# =====================================================================
# MODULE FILTERING FUNCTIONS
# =====================================================================

func can_module_be_used_now(mek: Mek, item: Item, module: ItemModule) -> bool:
	"""
	Checks if a module can be used based on its cooldown and power requirements.
	"""
	if module.passive:
		return false
	if mek.cooldown_manager.is_on_cooldown(item, module):
		return false
	if mek.power < module.power_on_use:
		return false
	return true

func find_matching_modules(
	mek: Mek,
	offensive: bool,
	include_passive: bool,
	include_on_cooldown: bool
) -> Array[EquippedModule]:
	"""
	Returns a list of modules matching the requested type (offensive or utility).
	Flags control whether passive modules and modules on cooldown are included.
	"""
	var matching_modules: Array[EquippedModule] = []
	for item in mek.items:
		# Filter by slot type based on offensive flag.
		if offensive and item.template.slot == Enums.SlotType.UTILITY:
			continue
		if not offensive and item.template.slot != Enums.SlotType.UTILITY:
			continue
		for module in item.template.modules:
			# Optionally skip passive modules.
			if not include_passive and module.passive:
				continue
			# Optionally skip modules on cooldown.
			if not include_on_cooldown and mek.cooldown_manager.is_on_cooldown(item, module):
				continue
			# Always skip if not enough power.
			if mek.power < module.power_on_use:
				continue
			# Add the module if all checks passed.
			matching_modules.append(EquippedModule.new(mek, item, module))
	return matching_modules

# =====================================================================
# PATHFINDING FUNCTIONS
# =====================================================================

func normalize_position(vector: Vector2i) -> Vector2:
	"""
	Returns a normalized Vector2 version of a Vector2i.
	"""
	var length = sqrt(vector.x * vector.x + vector.y * vector.y)
	if length == 0:
		return Vector2(0, 0) # Avoid division by zero; return zero vector.
	return Vector2(vector.x / length, vector.y / length)


func round_position(vector: Vector2) -> Vector2i:
	"""
	Returns a Vector2i with each component rounded to the nearest integer.
	"""
	return Vector2i(round(vector.x), round(vector.y))


func get_shortest_path(game_map: GameMap, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	"""
	Returns the shortest path between two tiles using AStar2D.
	"""
	# Get the AStar IDs for the start and end positions.
	var start_id = game_map.position_to_astar_id(start)
	var end_id = game_map.position_to_astar_id(end)
	# Check if the start and end points are valid.
	if not game_map.astar.has_point(start_id):
		GameServer.log_message("AStar does not have starting point %s, %d" % [str(start), start_id])
		return []
	if not game_map.astar.has_point(end_id):
		GameServer.log_message("AStar does not have ending point %s, %d" % [str(end), end_id])
		return []
	# Get the path from AStar.
	var path: PackedVector2Array = game_map.astar.get_point_path(start_id, end_id, true)
	# Convert the path to a regular array.
	var result: Array[Vector2i] = []
	for i in range(path.size()):
		result.append(Vector2i(path[i]))
	return result


func get_path_cost(game_map: GameMap, path: PackedVector2Array) -> float:
	"""
	Compute the total cost of a path.
	"""
	var cost = 0.0
	for i in range(1, path.size()):
		cost += game_map.get_movement_cost(Vector2i(path[i]))
	return cost


func get_tiles_in_range(game_map: GameMap, position: Vector2i, max_range: int) -> Array[Vector2i]:
	"""
	Returns all tiles within a given range from a starting position.
	"""
	var visible: Array[Vector2i] = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var tile = position + Vector2i(dx, dy)
			if game_map.is_in_bounds(tile):
				if position.distance_to(tile) <= max_range:
					visible.append(tile)
	return visible

func get_reachable_tiles(game_map: GameMap, start: Vector2i, max_cost: int) -> Array[Vector2i]:
	"""
	Returns all reachable tiles from a starting position within a given cost.
	"""
	# Prepare the list of reachable tiles.
	var reachable: Array[Vector2i] = []
	# Get the AStar ID for the starting position.
	var start_id = game_map.position_to_astar_id(start)
	# Check that the starting position is valid.
	if not game_map.astar.has_point(start_id):
		return reachable
	# Get all candidate tiles within the maximum cost + 2.
	var candidate_tiles = get_tiles_in_range(game_map, start, max_cost + 2)
	# Iterate over the candidate tiles.
	for tile in candidate_tiles:
		# Skip the starting tile.
		if tile != start:
			# Get the ID of the candidate tile.
			var id = game_map.position_to_astar_id(tile)
			# Check that the candidate tile is valid.
			if game_map.astar.has_point(id):
				# Get the path to the candidate tile.
				var path = game_map.astar.get_point_path(start_id, id, true)
				# Check that the path is valid.
				if path.size() < 2:
					continue
				# Get the cost of the path.
				var cost = get_path_cost(game_map, path)
				# If the cost is within the maximum allowed, add the tile to the reachable list.
				if cost <= max_cost:
					reachable.append(tile)
	return reachable

func get_distance(game_map: GameMap, from: Vector2i, to: Vector2i) -> float:
	"""
	Returns the distance between two tiles on the game map.
	"""
	var path = get_shortest_path(game_map, from, to)
	if path.is_empty():
		return INF
	return get_path_cost(game_map, path)

# =====================================================================
# UNIT UTILITY FUNCTIONS
# =====================================================================

func get_all_units(game_map: GameMap) -> Array[MapMek]:
	"""
	Returns all units in the game map.
	"""
	return game_map.player_units.values() + game_map.npc_units.values()


func get_units_in_range(
	game_map: GameMap,
	source: MapMek,
	position: Vector2i,
	radius: int,
	include_allies: bool = true,
	include_enemies: bool = true,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all units within the specified range of a position.
	Parameters:
	- source: The unit doing the search (to determine ally/enemy).
	- position: The origin position for the search.
	- radius: The radius in tiles.
	- include_allies: Whether to include units on the same side as source.
	- include_enemies: Whether to include enemy units.
	- exclude_units: Optional list of units to ignore.
	"""
	var units_in_range: Array[MapMek] = []
	for entity in get_all_units(game_map):
		if entity == source:
			continue
		if entity in exclude_units:
			continue
		if position.distance_to(entity.position) > radius:
			continue
		if include_allies and not game_map.is_enemy_of(source, entity):
			units_in_range.append(entity)
		elif include_enemies and game_map.is_enemy_of(source, entity):
			units_in_range.append(entity)
	return units_in_range


func get_enemies_in_range(
	game_map: GameMap,
	source: MapMek,
	radius: int,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all enemy units within a specified range of the source unit.
	"""
	return get_units_in_range(game_map, source, source.position, radius, false, true, exclude_units)


func get_allies_in_range(
	game_map: GameMap,
	source: MapMek,
	radius: int,
	exclude_units: Array[MapMek] = []
) -> Array[MapMek]:
	"""
	Returns all ally units within a specified range of the source unit.
	"""
	return get_units_in_range(game_map, source, source.position, radius, true, false, exclude_units)


func get_threat_level(
	game_map: GameMap,
	tile: Vector2i,
	source: MapMek
) -> float:
	"""
	Estimates how dangerous it would be to stand on this tile.
	Threat level is based on the number and strength of enemy units
	that could hit this tile.
	"""
	var threat_score: float = 0.0
	# Get all enemy units in range of the tile.
	for enemy in get_enemies_in_range(game_map, source, 9999):
		# Get the range modifier for the enemy unit.
		var range_modifier = enemy.mek.range_modifier
		# Check if any offensive module can reach this tile.
		for equipped_module in find_matching_modules(enemy.mek, true, false, false):
			# Get the module range.
			var module_range = equipped_module.module.module_range + range_modifier
			# Get the distance to the tile.
			var distance = tile.distance_to(enemy.position)
			# Check if the tile is within the module range.
			if distance >= 0 and distance <= module_range:
				# Score is based on module damage or default threat
				for effect in equipped_module.module.effects:
					if effect.type == Enums.EffectType.DAMAGE:
						threat_score += float(effect.amount)
					elif effect.type == Enums.EffectType.DAMAGE_OVER_TIME:
						threat_score += float(effect.amount * effect.duration) * 0.5
					else:
						threat_score += 2.0 # Fallback small threat
	return threat_score


func can_reach_target_this_turn(
	game_map: GameMap,
	source: MapMek,
	target: MapMek,
	range_min: int,
	range_max: int,
	max_movement: int
) -> bool:
	"""
	Determines if the source can reach a tile from which it can attack the target this turn.
	"""
	var reachable_tiles = get_reachable_tiles(game_map, source.position, max_movement)

	for tile in reachable_tiles:
		if game_map.is_occupied(tile):
			continue
		var distance = tile.distance_to(target.position)
		if distance >= range_min and distance <= range_max:
			return true
	return false


func get_most_vulnerable_enemy(
	game_map: GameMap,
	source: MapMek,
	max_distance: int
) -> MapMek:
	"""
	Returns the enemy with the lowest combined survivability ratio within range.
	Combined survivability = (health + armor + shield) / (max values).
	"""
	var weakest: MapMek = null
	var lowest_score: float = INF

	for enemy in get_units_in_range(game_map, source, source.position, max_distance, false, true):
		var current_total = float(enemy.mek.health + enemy.mek.armor + enemy.mek.shield)
		var max_total = float(enemy.mek.max_health + enemy.mek.max_armor + enemy.mek.max_shield)
		# Sanity check
		if max_total > 0:
			var ratio: float = current_total / max_total
			if ratio < lowest_score:
				lowest_score = ratio
				weakest = enemy
	return weakest


func find_furthest_progress_along_path(
	game_map: GameMap,
	start: Vector2i,
	target: Vector2i,
	max_movement: int
) -> Vector2i:
	"""
	Returns the farthest tile along the path toward the target that the unit
	can safely move to this turn (based on movement cost and occupancy).
	"""
	var path = get_shortest_path(game_map, start, target)
	if path.size() <= 1:
		return start
	var total_cost = 0.0
	var fallback_tile = start
	for i in range(1, path.size()):
		var tile = path[i]
		if game_map.is_occupied(tile):
			break
		var cost = game_map.get_movement_cost(tile)
		if cost < 0 or total_cost + cost > max_movement:
			break
		total_cost += cost
		fallback_tile = tile
	return fallback_tile


func find_closest_reachable_tile(
	game_map: GameMap,
	source: MapMek,
	target: MapMek,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	# This will keep track of the best tile.
	var best_tile: Vector2i = Vector2i.ZERO
	# This will keep track of the best distance to the target (lower is better).
	var shortest_distance: float = INF
	# Check for ideal case: reachable and in range.
	for tile in get_reachable_tiles(game_map, source.position, max_movement):
		# Skip occupied tiles.
		if game_map.is_occupied(tile):
			continue
		# Get the distance to the target.
		var distance = tile.distance_to(target.position)
		# Check if the tile is within the specified range.
		if distance < min_range or distance > max_range:
			continue
		# Check if the tile is closer than the best one found so far.
		if distance < shortest_distance:
			best_tile = tile
			shortest_distance = distance
	# If we found a valid tile in range, use it.
	if best_tile != Vector2i.ZERO:
		return best_tile
	# No valid tile in range — fallback toward the target.
	return find_furthest_progress_along_path(game_map, source.position, target.position, max_movement)


func find_best_attack_tile(
	game_map: GameMap,
	source: MapMek,
	target: MapMek,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	# This will keep track of the best tile.
	var best_tile: Vector2i = Vector2i.ZERO
	# This will keep track of the best score (higher is better).
	var best_score: float = - INF
	# Check for the tile.
	for tile in get_reachable_tiles(game_map, source.position, max_movement):
		# Skip occupied tiles.
		if game_map.is_occupied(tile):
			continue
		# Get the distance to the target.
		var distance = tile.distance_to(target.position)
		# Check if the tile is within the specified range.
		if distance < min_range or distance > max_range:
			continue
		# Get the movement cost to the tile.
		var move_cost = get_path_cost(game_map, get_shortest_path(game_map, source.position, tile))
		# Get the height difference between the tile and the target.
		var height_difference = game_map.get_tile_height(tile) - game_map.get_tile_height(target.position)
		# Calculate the ideal range.
		var ideal_range = (min_range + max_range) / 2.0
		# Calculate the range penalty.
		var range_penalty = abs(distance - ideal_range)
		# Calculate the score.
		var score = - move_cost - range_penalty + height_difference * 2.0
		# Check if the score is better than the best one found so far.
		if score > best_score:
			best_score = score
			best_tile = tile
	# If we found a valid tile in range, use it.
	if best_tile != Vector2i.ZERO:
		return best_tile
	# No valid tile in range — fallback toward the target.
	return find_furthest_progress_along_path(game_map, source.position, target.position, max_movement)


func find_random_reachable_tile(
	game_map: GameMap,
	start: Vector2i,
	max_cost: int
) -> Vector2i:
	# Get the reachable tiles from the starting position.
	var tiles = get_reachable_tiles(game_map, start, max_cost)
	# Filter the tiles to exclude occupied ones.
	var valid_tiles = tiles.filter(func(tile): return not game_map.is_occupied(tile))
	# If no valid tiles are found, return the starting position.
	if valid_tiles.is_empty():
		return Vector2i.ZERO
	# Otherwise, return a random tile from the valid tiles.
	return valid_tiles.pick_random()
