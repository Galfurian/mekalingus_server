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


func generate_plan(source: MapCombatEntity) -> AIPlan:
	var plan: AIPlan = null
	var best_score := -INF
	AIProfileManager.warm_source(source)

	var current_turn: int = game_map.turn_manager.get_current_turn()
	var decision_trace := AIDecisionTrace.new(source, current_turn)

	_add_thought(source, "==== Turn %d ====" % current_turn)

	# Planning context that holds shared data and caches for the current planning session.
	var planning_context: AIPlanningContext = AIPlanningContext.new(turn_context, source)

	# Evaluate different intent candidates and select the one with the highest score.
	var attack_candidate: AIPlan = AIAttackIntentEvaluator.evaluate(planning_context)
	decision_trace.record_intent_result(
		AIPlan.Intent.ATTACK,
		attack_candidate,
		"no valid attack candidate",
	)
	if attack_candidate and attack_candidate.score > best_score:
		plan = attack_candidate
		best_score = attack_candidate.score

	var support_candidate: AIPlan = AISupportIntentEvaluator.evaluate(planning_context)
	decision_trace.record_intent_result(
		AIPlan.Intent.SUPPORT,
		support_candidate,
		"no valid support candidate",
	)
	if support_candidate and support_candidate.score > best_score:
		plan = support_candidate
		best_score = support_candidate.score

	var retreat_candidate: AIPlan = AIRetreatIntentEvaluator.evaluate(planning_context)
	decision_trace.record_intent_result(
		AIPlan.Intent.RETREAT,
		retreat_candidate,
		"retreat threshold not met or no tile",
	)
	if retreat_candidate and retreat_candidate.score > best_score:
		plan = retreat_candidate
		best_score = retreat_candidate.score

	var reposition_candidate: AIPlan = AIRepositionIntentEvaluator.evaluate(planning_context)
	decision_trace.record_intent_result(
		AIPlan.Intent.REPOSITION,
		reposition_candidate,
		"no valid directive destination",
	)
	if reposition_candidate and reposition_candidate.score > best_score:
		plan = reposition_candidate
		best_score = reposition_candidate.score

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
