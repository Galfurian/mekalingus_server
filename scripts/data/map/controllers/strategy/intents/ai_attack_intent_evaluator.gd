class_name AIAttackIntentEvaluator
extends RefCounted


const PLAN_BUILDER = preload("res://scripts/data/map/controllers/strategy/ai_plan_builder.gd")


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	var visible_enemies: Array[MapCombatEntity] = context.get_visible_enemies()
	if visible_enemies.is_empty():
		return null

	var best_score := -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var reachable_tiles: Array[Vector2i] = context.get_reachable_tiles()

	for equipped_module: EquippedModule in context.get_offensive_modules():
		var module_range: int = equipped_module.module.module_range + source.combatant.range_modifier
		var min_range: int = AIUtils.get_offensive_min_range(module_range)

		for target: MapCombatEntity in visible_enemies:
			if target.combatant.is_dead():
				continue

			var score: float = AIUtils.score_offensive_module_on_target(
				equipped_module.module,
				target
			)
			var distance_now: float = source.position.distance_to(target.position)
			var in_standoff_band: bool = distance_now >= min_range and distance_now <= module_range
			var can_reach_standoff_this_turn: bool = _can_reach_range_this_turn(
				reachable_tiles,
				context.game_map,
				target,
				min_range,
				module_range
			)

			if in_standoff_band:
				score += AITuning.ATTACK_STANDOFF_BONUS
			elif can_reach_standoff_this_turn:
				score += AITuning.ATTACK_REACHABLE_BONUS
			else:
				score -= AITuning.ATTACK_UNREACHABLE_PENALTY

			score *= lerp(
				AITuning.AGGRESSIVENESS_MIN,
				AITuning.AGGRESSIVENESS_MAX,
				context.aggressiveness
			)

			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module

	if not best_target:
		return null

	return PLAN_BUILDER.build_plan(
		context,
		AIPlan.Intent.ATTACK,
		clamp(best_score, 0, 100),
		best_target,
		best_equipped_module,
		Vector2i.ZERO
	)


static func _can_reach_range_this_turn(
	reachable_tiles: Array[Vector2i],
	game_map,
	target: MapCombatEntity,
	range_min: int,
	range_max: int
) -> bool:
	for tile: Vector2i in reachable_tiles:
		if game_map.is_occupied(tile):
			continue

		var distance: float = tile.distance_to(target.position)
		if distance >= range_min and distance <= range_max:
			return true

	return false
