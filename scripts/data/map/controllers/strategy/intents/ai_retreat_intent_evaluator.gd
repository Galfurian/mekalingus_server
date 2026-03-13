class_name AIRetreatIntentEvaluator
extends RefCounted


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	if not source.can_move():
		return null

	var max_survivability: float = float(
		source.combatant.max_health + source.combatant.max_armor + source.combatant.max_shield
	)
	if max_survivability <= 0:
		return null

	var current_survivability: float = float(
		source.combatant.health + source.combatant.armor + source.combatant.shield
	)
	var health_ratio: float = current_survivability / max_survivability
	var current_threat: float = context.get_threat(source.position)

	if (
		health_ratio > AITuning.RETREAT_HEALTH_THRESHOLD
		and current_threat < AITuning.RETREAT_THREAT_THRESHOLD
	):
		return null

	var best_tile: Vector2i = source.position
	var best_score: float = INF
	var best_equipped_module: EquippedModule = null
	var best_module_score: float = -INF

	for tile: Vector2i in context.get_reachable_tiles():
		if context.game_map.is_occupied(tile):
			continue

		var threat: float = context.get_threat(tile)
		if threat < best_score:
			best_score = threat
			best_tile = tile

	for equipped_module: EquippedModule in context.get_utility_modules():
		var utility_score: float = AIUtils.score_utility_module_on_target(
			equipped_module.module, source, source
		)
		if utility_score > best_module_score:
			best_module_score = utility_score
			best_equipped_module = equipped_module

	if best_tile == source.position:
		return null

	var retreat_score: float = clamp(100.0 - best_score, 0.0, 100.0)
	return AIPlanBuilder.build_plan(
		context, AIPlan.Intent.RETREAT, retreat_score, source, best_equipped_module, best_tile
	)
