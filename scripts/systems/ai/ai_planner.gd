class_name AIPlanner
extends RefCounted


func generate_plan(
	source,
	game_map,
	turn_context: RefCounted = null,
) -> AIPlan:
	var context := AIPlanningContext.new(source, game_map, turn_context)
	var plan: AIPlan = null
	var best_score := -INF

	var attack_candidate: AIPlan = AIAttackIntentEvaluator.evaluate(context)
	if attack_candidate:
		source.combatant.add_ai_thought("Intent ATTACK scored %.2f" % attack_candidate.score)
	else:
		source.combatant.add_ai_thought("Intent ATTACK unavailable")
	if attack_candidate and attack_candidate.score > best_score:
		plan = attack_candidate
		best_score = attack_candidate.score

	var support_candidate: AIPlan = AISupportIntentEvaluator.evaluate(context)
	if support_candidate:
		source.combatant.add_ai_thought("Intent SUPPORT scored %.2f" % support_candidate.score)
	else:
		source.combatant.add_ai_thought("Intent SUPPORT unavailable")
	if support_candidate and support_candidate.score > best_score:
		plan = support_candidate
		best_score = support_candidate.score

	var retreat_candidate: AIPlan = AIRetreatIntentEvaluator.evaluate(context)
	if retreat_candidate:
		source.combatant.add_ai_thought("Intent RETREAT scored %.2f" % retreat_candidate.score)
	else:
		source.combatant.add_ai_thought("Intent RETREAT unavailable")
	if retreat_candidate and retreat_candidate.score > best_score:
		plan = retreat_candidate
		best_score = retreat_candidate.score

	if plan:
		source.combatant.add_ai_thought(
			"Selected intent %s with score %.2f" % [AIPlan.Intent.keys()[plan.intent], plan.score]
		)
	else:
		source.combatant.add_ai_thought("No valid plan selected")

	return plan
