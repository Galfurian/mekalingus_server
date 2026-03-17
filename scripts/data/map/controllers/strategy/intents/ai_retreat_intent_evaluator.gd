class_name AIRetreatIntentEvaluator
extends RefCounted


const TacticalBrainResolver = preload(
	"res://scripts/data/map/controllers/strategy/ai_tactical_brain_resolver.gd"
)


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	if not source.can_move():
		return null

	var profile: AIActionProfile = TacticalBrainResolver.resolve_retreat_profile(source)
	if not profile:
		return null

	var reachable_tiles: Array[Vector2i] = context.get_reachable_tiles()
	if reachable_tiles.is_empty():
		return null

	var utility_modules: Array[EquippedModule] = context.get_utility_modules()
	var candidate_tiles: Array[Dictionary] = []

	for tile: Vector2i in reachable_tiles:
		if tile != source.position and context.game_map.is_occupied(tile):
			continue

		var preliminary_context: Dictionary = {
			"source": source,
			"target": source,
			"planning_context": context,
			"tile": tile,
		}
		var preliminary_score: float = profile.evaluate_preliminary(preliminary_context)
		candidate_tiles.append(
			{
				"tile": tile,
				"preliminary_score": preliminary_score,
			}
		)

	if candidate_tiles.is_empty():
		return null

	candidate_tiles.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return a["preliminary_score"] > b["preliminary_score"]
	)

	var best_tile: Vector2i = source.position
	var best_score: float = -INF
	var best_equipped_module: EquippedModule = null
	var max_targets: int = mini(profile.get_max_targets_to_narrow_phase(), candidate_tiles.size())
	var expensive_ops_budget: int = profile.get_max_expensive_ops_per_frame()
	var expensive_ops: int = 0

	for candidate_index in range(max_targets):
		var candidate: Dictionary = candidate_tiles[candidate_index]
		var tile: Vector2i = candidate["tile"]

		if tile != source.position:
			expensive_ops = await _consume_expensive_op(context, expensive_ops_budget, expensive_ops)
			var path: Array[Vector2i] = AIPathfinder.get_shortest_path(
				context.game_map,
				source.position,
				tile,
			)
			if path.is_empty():
				continue

		var best_module_score: float = -INF
		var selected_module: EquippedModule = null
		for equipped_module: EquippedModule in utility_modules:
			if not _can_module_target_self(equipped_module.module, source):
				continue

			var module_context: Dictionary = {
				"source": source,
				"target": source,
				"module": equipped_module.module,
				"planning_context": context,
				"tile": tile,
			}
			var module_score: float = profile.evaluate_final(module_context)
			if module_score > best_module_score:
				best_module_score = module_score
				selected_module = equipped_module

		var score_context: Dictionary = {
			"source": source,
			"target": source,
			"planning_context": context,
			"tile": tile,
		}
		var score: float = profile.evaluate_final(score_context)
		if selected_module:
			score = maxf(score, best_module_score)
		if tile != source.position:
			score += profile.reachable_bonus

		if score > best_score:
			best_score = score
			best_tile = tile
			best_equipped_module = selected_module

	if best_tile == source.position:
		return null

	return AIPlanBuilder.build_plan(
		context,
		AIPlan.Intent.RETREAT,
		clampf(best_score, 0.0, 100.0),
		source,
		best_equipped_module,
		best_tile,
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


static func _can_module_target_self(module: ItemModule, _source: MapCombatEntity) -> bool:
	for effect: BaseEffect in module.effects:
		if effect.target == Enums.TargetType.SELF or effect.target == Enums.TargetType.AREA:
			return true
	return false
