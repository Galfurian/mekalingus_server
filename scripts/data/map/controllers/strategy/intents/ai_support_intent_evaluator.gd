class_name AISupportIntentEvaluator
extends RefCounted


const PLAN_BUILDER = preload("res://scripts/data/map/controllers/strategy/ai_plan_builder.gd")


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	var best_score := -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var allies_with_self: Array[MapCombatEntity] = context.get_allies_with_self()

	for equipped_module: EquippedModule in context.get_utility_modules():
		for target: MapCombatEntity in allies_with_self:
			if target.combatant.is_dead():
				continue

			var score: float = AIUtils.score_utility_module_on_target(
				equipped_module.module,
				source,
				target
			)
			if source == target:
				score *= 1.5

			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module

	if not best_target:
		return null

	return PLAN_BUILDER.build_plan(
		context,
		AIPlan.Intent.SUPPORT,
		clamp(best_score, 0, 100),
		best_target,
		best_equipped_module,
		Vector2i.ZERO
	)
