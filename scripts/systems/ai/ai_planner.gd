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
	turn_context.reset_context()


func generate_plan(source: MapCombatEntity) -> AIPlan:
	var plan: AIPlan = null
	var best_score := -INF

	# Planning context that holds shared data and caches for the current planning session.
	var planning_context: AIPlanningContext = AIPlanningContext.new(turn_context, source)

	# Evaluate different intent candidates and select the one with the highest score.
	var attack_candidate: AIPlan = AIAttackIntentEvaluator.evaluate(planning_context)
	if attack_candidate and attack_candidate.score > best_score:
		plan = attack_candidate
		best_score = attack_candidate.score

	var support_candidate: AIPlan = AISupportIntentEvaluator.evaluate(planning_context)
	if support_candidate and support_candidate.score > best_score:
		plan = support_candidate
		best_score = support_candidate.score

	var retreat_candidate: AIPlan = AIRetreatIntentEvaluator.evaluate(planning_context)
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
