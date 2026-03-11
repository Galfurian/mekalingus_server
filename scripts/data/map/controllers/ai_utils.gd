extends Node

const AIPathfinderScript = preload("res://scripts/data/map/controllers/pathfinding/ai_pathfinder.gd")
const AIUnitQueriesScript = preload("res://scripts/data/map/controllers/ai_unit_queries.gd")
const AIThreatEvaluatorScript = preload("res://scripts/data/map/controllers/ai_threat_evaluator.gd")

# =====================================================================
# PRIORITY CALCULATION FUNCTIONS
# =====================================================================

func evaluate_utility_effect_priority(target, effect: ItemEffect) -> int:
	"""
	Calculates a priority score for a specific effect on a specific target.
	"""
	# Initialize the priority score.
	var priority = 0
	# Check the effect type and assign a score.
	match effect.type:
		# Repairs (High priority if the related stat is low)
		Enums.EffectType.HEALTH_REPAIR:
			if target.combatant.health < target.combatant.max_health * 0.4:
				priority += 16
			elif target.combatant.health < target.combatant.max_health * 0.7:
				priority += 8
		Enums.EffectType.SHIELD_REPAIR:
			if target.combatant.shield < target.combatant.max_shield * 0.4:
				priority += 16
			elif target.combatant.shield < target.combatant.max_shield * 0.7:
				priority += 8
		Enums.EffectType.ARMOR_REPAIR:
			if target.combatant.armor < target.combatant.max_armor * 0.4:
				priority += 16
			elif target.combatant.armor < target.combatant.max_armor * 0.7:
				priority += 8
		# Max stat modifiers (Lower priority than direct repairs)
		Enums.EffectType.HEALTH_MODIFIER:
			priority += 4 if target.combatant.health < target.combatant.max_health * 0.4 else 2
		Enums.EffectType.SHIELD_MODIFIER:
			priority += 4 if target.combatant.shield < target.combatant.max_shield * 0.4 else 2
		Enums.EffectType.ARMOR_MODIFIER:
			priority += 4 if target.combatant.armor < target.combatant.max_armor * 0.4 else 2
		Enums.EffectType.POWER_MODIFIER:
			priority += 3 if target.combatant.power < target.combatant.max_power * 0.4 else 1
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
			priority += 5 if target.combatant.health < target.combatant.max_health * 0.3 else 3
		Enums.EffectType.SHIELD_REGEN:
			priority += 5 if target.combatant.shield < target.combatant.max_shield * 0.3 else 3
		Enums.EffectType.ARMOR_REGEN:
			priority += 5 if target.combatant.armor < target.combatant.max_armor * 0.3 else 3
		Enums.EffectType.POWER_REGEN:
			priority += 5 if target.combatant.power < target.combatant.max_power * 0.3 else 3
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


func evaluate_offensive_effect_priority(target, effect: ItemEffect) -> int:
	"""
	Assigns a priority value to an offensive effect targeting a specific entity.
	"""
	var priority = 0

	# Factor 1: Threat level by size (larger = more threatening)

	priority += (target.combatant.template.size + 1) * (target.combatant.template.size + 1)

	# Factor 2: Target state sensitivity.

	if target.combatant.health < target.combatant.max_health * 0.25:
		priority += 10
	elif target.combatant.health < target.combatant.max_health * 0.5:
		priority += 5

	if target.combatant.shield < target.combatant.max_shield * 0.25:
		priority += 6
	elif target.combatant.shield < target.combatant.max_shield * 0.5:
		priority += 3

	if target.combatant.armor < target.combatant.max_armor * 0.25:
		priority += 4
	elif target.combatant.armor < target.combatant.max_armor * 0.5:
		priority += 2

	# Factor 3: Effect-Specific Logic
	
	match effect.type:
		Enums.EffectType.DAMAGE:
			# Scale based on raw damage amount.
			priority += clamp(effect.amount / 10.0, 1, 10)

		Enums.EffectType.DAMAGE_OVER_TIME:
			var existing_effects: Array[ActiveEffect] = target.combatant.active_effect_manager.get_effects_by_type(effect.type)
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
	source,
	target
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


func score_offensive_module_on_target(module: ItemModule, target) -> int:
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
	return AIPathfinderScript.normalize_position(vector)


func round_position(vector: Vector2) -> Vector2i:
	return AIPathfinderScript.round_position(vector)


func get_shortest_path(game_map, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	return AIPathfinderScript.get_shortest_path(game_map, start, end)


func get_path_cost(game_map, path) -> float:
	return AIPathfinderScript.get_path_cost(game_map, path)


func get_tiles_in_range(game_map, position: Vector2i, max_range: int) -> Array[Vector2i]:
	return AIPathfinderScript.get_tiles_in_range(game_map, position, max_range)


func get_reachable_tiles(game_map, start: Vector2i, max_cost: int) -> Array[Vector2i]:
	return AIPathfinderScript.get_reachable_tiles(game_map, start, max_cost)


func get_distance(game_map, from: Vector2i, to: Vector2i) -> float:
	return AIPathfinderScript.get_distance(game_map, from, to)


func find_furthest_progress_along_path(
	game_map,
	start: Vector2i,
	target: Vector2i,
	max_movement: int
) -> Vector2i:
	return AIPathfinderScript.find_furthest_progress_along_path(game_map, start, target, max_movement)


func find_closest_reachable_tile(
	game_map,
	source,
	target,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	return AIPathfinderScript.find_closest_reachable_tile(
		game_map,
		source,
		target,
		min_range,
		max_range,
		max_movement
	)


func find_best_attack_tile(
	game_map,
	source,
	target,
	min_range: int,
	max_range: int,
	max_movement: int
) -> Vector2i:
	return AIPathfinderScript.find_best_attack_tile(
		game_map,
		source,
		target,
		min_range,
		max_range,
		max_movement
	)


func find_random_reachable_tile(game_map, start: Vector2i, max_cost: int) -> Vector2i:
	return AIPathfinderScript.find_random_reachable_tile(game_map, start, max_cost)


# =====================================================================
# UNIT UTILITY FUNCTIONS
# =====================================================================

func get_all_units(game_map) -> Array:
	return AIUnitQueriesScript.get_all_units(game_map)


func get_units_in_range(
	game_map,
	source,
	position: Vector2i,
	radius: int,
	include_allies: bool = true,
	include_enemies: bool = true,
	exclude_units: Array = []
) -> Array:
	return AIUnitQueriesScript.get_units_in_range(
		game_map,
		source,
		position,
		radius,
		include_allies,
		include_enemies,
		exclude_units
	)


func get_enemies_in_range(
	game_map,
	source,
	radius: int,
	exclude_units: Array = []
) -> Array:
	return AIUnitQueriesScript.get_enemies_in_range(game_map, source, radius, exclude_units)


func get_allies_in_range(
	game_map,
	source,
	radius: int,
	exclude_units: Array = []
) -> Array:
	return AIUnitQueriesScript.get_allies_in_range(game_map, source, radius, exclude_units)


func get_threat_level(game_map, tile: Vector2i, source) -> float:
	return AIThreatEvaluatorScript.get_threat_level(game_map, tile, source)


func can_reach_target_this_turn(
	game_map,
	source,
	target,
	range_min: int,
	range_max: int,
	max_movement: int
) -> bool:
	return AIThreatEvaluatorScript.can_reach_target_this_turn(
		game_map,
		source,
		target,
		range_min,
		range_max,
		max_movement
	)


func get_most_vulnerable_enemy(game_map, source, max_distance: int) -> MapCombatEntity:
	return AIUnitQueriesScript.get_most_vulnerable_enemy(game_map, source, max_distance)
