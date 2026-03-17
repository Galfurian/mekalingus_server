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

	var attack_candidate: AIPlan = await AIAttackIntentEvaluator.evaluate(context)
	if attack_candidate and attack_candidate.score > best_score:
		plan = attack_candidate
		best_score = attack_candidate.score

	var support_candidate: AIPlan = AISupportIntentEvaluator.evaluate(context)
	if support_candidate and support_candidate.score > best_score:
		plan = support_candidate
		best_score = support_candidate.score

	var retreat_candidate: AIPlan = AIRetreatIntentEvaluator.evaluate(context)
	if retreat_candidate and retreat_candidate.score > best_score:
		plan = retreat_candidate
		best_score = retreat_candidate.score

	var reposition_candidate: AIPlan = AIRepositionIntentEvaluator.evaluate(context)
	if reposition_candidate and reposition_candidate.score > best_score:
		plan = reposition_candidate
		best_score = reposition_candidate.score

	return plan
