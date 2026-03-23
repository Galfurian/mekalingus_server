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


func clear() -> void:
	"""
	Clears the planner's internal state and caches.
	"""
	AIProfileManager.clear_cache()
	turn_context.reset_context()


func _get_intent_registry() -> Array[Dictionary]:
	return [
		{
			"intent": AIPlan.Intent.ATTACK,
			"reason": "no valid attack candidate",
			"evaluator": Callable(AIAttackIntentEvaluator, "evaluate"),
		},
		{
			"intent": AIPlan.Intent.SUPPORT,
			"reason": "no valid support candidate",
			"evaluator": Callable(AISupportIntentEvaluator, "evaluate"),
		},
		{
			"intent": AIPlan.Intent.RETREAT,
			"reason": "retreat threshold not met or no tile",
			"evaluator": Callable(AIRetreatIntentEvaluator, "evaluate"),
		},
		{
			"intent": AIPlan.Intent.REPOSITION,
			"reason": "no valid directive destination",
			"evaluator": Callable(AIRepositionIntentEvaluator, "evaluate"),
		},
	]


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
	for intent_entry: Dictionary in _get_intent_registry():
		var intent: AIPlan.Intent = intent_entry["intent"]
		var evaluator: Callable = intent_entry["evaluator"]
		var unavailable_reason: String = intent_entry["reason"]

		if not evaluator.is_valid():
			decision_trace.record_intent_result(intent, null, "invalid evaluator binding")
			continue

		var candidate: AIPlan = evaluator.call(planning_context)
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
