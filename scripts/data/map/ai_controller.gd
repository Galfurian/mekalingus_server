extends RefCounted

class_name AIController

# =============================================================================
# PROPERTIES
# =============================================================================

var game_map: GameMap

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================

func _init(p_game_map: GameMap) -> void:
	game_map = p_game_map

func log_message(msg: String):
	GameServer.log_message(msg)

static func format_mek_tag(mek: Mek) -> String:
	if not mek: return "<mek-null>"
	return "[url=mek:%s]%s[/url]" % [mek.uuid, mek.template.name]

static func format_item_tag(mek: Mek, item: Item, module: ItemModule) -> String:
	if not mek:  return "<mek-null>"
	if not item: return "<item-null>"
	if not item: return "<module-null>"
	return "[url=item:%s:%s]%s[/url]" % [mek.uuid, item.uuid, module.name]

static func format_item_pair_tag(mek: Mek, item_module_pair: Dictionary) -> String:
	return format_item_tag(mek, item_module_pair.get("item", null), item_module_pair.get("module", null))

static func format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]

# =============================================================================
# SCHEDULE UTILITY ORDER
# =============================================================================

func _evaluate_utility_effect_priority(target: MapEntity, effect: ItemEffect) -> int:
	"""Calculates a priority score for a specific effect on a specific target."""
	var priority = 0
	var target_mek: Mek = target.entity
	# Check the effect type and assign a score.
	match effect.type:
		# Repairs (High priority if the related stat is low)
		Enums.EffectType.HEALTH_REPAIR:
			if target_mek.health < target_mek.max_health * 0.4:
				priority += 10
			elif target_mek.health < target_mek.max_health * 0.7:
				priority += 6
		Enums.EffectType.SHIELD_REPAIR:
			if target_mek.shield < target_mek.max_shield * 0.4:
				priority += 8
			elif target_mek.shield < target_mek.max_shield * 0.7:
				priority += 4
		Enums.EffectType.ARMOR_REPAIR:
			if target_mek.armor < target_mek.max_armor * 0.4:
				priority += 8
			elif target_mek.armor < target_mek.max_armor * 0.7:
				priority += 4
		# Max stat modifiers (Lower priority than direct repairs)
		Enums.EffectType.HEALTH_MODIFIER:
			priority += 4 if target_mek.health < target_mek.max_health * 0.4 else 2
		Enums.EffectType.SHIELD_MODIFIER:
			priority += 4 if target_mek.shield < target_mek.max_shield * 0.4 else 2
		Enums.EffectType.ARMOR_MODIFIER:
			priority += 4 if target_mek.armor < target_mek.max_armor * 0.4 else 2
		Enums.EffectType.POWER_MODIFIER:
			priority += 3 if target_mek.power < target_mek.max_power * 0.4 else 1
		# Speed modifier (Always useful, moderate priority)
		Enums.EffectType.SPEED_MODIFIER:
			priority += 5
		# Combat performance modifiers (Medium priority)
		Enums.EffectType.ACCURACY_MODIFIER:
			priority += 4
		Enums.EffectType.RANGE_MODIFIER:
			priority += 4
		Enums.EffectType.COOLDOWN_MODIFIER:
			priority += 4
		# Regeneration effects (Lower than direct repair but useful)
		Enums.EffectType.SHIELD_REGEN:
			priority += 5 if target_mek.shield < target_mek.max_shield * 0.3 else 3
		Enums.EffectType.ARMOR_REGEN:
			priority += 5 if target_mek.armor < target_mek.max_armor * 0.3 else 3
		Enums.EffectType.POWER_REGEN:
			priority += 5 if target_mek.power < target_mek.max_power * 0.3 else 3
		# Damage Reduction (Always useful, medium priority)
		Enums.EffectType.DAMAGE_REDUCTION_ALL:
			priority += 6
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

func _get_utility_effect_targets(effect: ItemEffect, source: MapEntity, module_range: int) -> Array[MapEntity]:
	"""
	Returns a list of valid potential targets for the given effect,
	based on target type and range, for AI decision-making.
	"""
	match effect.target:
		Enums.TargetType.SELF:
			return [source]
		Enums.TargetType.ENEMY:
			return game_map.get_units_in_range(source, source.position, module_range, false, true)
		Enums.TargetType.ALLY:
			return game_map.get_units_in_range(source, source.position, module_range, true, false)
		Enums.TargetType.AREA:
			# Area effects are centered on the target during execution,
			# but for AI targeting we want to know which targets could be the AoE center.
			# So return all potential units it could center on.
			return game_map.get_units_in_range(source, source.position, module_range, true, true)
	return []

func _find_usable_utility_modules(mek: Mek) -> Array[Dictionary]:
	"""Finds all utility modules that can be used by the Mek."""
	var usable_modules: Array[Dictionary] = []
	for item in mek.items:
		# Ensure the item is a utility module.
		if item.template.slot != Enums.SlotType.UTILITY:
			continue
		for module in item.template.modules:
			# Ignore passive modules.
			if module.passive:
				continue
			# Check if the module is on cooldown.
			if mek.cooldown_manager.is_on_cooldown(item, module):
				continue
			# Check if the Mek lacks power to use it.
			if mek.power < module.power_on_use:
				continue
			# If all checks pass, add the module to the usable list.
			usable_modules.append({"item": item, "module": module})
	return usable_modules

func _determine_best_utility_module_target(source: MapEntity, item_module_pair: Dictionary) -> Dictionary:
	"""Determines the best target and priority for the given utility module."""
	var best_target: MapEntity = null
	var highest_priority: int = 0
	game_map.add_log(Enums.LogType.AI,
		"%s is determining the best target for module %s..." % [
			format_mek_tag(source.entity), format_item_pair_tag(source.entity, item_module_pair)
		]
	)
	game_map.increase_indent()
	for effect in item_module_pair.module.effects:
		var candidates = _get_utility_effect_targets(effect, source, item_module_pair.module.module_range)
		for candidate in candidates:
			# Skip evaluation if the effect is already active on this Mek.
			if candidate.entity.has_effect_type(effect.type):
				continue
			var priority = _evaluate_utility_effect_priority(candidate, effect)
			# Apply power penalty if using this module would drain the Mek
			if not item_module_pair.module.passive and item_module_pair.module.power_on_use > 0:
				var power_after_use = candidate.entity.power - item_module_pair.module.power_on_use
				var remaining_ratio = float(power_after_use) / float(candidate.entity.max_power)
				var penalty_applied = 0
				if remaining_ratio < 0.25:
					penalty_applied = 5
				elif remaining_ratio < 0.5:
					penalty_applied = 3
				elif remaining_ratio < 0.75:
					penalty_applied = 1
				priority = max(priority, priority - penalty_applied)
			game_map.add_log(Enums.LogType.AI,
				"%s, evaluated %s on %s: effect=%s, priority=%d" % [
					format_mek_tag(source.entity),
					format_item_pair_tag(source.entity, item_module_pair),
					format_mek_tag(candidate.entity),
					Enums.EffectType.keys()[effect.type],
					priority
				]
			)
			if priority > highest_priority:
				highest_priority = priority
				best_target = candidate
	if best_target:
		game_map.add_log(Enums.LogType.AI,
			"%s has selected target %s for module %s (priority %d)" % [
				format_mek_tag(source.entity),
				format_mek_tag(best_target.entity),
				format_item_pair_tag(source.entity, item_module_pair),
				highest_priority
			]
		)
	else:
		game_map.add_log(Enums.LogType.AI,
			"%s has no suitable target found for its module %s" % [
				format_mek_tag(source.entity),
				format_item_pair_tag(source.entity, item_module_pair)
			]
		)
	game_map.decrease_indent()
	return {"target": best_target, "priority": highest_priority}

func schedule_utility_module_order(source: MapEntity) -> UseModuleOrder:
	"""Schedules an utility use action for the AI-controlled Mek."""
	var mek: Mek = source.entity	
	var best_module: Dictionary = {"item": null, "module": null}
	var best_target: MapEntity = null
	var highest_priority: int = 0
	
	for item_module_pair in _find_usable_utility_modules(mek):
		var result = _determine_best_utility_module_target(source, item_module_pair)
		var adjusted_priority = result.priority
		if result.priority > 0:
			adjusted_priority += int(item_module_pair.module.cooldown / 2)
		if adjusted_priority > highest_priority:
			highest_priority = adjusted_priority
			best_module = item_module_pair
			best_target = result.target
	
	if best_module.item and best_module.module and best_target and highest_priority > 0:
		game_map.add_log(
			Enums.LogType.AI,
			"%s selected utility module %s targeting %s (final priority=%d)" % [
				format_mek_tag(source.entity),
				format_item_pair_tag(source.entity, best_module),
				format_mek_tag(best_target.entity),
				highest_priority
			]
		)
		return UseModuleOrder.new(source, best_target, best_module.item, best_module.module)
	return null

# =============================================================================
# SCHEDULE OFFENSIVE ORDER
# =============================================================================

func _evaluate_offensive_effect_priority(target: MapEntity, effect: ItemEffect) -> int:
	"""Assigns a priority value to an offensive effect targeting a specific entity."""
	var priority = 0
	var mek: Mek = target.entity

	# === Factor 1: Threat level by size (larger = more threatening) ===
	priority += (mek.template.size + 1) * (mek.template.size + 1)

	# === Factor 2: Target state sensitivity ===
	if mek.health < mek.max_health * 0.25:
		priority += 10
	elif mek.health < mek.max_health * 0.5:
		priority += 5

	if mek.shield < mek.max_shield * 0.25:
		priority += 6
	elif mek.shield < mek.max_shield * 0.5:
		priority += 3

	if mek.armor < mek.max_armor * 0.25:
		priority += 4
	elif mek.armor < mek.max_armor * 0.5:
		priority += 2

	# === Factor 3: Effect-Specific Logic ===
	match effect.type:
		Enums.EffectType.DAMAGE:
			# Scale based on raw damage
			priority += clamp(effect.amount / 10.0, 1, 10)

		Enums.EffectType.DAMAGE_OVER_TIME:
			if mek.has_effect_type(effect.type):
				return 0
			var dot_score = (effect.amount * effect.duration) / 5.0
			priority += clamp(dot_score, 1, 8)

		Enums.EffectType.SPEED_MODIFIER, \
		Enums.EffectType.ACCURACY_MODIFIER, \
		Enums.EffectType.RANGE_MODIFIER, \
		Enums.EffectType.COOLDOWN_MODIFIER, \
		Enums.EffectType.POWER_MODIFIER, \
		Enums.EffectType.HEALTH_MODIFIER, \
		Enums.EffectType.ARMOR_MODIFIER, \
		Enums.EffectType.SHIELD_MODIFIER:
			# Prioritize debuffs (negative values), deprioritize buffs (positive values)
			if effect.amount < 0:
				priority += clamp(abs(effect.amount), 1, 8)
			else:
				priority += 1

		Enums.EffectType.DAMAGE_REDUCTION_ALL, \
		Enums.EffectType.DAMAGE_REDUCTION_KINETIC, \
		Enums.EffectType.DAMAGE_REDUCTION_ENERGY, \
		Enums.EffectType.DAMAGE_REDUCTION_EXPLOSIVE, \
		Enums.EffectType.DAMAGE_REDUCTION_PLASMA, \
		Enums.EffectType.DAMAGE_REDUCTION_CORROSIVE:
			# These are strong debuffs, especially if applied to enemies
			if effect.amount < 0:
				priority += clamp(abs(effect.amount), 2, 6)

		# Ignore healing, regeneration, or buffs (they should never appear here)
		_:
			priority += 0

	# Cap to prevent over-prioritization.
	return clamp(priority, 0, 25)

func _determine_best_offensive_module_target(source: MapEntity, item_module_pair: Dictionary) -> Dictionary:
	"""Determines the best target and priority for the given offensive module."""
	var best_target: MapEntity = null
	var highest_priority: int = -1
	var candidates = game_map.get_units_in_range(source, source.position, item_module_pair.module.module_range, false, true)
	
	game_map.add_log(Enums.LogType.AI,
		"%s is determining the best target for module %s (candidates: %d)..." % [
			format_mek_tag(source.entity), format_item_pair_tag(source.entity, item_module_pair), candidates.size()
		]
	)
	game_map.increase_indent()
	
	for target in candidates:
		if target == source:
			continue
		for effect in item_module_pair.module.effects:
			var priority = _evaluate_offensive_effect_priority(target, effect)
			game_map.add_log(Enums.LogType.AI,
				"%s, evaluated %s on %s: effect=%s, priority=%d" % [
					format_mek_tag(source.entity),
					format_item_pair_tag(source.entity, item_module_pair),
					format_mek_tag(target.entity),
					Enums.EffectType.keys()[effect.type],
					priority
				]
			)
			if priority > highest_priority:
				highest_priority = priority
				best_target = target
	if best_target:
		game_map.add_log(Enums.LogType.AI,
			"%s has selected target %s for module %s (priority %d)" % [
				format_mek_tag(source.entity),
				format_mek_tag(best_target.entity),
				format_item_pair_tag(source.entity, item_module_pair),
				highest_priority
			]
		)
	else:
		game_map.add_log(Enums.LogType.AI,
			"%s has no suitable target found for its module %s" % [
				format_mek_tag(source.entity),
				format_item_pair_tag(source.entity, item_module_pair)
			]
		)
	
	game_map.decrease_indent()
	return {"target": best_target, "priority": highest_priority}

func _find_usable_offensive_modules(mek: Mek) -> Array[Dictionary]:
	"""Finds all offensive modules that can be used by the Mek."""
	var usable_modules: Array[Dictionary] = []
	for item in mek.items:
		# Ensure the item is an offensive module (not a utility module).
		if item.template.slot == Enums.SlotType.UTILITY:
			continue
		for module in item.template.modules:
			# Ignore passive modules.
			if module.passive:
				continue
			# Check if the module is on cooldown.
			if mek.cooldown_manager.is_on_cooldown(item, module):
				continue
			# Check if the Mek lacks power to use it.
			if mek.power < module.power_on_use:
				continue
			# If all checks pass, add the module to the usable list.
			usable_modules.append({"item": item, "module": module})
	return usable_modules

func schedule_offensive_module_order(source: MapEntity):
	"""Schedules an offensive action for the AI-controlled Mek."""
	# Find all usable offensive modules.
	var mek: Mek = source.entity
	var usable_modules = _find_usable_offensive_modules(mek)
	
	# Track the best module and target.
	var best_module: Dictionary = {"item": null, "module": null}
	var best_target: MapEntity = null
	var highest_priority: int = -1
	
	# Determine the best target and priority for each usable module.
	for item_module_pair in usable_modules:
		var result = _determine_best_offensive_module_target(source, item_module_pair)
		if result.priority > highest_priority:
			highest_priority = result.priority
			best_module = item_module_pair
			best_target = result.target
	
	# If a valid module and target were found, queue a use order.
	if best_module.item and best_module.module and best_target and highest_priority > 0:
		game_map.add_log(
			Enums.LogType.AI,
			"%s selected offensive module %s targeting %s (final priority=%d)" % [
				format_mek_tag(source.entity),
				format_item_pair_tag(source.entity, best_module),
				format_mek_tag(best_target.entity),
				highest_priority
			]
		)
		return UseModuleOrder.new(source, best_target, best_module.item, best_module.module)
	return null

# =============================================================================
# SCHEDULE MOVE ORDER
# =============================================================================

func normalize_position(vector: Vector2i) -> Vector2:
	"""Returns a normalized Vector2 version of a Vector2i."""
	var length = sqrt(vector.x * vector.x + vector.y * vector.y)
	if length == 0:
		return Vector2(0, 0)  # Avoid division by zero; return zero vector.
	return Vector2(vector.x / length, vector.y / length)

func round_position(vector: Vector2) -> Vector2i:
	"""Returns a Vector2i with each component rounded to the nearest integer."""
	return Vector2i(round(vector.x), round(vector.y))

func _evaluate_movement_priority(source: MapEntity, target: MapEntity, desired_range: int) -> int:
	"""Assigns a priority to moving toward the specified target."""
	# If the source is the target.
	if source == target:
		return -1
	# Get current distance between source and target.
	var current_distance = source.position.distance_to(target.position)
	# If already within or closer than desired range, don't move.
	if current_distance <= desired_range:
		return 0
	# Set he priority to 0,.
	var priority = abs(current_distance - desired_range)
	# Calculate priority based on distance from desired range (closer to desired = higher priority)	var priority = abs(current_distance - desired_range)
	# Adjust priority based on target type.
	if game_map.is_enemy_of(source, target):
		priority += 5  # Higher priority if target is an enemy.
	else:
		priority += 2  # Lower priority if target is an ally.
	game_map.add_log(
		Enums.LogType.AI,
		"%s evaluated movement toward %s: distance=%d, is_enemy=%s, priority=%d" % [
			format_mek_tag(source.entity),
			format_mek_tag(target.entity),
			int(current_distance),
			str(game_map.is_enemy_of(source, target)),
			priority
		]
	)
	# Ensure the priority is not negative.
	return max(priority, 0)

func _find_high_priority_targets(source: MapEntity, detection_range: int, desired_range: int) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var nearby_units = game_map.get_units_in_range(source, source.position, detection_range, false, true)
	for target in nearby_units:
		var priority = _evaluate_movement_priority(source, target, desired_range)
		if priority >= 0:
			targets.append({"target": target, "priority": priority})
	return targets

func _select_best_target(targets: Array[Dictionary]) -> Dictionary:
	"""Selects the target with the highest priority."""
	# Return an empty dictionary if no targets exist.
	if targets.is_empty():
		return {}
	# Initialize the best target data.
	var best_target_data = targets[0]
	# Iterate through the targets to find the one with the highest priority.
	for target_data in targets:
		if target_data.priority > best_target_data.priority:
			best_target_data = target_data
	return best_target_data

func _select_movement_destination(start_position: Vector2i, target_position: Vector2i, max_movement: int) -> Vector2i:
	"""Determines the best tile to move closer to the target using A* pathfinding with movement cost."""
	var path: Array[Vector2i] = game_map.get_path(start_position, target_position)
	# If there's no path or it's too short, return start.
	if path.is_empty() or path.size() <= 1:
		game_map.add_log(
			Enums.LogType.AI,
			"No valid path from %s to %s." % [
				format_pos_tag(start_position),
				format_pos_tag(target_position)
			]
		)
		return start_position
	var destination = start_position
	var total_cost = 0
	for i in range(1, path.size()):  # skip start_position
		var tile = path[i]
		var cost = game_map.get_movement_cost(tile)
		if cost < 0:
			break  # impassable tile
		if total_cost + cost > max_movement:
			break  # reached movement limit
		if game_map.can_move_to(tile):
			destination = tile
		total_cost += cost
	if destination != start_position:
		return destination
	# Fallback: try earlier tiles (backtrack)
	for i in range(path.size() - 2, 0, -1):
		var fallback_tile = path[i]
		if game_map.can_move_to(fallback_tile):
			game_map.add_log(
				Enums.LogType.AI,
				"Fallback: using closer reachable tile on path: %s" % [
					format_pos_tag(fallback_tile)
				]
			)
			return fallback_tile
	# Nothing found
	game_map.add_log(Enums.LogType.AI,
		"No reachable tile on path from: %s" % [
			format_pos_tag(start_position)
		]
	)
	return start_position

func _find_best_tile_to_attack_target(
	source: MapEntity,
	target: MapEntity,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	"""
	Finds the best tile within weapon range to attack the target from, considering:
	- Movement range
	- Height advantage
	- Distance to target
	"""
	var start_pos = source.position
	var target_pos = target.position
	var best_tile: Vector2i = start_pos
	var best_score = -INF
	# Log the search context
	game_map.add_log(
		Enums.LogType.AI,
		"%s searching best attack tile near %s (range %d–%d, movement=%d)" % [
			format_mek_tag(source.entity),
			format_mek_tag(target.entity),
			min_range,
			max_range,
			max_movement
		]
	)
	# Get all the tiles this unit can reach given its movement allowance
	var reachable_tiles = game_map.get_reachable_tiles(start_pos, max_movement)
	for tile in reachable_tiles:
		var dist = tile.distance_to(target_pos)
		# Skip tiles already occupied by other units
		if game_map.is_occupied(tile):
			game_map.add_log(Enums.LogType.AI,
				"- Skipping %s -> %s: occupied" % [
					format_pos_tag(start_pos), format_pos_tag(tile)
				]
			)
			continue
		# Skip tiles outside of our weapon's usable range
		if dist < min_range or dist > max_range:
			game_map.add_log(Enums.LogType.AI,
				"- Skipping %s -> %s: out of range (distance=%d)" % [
					format_pos_tag(start_pos), format_pos_tag(tile), dist
				]
			)
			continue
		# Compute how far the unit must move to reach this tile
		var move_cost = game_map.get_path_cost(game_map.get_path(start_pos, tile))
		# Calculate the elevation difference (positive = tile is above the target)
		var height_diff = game_map.get_tile_height(tile) - game_map.get_tile_height(target_pos)
		# Determine how close we are to the ideal range (middle of min/max)
		var ideal_range = (min_range + max_range) / 2.0
		var range_penalty = abs(dist - ideal_range)
		# Final score:
		# - Favor low move cost (less effort to reach)
		# - Favor being close to ideal range
		# - Favor tiles that are higher than the target (positive height diff)
		var score = -move_cost - range_penalty + height_diff * 2.0
		game_map.add_log(
			Enums.LogType.AI,
			"- Tile %s: move_cost=%d, dist=%d, height_diff=%d -> score=%.2f" % [
				format_pos_tag(tile), move_cost, dist, height_diff, score
			]
		)
		# Keep track of the best scoring tile
		if score > best_score:
			best_score = score
			best_tile = tile
	# Log the final selected destination
	game_map.add_log(
		Enums.LogType.AI,
		"%s selects tile %s (score=%.2f) to attack %s" % [
			format_mek_tag(source.entity),
			format_pos_tag(best_tile),
			best_score,
			format_mek_tag(target.entity)
		]
	)
	return best_tile

func _select_random_movement_destination(start_position: Vector2i, max_movement: int) -> Vector2i:
	"""Selects a random valid destination within max_movement range."""
	# Generate a random offset in both X and Y directions.
	var offset_x = randi_range(-max_movement, max_movement)
	var offset_y = randi_range(-max_movement, max_movement)
	return _select_movement_destination(
		start_position,
		Vector2i(
			min(max(0, start_position.x + offset_x), game_map.map_width - 1),
			min(max(0, start_position.y + offset_y), game_map.map_height - 1),
		),
		max_movement
	)

func schedule_move_order(source: MapEntity) -> MoveOrder:
	"""Schedules a movement order for the source MapEntity."""
	var mek: Mek = source.entity
	# Adjust this based on the unit's movement capabilities.
	var detection_range = game_map.map_width + game_map.map_height
	# Adjust this based on the unit's movement capabilities.
	var desired_range = mek.get_usable_weapon_range()
	# Fallback value to prevent standing still.
	if desired_range.min == 0:
		game_map.add_log(
			Enums.LogType.AI,
			"%s get_usable_weapon_range return 0, fallback to 1" % [
				format_mek_tag(source.entity)
			]
		)
		desired_range.min = 1
		desired_range.max = 1
	game_map.add_log(
		Enums.LogType.AI,
		"%s is scheduling movement (speed=%d, detection=%d, desired_range=[%d, %d])" % [
			format_mek_tag(source.entity),
			mek.speed,
			detection_range,
			desired_range.min,
			desired_range.max
		]
	)
	# Find all high-priority targets within the search range.
	var targets = _find_high_priority_targets(source, detection_range, desired_range.min)
	game_map.add_log(
		Enums.LogType.AI,
		"%s found %d nearby units to evaluate for movement" % [
			format_mek_tag(source.entity),
			targets.size()
		]
	)
	# No valid targets to move toward.
	if targets.is_empty():
		game_map.add_log(
			Enums.LogType.AI,
			"%s found no movement-worthy targets. Choosing random repositioning." % [
				format_mek_tag(source.entity)
			]
		)
		# No valid targets, consider repositioning.
		var max_movement = mek.speed
		var start_position = source.position
		var destination = _select_random_movement_destination(start_position, max_movement)
		return MoveOrder.new(source, destination)
	else:
		# Select the best target based on priority.
		var best_target_data = _select_best_target(targets)
		var best_target = best_target_data.target
		game_map.add_log(
			Enums.LogType.AI,
			"%s selected %s as movement target (priority=%d)" % [
				format_mek_tag(source.entity),
				format_mek_tag(best_target.entity),
				best_target_data.priority
			]
		)
		# If the priority is 0, we already are at range:
		if best_target_data.priority == 0:
			game_map.add_log(
				Enums.LogType.AI,
				"%s is already at desired range to %s — no movement needed" % [
					format_mek_tag(source.entity),
					format_mek_tag(best_target.entity)
				]
			)
			return null
			
		var destination_tile = best_target.position
		if source.position.distance_to(best_target.position) <= desired_range.max:
			# Compute destination tile.
			destination_tile = _find_best_tile_to_attack_target(
				source, best_target,
				desired_range.min, desired_range.max,
				mek.speed)
		# Move to the destination.
		var destination = _select_movement_destination(
			source.position, destination_tile,
			mek.speed)
		# Create and return a new MoveOrder to the determined destination.
		return MoveOrder.new(source, destination)
