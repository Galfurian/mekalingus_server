class_name AIAttackIntentEvaluator
extends RefCounted


const DEFAULT_PROFILE_PATH: String = "res://data/ai_profiles/aggressive_brawler.tres"
const DEFAULT_MAX_LOS_TILE_CANDIDATES: int = 6

static var _profile_cache: Dictionary = {}


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	var visible_enemies: Array[MapCombatEntity] = context.get_visible_enemies()
	if visible_enemies.is_empty():
		return null

	var offensive_modules: Array[EquippedModule] = context.get_offensive_modules()
	if offensive_modules.is_empty():
		return null

	var profile: Resource = _resolve_profile(source)
	if not profile:
		return null

	var max_module_range: int = _get_max_module_range(source, offensive_modules)
	var max_candidate_distance: int = source.combatant.speed + max_module_range
	var candidate_targets: Array[Dictionary] = []

	for target: MapCombatEntity in visible_enemies:
		if target.combatant.is_dead():
			continue

		var distance: int = _manhattan_distance(source.position, target.position)
		if distance > max_candidate_distance:
			continue

		var preliminary_context: Dictionary = {
			"source": source,
			"target": target,
			"max_distance": float(max_candidate_distance),
		}
		var preliminary_score: float = profile.evaluate_preliminary(preliminary_context)
		candidate_targets.append(
			{
				"target": target,
				"preliminary_score": preliminary_score,
			}
		)

	if candidate_targets.is_empty():
		return null

	candidate_targets.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return a["preliminary_score"] > b["preliminary_score"]
	)

	var los_cache: Dictionary = {}
	var best_score: float = -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var best_destination: Vector2i = Vector2i.ZERO
	var max_targets: int = mini(
		profile.get_max_targets_to_narrow_phase(),
		candidate_targets.size(),
	)
	var expensive_ops_budget: int = profile.get_max_expensive_ops_per_frame()
	var expensive_ops: int = 0

	for candidate_index in range(max_targets):
		var candidate: Dictionary = candidate_targets[candidate_index]
		var target: MapCombatEntity = candidate["target"]

		expensive_ops = await _consume_expensive_op(context, expensive_ops_budget, expensive_ops)
		var has_los_from_source: bool = _get_or_compute_los(
			context,
			source,
			target,
			los_cache,
		)

		for equipped_module: EquippedModule in offensive_modules:
			var module_range: int = (
				equipped_module.module.module_range + source.combatant.range_modifier
			)
			var min_range: int = AIUtils.get_offensive_min_range(module_range)
			var source_distance: int = _manhattan_distance(source.position, target.position)
			var can_attack_from_source: bool = (
				has_los_from_source
				and source_distance >= min_range
				and source_distance <= module_range
			)
			var destination: Vector2i = source.position

			if not can_attack_from_source:
				expensive_ops = await _consume_expensive_op(
					context,
					expensive_ops_budget,
					expensive_ops,
				)
				var move_data: Dictionary = await _find_attack_destination_with_los(
					context,
					source,
					target,
					min_range,
					module_range,
					expensive_ops_budget,
					expensive_ops,
				)
				expensive_ops = move_data["expensive_ops"]
				if not move_data["reachable"]:
					continue
				destination = move_data["destination"]

			var score_context: Dictionary = {
				"source": source,
				"target": target,
				"module": equipped_module.module,
				"max_distance": float(max_candidate_distance),
			}
			var score: float = profile.evaluate_final(score_context)

			if can_attack_from_source:
				score += profile.in_range_los_bonus
			else:
				score += profile.reachable_bonus

			score *= lerp(
				AITuning.AGGRESSIVENESS_MIN,
				AITuning.AGGRESSIVENESS_MAX,
				context.aggressiveness,
			)

			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module
				best_destination = destination

	if not best_target:
		return null

	return AIPlanBuilder.build_plan(
		context,
		AIPlan.Intent.ATTACK,
		clampf(best_score, 0.0, 100.0),
		best_target,
		best_equipped_module,
		best_destination,
	)


static func _consume_expensive_op(
	context: AIPlanningContext,
	max_expensive_ops_per_frame: int,
	current_ops: int,
) -> int:
	current_ops += 1
	if current_ops < max_expensive_ops_per_frame:
		return current_ops

	current_ops = 0
	if context and context.game_map and context.game_map.get_tree():
		await context.game_map.get_tree().process_frame
	return current_ops


static func _get_or_compute_los(
	context: AIPlanningContext,
	source: MapCombatEntity,
	target: MapCombatEntity,
	los_cache: Dictionary,
) -> bool:
	var cache_key: String = target.combatant.uuid
	if los_cache.has(cache_key):
		return los_cache[cache_key]

	var has_los: bool = _has_line_of_sight(
		context.game_map,
		source.position,
		target.position,
	)
	los_cache[cache_key] = has_los
	return has_los


static func _find_attack_destination_with_los(
	context: AIPlanningContext,
	source: MapCombatEntity,
	target: MapCombatEntity,
	min_range: int,
	max_range: int,
	max_expensive_ops_per_frame: int,
	current_expensive_ops: int,
) -> Dictionary:
	var candidate_tiles: Array[Dictionary] = []
	for tile: Vector2i in context.get_reachable_tiles():
		if tile != source.position and context.game_map.is_occupied(tile):
			continue

		var distance_to_target: int = _manhattan_distance(tile, target.position)
		if distance_to_target < min_range or distance_to_target > max_range:
			continue

		candidate_tiles.append(
			{
				"tile": tile,
				"distance_to_source": _manhattan_distance(source.position, tile),
			}
		)

	if candidate_tiles.is_empty():
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
			"expensive_ops": current_expensive_ops,
		}

	candidate_tiles.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return a["distance_to_source"] < b["distance_to_source"]
	)

	var max_los_candidates: int = mini(DEFAULT_MAX_LOS_TILE_CANDIDATES, candidate_tiles.size())
	var destination: Vector2i = Vector2i.ZERO

	for tile_index in range(max_los_candidates):
		current_expensive_ops = await _consume_expensive_op(
			context,
			max_expensive_ops_per_frame,
			current_expensive_ops,
		)
		var tile: Vector2i = candidate_tiles[tile_index]["tile"]
		if _has_line_of_sight(context.game_map, tile, target.position):
			destination = tile
			break

	if destination == Vector2i.ZERO:
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
			"expensive_ops": current_expensive_ops,
		}

	current_expensive_ops = await _consume_expensive_op(
		context,
		max_expensive_ops_per_frame,
		current_expensive_ops,
	)
	var path: Array[Vector2i] = AIPathfinder.get_shortest_path(
		context.game_map,
		source.position,
		destination,
	)
	if path.is_empty():
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
			"expensive_ops": current_expensive_ops,
		}

	return {
		"reachable": true,
		"destination": destination,
		"expensive_ops": current_expensive_ops,
	}


static func _has_line_of_sight(game_map, from_tile: Vector2i, to_tile: Vector2i) -> bool:
	if from_tile == to_tile:
		return true

	var x0: int = from_tile.x
	var y0: int = from_tile.y
	var x1: int = to_tile.x
	var y1: int = to_tile.y
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var step_x: int = 1 if x0 < x1 else -1
	var step_y: int = 1 if y0 < y1 else -1
	var error: int = dx + dy

	while true:
		var tile: Vector2i = Vector2i(x0, y0)
		if tile != from_tile and tile != to_tile:
			if not game_map.is_in_bounds(tile):
				return false
			if game_map.is_tile_blocked_for_pathfinding(tile):
				return false
			if game_map.get_blocking_entity_at(tile):
				return false

		if x0 == x1 and y0 == y1:
			break

		var e2: int = 2 * error
		if e2 >= dy:
			error += dy
			x0 += step_x
		if e2 <= dx:
			error += dx
			y0 += step_y

	return true


static func _get_max_module_range(
	source: MapCombatEntity,
	offensive_modules: Array[EquippedModule],
) -> int:
	var max_range: int = 0
	for equipped_module: EquippedModule in offensive_modules:
		var range_with_modifier: int = (
			equipped_module.module.module_range + source.combatant.range_modifier
		)
		max_range = maxi(max_range, range_with_modifier)
	return max_range


static func _resolve_profile(source: MapCombatEntity) -> Resource:
	var profile_path: String = DEFAULT_PROFILE_PATH
	if source and source.combatant and is_instance_of(source.combatant, Mek):
		var mek: Mek = source.combatant
		if mek.ai_action_profile:
			return mek.ai_action_profile
		if mek.template and not mek.template.ai_profile_path.is_empty():
			profile_path = mek.template.ai_profile_path

	if _profile_cache.has(profile_path):
		return _profile_cache[profile_path]

	var loaded_profile: Resource = load(profile_path)
	if not loaded_profile:
		push_error("Failed to load AI profile: %s" % profile_path)
		loaded_profile = load(DEFAULT_PROFILE_PATH)

	_profile_cache[profile_path] = loaded_profile
	return loaded_profile


static func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
