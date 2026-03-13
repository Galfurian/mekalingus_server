class_name AIPlanner
extends RefCounted


func generate_plan(
	source,
	game_map,
	aggressiveness: float = 1.0,
	turn_context: RefCounted = null,
) -> AIPlan:
	var context := AIPlanningContext.new(source, game_map, aggressiveness, turn_context)
	var plan: AIPlan = null
	var best_score := -INF
	var evaluators: Array = [
		AIAttackIntentEvaluator,
		AISupportIntentEvaluator,
		AIRetreatIntentEvaluator,
		AIRepositionIntentEvaluator,
	]

	for evaluator in evaluators:
		var candidate: AIPlan = evaluator.evaluate(context)
		if candidate and candidate.score > best_score:
			plan = candidate
			best_score = candidate.score

	return plan
