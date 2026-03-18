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

	if plan:
		_add_thought(
			source,
			"Selected intent %s with score %.2f" % [AIPlan.Intent.keys()[plan.intent], plan.score]
		)
	else:
		_add_thought(source, "No valid plan selected")

	return plan


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
