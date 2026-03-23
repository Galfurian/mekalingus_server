class_name AIPlanner
extends RefCounted

# ============================================================================
# DATA
# ============================================================================

const ATTACK_INTENT_EVALUATOR = preload(
	"res://scripts/systems/ai/intents/ai_attack_intent_evaluator.gd"
)
const SUPPORT_INTENT_EVALUATOR = preload(
	"res://scripts/systems/ai/intents/ai_support_intent_evaluator.gd"
)
const RETREAT_INTENT_EVALUATOR = preload(
	"res://scripts/systems/ai/intents/ai_retreat_intent_evaluator.gd"
)
const REPOSITION_INTENT_EVALUATOR = preload(
	"res://scripts/systems/ai/intents/ai_reposition_intent_evaluator.gd"
)

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
			"evaluator": ATTACK_INTENT_EVALUATOR.new(),
		},
		{
			"evaluator": SUPPORT_INTENT_EVALUATOR.new(),
		},
		{
			"evaluator": RETREAT_INTENT_EVALUATOR.new(),
		},
		{
			"evaluator": REPOSITION_INTENT_EVALUATOR.new(),
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
		var evaluator = intent_entry["evaluator"]
		if not evaluator:
			decision_trace.record_intent_result(
				AIPlan.Intent.NONE,
				null,
				"missing evaluator instance",
			)
			continue

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
