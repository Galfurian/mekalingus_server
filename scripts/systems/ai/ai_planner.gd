class_name AIPlanner
extends RefCounted

# ============================================================================
# DATA
# ============================================================================

# Reference to the game map for pathfinding and queries.
var game_map: GameMap
# Turn context that holds shared data and caches for the entire turn.
var turn_context: AITurnContext

# ============================================================================
# PUBLIC METHODS
# ============================================================================


func _init(p_game_map: GameMap) -> void:
	assert(p_game_map, "AIPlanner requires a valid GameMap reference.")
	game_map = p_game_map
	turn_context = AITurnContext.new(p_game_map)
	assert(_validate_intent_registry(), "AIPlanner intent registry validation failed.")


func clear() -> void:
	"""
	Clears the planner's internal state and caches.
	"""
	AIProfileManager.clear_cache()
	turn_context.reset_context()


func _get_intent_registry() -> Array[AIIntentEvaluator]:
	return [
		AIAttackIntentEvaluator.new(),
		AISupportIntentEvaluator.new(),
		AIRetreatIntentEvaluator.new(),
	]


func _validate_intent_registry() -> bool:
	var registry: Array[AIIntentEvaluator] = _get_intent_registry()
	var seen_intents: Dictionary = {}

	for evaluator: AIIntentEvaluator in registry:
		if not evaluator:
			push_error("AIPlanner intent registry contains null evaluator.")
			return false

		var intent: int = int(evaluator.get_intent())
		if intent == AIPlan.Intent.NONE:
			push_error("AIPlanner evaluator cannot register AIPlan.Intent.NONE.")
			return false

		if seen_intents.has(intent):
			push_error(
				(
					"AIPlanner duplicate evaluator registration for intent '%s'."
					% AIPlan.Intent.keys()[intent]
				)
			)
			return false

		seen_intents[intent] = true

	return true


func generate_plan(source: MapCombatEntity) -> AIPlan:
	var plan: AIPlan = null
	var best_score := -INF
	AIProfileManager.warm_source(source)

	var current_turn: int = game_map.turn_manager.get_current_turn()
	var decision_trace := AIDecisionTrace.new(source, current_turn)

	_add_thought(source, "==== Turn %d ====" % current_turn)

	# Planning context that holds shared data and caches for the current planning session.
	var planning_context: AIPlanningContext = AIPlanningContext.new(turn_context, source)

	# Evaluate registered intent candidates and select the one with the highest score.
	for evaluator: AIIntentEvaluator in _get_intent_registry():
		var intent: AIPlan.Intent = evaluator.get_intent()
		var unavailable_reason: String = evaluator.get_unavailable_reason()

		var candidate: AIPlan = evaluator.evaluate_intent(planning_context)
		decision_trace.record_intent_result(intent, candidate, unavailable_reason)

		if candidate and candidate.score > best_score:
			plan = candidate
			best_score = candidate.score

	if plan:
		decision_trace.mark_selected(plan)
		plan.decision_trace = decision_trace

	_add_thought(source, "----------------------------------------")
	for line: String in decision_trace.format_summary_lines():
		_add_thought(source, line)
	if plan:
		_add_thought(source, "Plan selected:")
		_add_thought(source, "%s" % str(plan))
	else:
		_add_thought(source, "No valid plan selected")

	_add_thought(source, "==== End of Planning ====")

	return plan


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
