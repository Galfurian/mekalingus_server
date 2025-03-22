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

func _determine_best_utility_module_target(source: MapEntity, module: ItemModule) -> Dictionary:
	"""Determines the best target and priority for the given utility module."""
	var best_target: MapEntity = null
	var highest_priority: int = 0
	for effect in module.effects:
		var candidates = _get_utility_effect_targets(effect, source, module.module_range)
		for candidate in candidates:
			# Skip evaluation if the effect is already active on this Mek.
			if candidate.entity.has_effect_type(effect.type):
				game_map.add_log(
					Enums.LogType.AI,
					"    %s, skipped %s: already has active effect %s" % [
						source.entity.template.name,
						candidate.entity.template.name,
						Enums.EffectType.keys()[effect.type]
					]
				)
				continue
			var priority = _evaluate_utility_effect_priority(candidate, effect)
			# Apply power penalty if using this module would drain the Mek
			if not module.passive and module.power_on_use > 0:
				var power_after_use = candidate.entity.power - module.power_on_use
				var remaining_ratio = float(power_after_use) / float(candidate.entity.max_power)
				var penalty_applied = 0
				if remaining_ratio < 0.25:
					penalty_applied = 5
				elif remaining_ratio < 0.5:
					penalty_applied = 3
				elif remaining_ratio < 0.75:
					penalty_applied = 1
				priority = max(priority, priority - penalty_applied)
				if penalty_applied > 0:
					game_map.add_log(
						Enums.LogType.AI,
						"    %s, penalized priority for %s: power left=%d (%.2f), penalty=%d" % [
							candidate.entity.template.name,
							module.name,
							power_after_use,
							remaining_ratio,
							penalty_applied
						]
					)
			game_map.add_log(
				Enums.LogType.AI,
				"    %s, evaluated %s on %s: effect=%s, priority=%d" % [
					source.entity.template.name,
					module.name,
					candidate.entity.template.name,
					Enums.EffectType.keys()[effect.type],
					priority
				]
			)
			
			if priority > highest_priority:
				highest_priority = priority
				best_target = candidate
	
	if best_target:
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"    %s has selected target %s for module %s (priority %d)" % [
				source.entity.template.name,
				best_target.entity.template.name,
				module.name,
				highest_priority
			]
		)
	#else:
		#game_map.add_log(
			#Enums.LogType.SYSTEM,
			#"    %s has no suitable target found for its module %s" % [
				#source.entity.template.name,
				#module.name
			#]
		#)
	return {"target": best_target, "priority": highest_priority}

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
			# Check if the module is on cooldown or if the Mek lacks power to use it.
			if mek.cooldown_manager.is_on_cooldown(item, module) or mek.power < module.power_on_use:
				continue
			# If all checks pass, add the module to the usable list.
			usable_modules.append({"item": item, "module": module})
	return usable_modules

func schedule_utility_module_order(source: MapEntity) -> UseModuleOrder:
	"""Schedules an utility use action for the AI-controlled Mek."""
	var mek: Mek = source.entity
	var usable_modules = _find_usable_utility_modules(mek)

	var best_module: Dictionary = {"item": null, "module": null}
	var best_target: MapEntity = null
	var highest_priority: int = 0

	for module in usable_modules:
		var result = _determine_best_utility_module_target(source, module.module)
		var adjusted_priority = result.priority
		if result.priority > 0:
			adjusted_priority += int(module.module.cooldown / 2)
		game_map.add_log(
			Enums.LogType.AI,
			"    %s is evaluating module %s: raw priority=%d%s, cooldown=%d, adjusted=%d" % [
				source.entity.template.name,
				module.module.name,
				result.priority,
				" + cooldown bonus" if result.priority > 0 else "",
				module.module.cooldown,
				adjusted_priority
			]
		)
		if adjusted_priority > highest_priority:
			highest_priority = adjusted_priority
			best_module = module
			best_target = result.target
	if best_module.item and best_module.module and best_target and highest_priority > 0:
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"%s selected utility module %s targeting %s (final priority=%d)" % [
				source.entity.template.name,
				best_module.module.name,
				best_target.entity.template.name,
				highest_priority
			]
		)
		return UseModuleOrder.new(source, best_target, best_module.item, best_module.module)
	game_map.add_log(
		Enums.LogType.SYSTEM,
		"%s did not select any utility module this turn." % source.entity.template.name
	)
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

func _determine_best_offensive_module_target(source: MapEntity, module: ItemModule) -> Dictionary:
	"""Determines the best target and priority for the given offensive module."""
	var best_target: MapEntity = null
	var highest_priority: int = -1
	var candidates = game_map.get_units_in_range(source, source.position, module.module_range, false, true)
	game_map.add_log(
		Enums.LogType.AI,
		"    %s evaluating %s: found %d candidates" % [
			source.entity.template.name,
			module.name,
			candidates.size()
		]
	)
	for target in candidates:
		if target == source:
			continue
		for effect in module.effects:
			var priority = _evaluate_offensive_effect_priority(target, effect)
			game_map.add_log(
				Enums.LogType.AI,
				"    %s, evaluated %s against %s: effect=%s, priority=%d" % [
					source.entity.template.name,
					module.name,
					target.entity.template.name,
					Enums.EffectType.keys()[effect.type],
					priority
				]
			)
			if priority > highest_priority:
				highest_priority = priority
				best_target = target
	if best_target:
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"    %s has selected target %s for module %s (priority %d)" % [
				source.entity.template.name,
				best_target.entity.template.name,
				module.name,
				highest_priority
			]
		)
	#else:
		#game_map.add_log(
			#Enums.LogType.SYSTEM,
			#"    %s has no suitable target found for its module %s" % [
				#source.entity.template.name,
				#module.name
			#]
		#)
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
			# Check if the module is on cooldown or if the Mek lacks power to use it.
			if mek.cooldown_manager.is_on_cooldown(item, module) or mek.power < module.power_on_use:
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
	for module in usable_modules:
		game_map.add_log(
			Enums.LogType.AI,
			"    %s is evaluating offensive module %s" % [
				source.entity.template.name,
				module.module.name
			]
		)
		var result = _determine_best_offensive_module_target(source, module.module)
		if result.priority > highest_priority:
			highest_priority = result.priority
			best_module = module
			best_target = result.target
	
	# If a valid module and target were found, queue a use order.
	if best_module.item and best_module.module and best_target:
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"%s selected offensive module %s targeting %s (final priority=%d)" % [
				source.entity.template.name,
				best_module.module.name,
				best_target.entity.template.name,
				highest_priority
			]
		)
		return UseModuleOrder.new(source, best_target, best_module.item, best_module.module)
	else:
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"%s did not select any offensive module this turn." % source.entity.template.name
		)
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
		"    %s evaluated movement toward %s: distance=%d, is_enemy=%s, priority=%d" % [
			source.entity.template.name,
			target.entity.template.name,
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
	"""Determines the best tile to move closer to the target using A* pathfinding."""
	# Get the path using the GameMap A*.
	var path: Array[Vector2i] = game_map.get_path(start_position, target_position)
	# If there's no path or the path is too short, fallback.
	if path.is_empty() or path.size() <= 1:
		game_map.add_log(
			Enums.LogType.AI,
			"No valid path from %s to %s" % [str(start_position), str(target_position)]
		)
		return start_position
	# Determine how far we can go: up to max_movement, but not past the end.
	var steps = min(max_movement, path.size() - 1)
	var destination = path[steps]
	# Ensure the destination is valid.
	if game_map.can_move_to(destination):
		#game_map.add_log(
			#Enums.LogType.SYSTEM,
			#"Moving from %s toward %s → destination: %s" % [str(start_position), str(target_position), str(destination)]
		#)
		return destination
	# If we can't move to the destination tile, fallback to previous steps in the path.
	for i in range(steps - 1, 0, -1):
		var fallback_tile = path[i]
		if game_map.can_move_to(fallback_tile):
			game_map.add_log(
				Enums.LogType.SYSTEM,
				"Fallback: using closer reachable tile on path: %s" % str(fallback_tile)
			)
			return fallback_tile
	# Nothing found, fallback to current position.
	game_map.add_log(
		Enums.LogType.SYSTEM,
		"No reachable tile on path from: %s" % str(start_position)
	)
	return start_position

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
	var desired_range = mek.get_max_usable_weapon_range()
	# Fallback value to prevent standing still.
	if desired_range == 0:
		game_map.add_log(
			Enums.LogType.AI,
			"    %s get_max_usable_weapon_range return 0, fallback to 1" % [
				source.entity.template.name
			]
		)
		desired_range = 1
	game_map.add_log(
		Enums.LogType.AI,
		"%s is scheduling movement (speed=%d, detection=%d, desired_range=%d)" % [
			source.entity.template.name,
			mek.speed,
			detection_range,
			desired_range
		]
	)
	# Find all high-priority targets within the search range.
	var targets = _find_high_priority_targets(source, detection_range, desired_range)
	game_map.add_log(
		Enums.LogType.AI,
		"%s found %d nearby units to evaluate for movement" % [
			source.entity.template.name,
			targets.size()
		]
	)
	# No valid targets to move toward.
	if targets.is_empty():
		game_map.add_log(
			Enums.LogType.SYSTEM,
			"%s found no movement-worthy targets. Choosing random repositioning." % source.entity.template.name
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
			Enums.LogType.SYSTEM,
			"%s selected %s as movement target (priority=%d)" % [
				source.entity.template.name,
				best_target.entity.template.name,
				best_target_data.priority
			]
		)
		# If the priority is 0, we already are at range:
		if best_target_data.priority == 0:
			game_map.add_log(
				Enums.LogType.SYSTEM,
				"%s is already at desired range to %s — no movement needed" % [
					source.entity.template.name,
					best_target.entity.template.name
				]
			)
			return null
		# Adjust this based on the unit's movement capabilities.
		var max_movement = mek.speed
		# Calculate the movement destination based on the best target.
		var start_position  = source.position
		var target_position = best_target.position
		var destination = _select_movement_destination(start_position, target_position, max_movement)
		# Create and return a new MoveOrder to the determined destination.
		return MoveOrder.new(source, destination)
