class_name AISupportIntentEvaluator
extends RefCounted


const TacticalBrainResolver = preload(
	"res://scripts/data/map/controllers/strategy/ai_tactical_brain_resolver.gd"
)


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	var profile: AIActionProfile = TacticalBrainResolver.resolve_support_profile(source)
	if not profile:
		return null

	var utility_modules: Array[EquippedModule] = context.get_utility_modules()
	if utility_modules.is_empty():
		return null

	var allies_with_self: Array[MapCombatEntity] = context.get_allies_with_self()
	var max_module_range: int = _get_max_module_range(source, utility_modules)
	var max_candidate_distance: int = source.combatant.speed + max_module_range
	var candidate_targets: Array[Dictionary] = []

	for target: MapCombatEntity in allies_with_self:
		if target.combatant.is_dead():
			continue

		var preliminary_context: Dictionary = {
			"source": source,
			"target": target,
			"planning_context": context,
			"tile": source.position,
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

	var best_score: float = -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var best_destination: Vector2i = source.position
	var max_targets: int = mini(
		profile.get_max_targets_to_narrow_phase(),
		candidate_targets.size(),
	)
	var expensive_ops_budget: int = profile.get_max_expensive_ops_per_frame()
	var expensive_ops: int = 0

	for candidate_index in range(max_targets):
		var candidate: Dictionary = candidate_targets[candidate_index]
		var target: MapCombatEntity = candidate["target"]

		for equipped_module: EquippedModule in utility_modules:
			if not _can_module_target(equipped_module.module, source, target):
				continue

			var module_range: int = (
				equipped_module.module.module_range + source.combatant.range_modifier
			)
			var source_distance: int = _manhattan_distance(source.position, target.position)
			var can_use_from_source: bool = _is_in_range(
				source_distance,
				module_range,
				target,
				source,
			)
			var destination: Vector2i = source.position

			if not can_use_from_source:
				expensive_ops = await _consume_expensive_op(context, expensive_ops_budget, expensive_ops)
				var move_data: Dictionary = await _find_support_destination(
					context,
					source,
					target,
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
				"planning_context": context,
				"tile": destination,
				"max_distance": float(max_candidate_distance),
			}
			var score: float = profile.evaluate_final(score_context)
			if can_use_from_source:
				score += profile.in_range_los_bonus
			else:
				score += profile.reachable_bonus

			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module
				best_destination = destination

	if not best_target:
		return null

	return AIPlanBuilder.build_plan(
		context,
		AIPlan.Intent.SUPPORT,
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


static func _find_support_destination(
	context: AIPlanningContext,
	source: MapCombatEntity,
	target: MapCombatEntity,
	module_range: int,
	max_expensive_ops_per_frame: int,
	current_expensive_ops: int,
) -> Dictionary:
	var candidate_tiles: Array[Dictionary] = []
	for tile: Vector2i in context.get_reachable_tiles():
		if tile != source.position and context.game_map.is_occupied(tile):
			continue

		var distance_to_target: int = _manhattan_distance(tile, target.position)
		if distance_to_target > module_range:
			continue

		current_expensive_ops = await _consume_expensive_op(
			context,
			max_expensive_ops_per_frame,
			current_expensive_ops,
		)
		var tile_threat: float = context.get_threat(tile)
		candidate_tiles.append(
			{
				"tile": tile,
				"tile_threat": tile_threat,
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
			if a["tile_threat"] == b["tile_threat"]:
				return a["distance_to_source"] < b["distance_to_source"]
			return a["tile_threat"] < b["tile_threat"]
	)

	var destination: Vector2i = candidate_tiles[0]["tile"]
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


static func _is_in_range(
	distance: int,
	module_range: int,
	target: MapCombatEntity,
	source: MapCombatEntity,
) -> bool:
	if target == source:
		return true
	return distance <= module_range


static func _can_module_target(
	module: ItemModule,
	source: MapCombatEntity,
	target: MapCombatEntity,
) -> bool:
	for effect: BaseEffect in module.effects:
		match effect.target:
			Enums.TargetType.SELF:
				if target == source:
					return true
			Enums.TargetType.ALLY:
				if target.owner == source.owner and target != source:
					return true
			Enums.TargetType.AREA:
				return true
	return false


static func _get_max_module_range(
	source: MapCombatEntity,
	utility_modules: Array[EquippedModule],
) -> int:
	var max_range: int = 0
	for equipped_module: EquippedModule in utility_modules:
		var range_with_modifier: int = (
			equipped_module.module.module_range + source.combatant.range_modifier
		)
		max_range = maxi(max_range, range_with_modifier)
	return max_range


static func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
