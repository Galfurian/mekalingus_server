class_name AIPlanner
extends RefCounted


const ATTACK_INTENT_EVALUATOR = preload("res://scripts/data/map/controllers/strategy/intents/ai_attack_intent_evaluator.gd")
const SUPPORT_INTENT_EVALUATOR = preload("res://scripts/data/map/controllers/strategy/intents/ai_support_intent_evaluator.gd")
const RETREAT_INTENT_EVALUATOR = preload("res://scripts/data/map/controllers/strategy/intents/ai_retreat_intent_evaluator.gd")
const REPOSITION_INTENT_EVALUATOR = preload("res://scripts/data/map/controllers/strategy/intents/ai_reposition_intent_evaluator.gd")


func generate_plan(source, game_map, aggressiveness: float = 1.0) -> AIPlan:
	var context := AIPlanningContext.new(source, game_map, aggressiveness)
	var plan := AIPlan.new(source, game_map)
	var best_score := -INF
	var evaluators: Array = [
		ATTACK_INTENT_EVALUATOR,
		SUPPORT_INTENT_EVALUATOR,
		RETREAT_INTENT_EVALUATOR,
		REPOSITION_INTENT_EVALUATOR,
	]

	for evaluator in evaluators:
		var candidate: AIPlan = evaluator.evaluate(context)
		if candidate and candidate.score > best_score:
			plan = candidate
			best_score = candidate.score

	return plan
