class_name AIRepositionIntentEvaluator
extends RefCounted

const INTENT_LABEL: String = "Reposition"


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating intent %10s -----" % [INTENT_LABEL.to_upper()]
	)
	var source: MapCombatEntity = planning_context.source
	if not source.can_move():
		_log(source, "intent unavailable: cannot move")
		return null
	if not planning_context.get_enemies().is_empty():
		_log(source, "intent unavailable: enemies visible")
		return null

	var ai_profile: AIProfile = AIProfileManager.get_profile(source)
	if not ai_profile or not ai_profile.reposition:
		_log(source, "intent unavailable: missing profile or reposition intent profile")
		return null

	var intent_bias: float = 1.0
	if ai_profile.reposition.get("intent_bias") != null:
		intent_bias = float(ai_profile.reposition.get("intent_bias"))
	# Get the game map.
	var game_map: GameMap = planning_context.get_game_map()

	# Get the owner key for the source unit.
	var owner_key: String = game_map.get_owner_key(source.owner)
	if owner_key.is_empty():
		_log(source, "intent unavailable: missing owner key")
		return null

	# Get the directive state for the source unit's owner.
	var state: RefCounted = game_map.directive_planner.get_owner_directive_by_key(
		owner_key, source.position
	)
	if not state:
		_log(source, "intent unavailable: missing directive state")
		return null

	var squad_center: Vector2i = planning_context.get_squad_center()
	var destination: Vector2i = source.position
	var score: float = 0.0

	match state.directive:
		NpcDirectiveState.Directive.HOLD_PERIMETER:
			var hold_anchor: Vector2i = state.anchor_position
			if hold_anchor == Vector2i.ZERO:
				hold_anchor = squad_center
			destination = _pick_destination_for_objective(
				planning_context,
				hold_anchor,
				hold_anchor,
				hold_anchor,
				maxi(1, state.leash_radius),
				state.compact_radius,
				true
			)
			score = AITuning.REPOSITION_HOLD_SCORE

		NpcDirectiveState.Directive.PATROL:
			var patrol_target: Vector2i = state.get_patrol_target()
			destination = _pick_destination_for_objective(
				planning_context,
				squad_center,
				patrol_target,
				Vector2i.ZERO,
				0,
				state.compact_radius,
				false
			)
			score = AITuning.REPOSITION_PATROL_SCORE

		_:
			destination = source.position

	if destination == Vector2i.ZERO or destination == source.position:
		_log(source, "intent produced no movement destination")
		return null

	var final_score: float = clampf(score * intent_bias, 0.0, 100.0)

	_log(
		source,
		(
			"selected destination=%s score=%.2f (bias=%.2f final=%.2f)"
			% [MetaTag.pos_tag(destination), score, intent_bias, final_score]
		),
	)

	var plan: AIPlan = AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.REPOSITION,
		final_score,
		null,
		null,
		destination
	)
	plan.debug_details = {
		"directive": NpcDirectiveState.Directive.keys()[state.directive],
		"destination": destination,
		"objective_score": score,
		"intent_bias": intent_bias,
		"final_score": final_score,
	}
	return plan


static func _pick_destination_for_objective(
	planning_context: AIPlanningContext,
	squad_center: Vector2i,
	objective: Vector2i,
	leash_center: Vector2i,
	leash_radius: int,
	compact_radius: int,
	prefer_low_threat: bool
) -> Vector2i:
	var source: MapCombatEntity = planning_context.source
	var best_tile: Vector2i = source.position
	var best_score: float = -INF

	for tile: Vector2i in planning_context.get_reachable_tiles():
		if leash_center != Vector2i.ZERO and tile.distance_to(leash_center) > leash_radius:
			continue
		if tile.distance_to(squad_center) > compact_radius:
			continue

		var threat: float = planning_context.get_tile_threat_score(source, tile)
		var objective_distance: float = tile.distance_to(objective)
		var cohesion_distance: float = tile.distance_to(squad_center)

		var score: float = 0.0
		if prefer_low_threat:
			score += -threat * AITuning.HOLD_THREAT_WEIGHT
			score += -objective_distance * AITuning.HOLD_OBJECTIVE_WEIGHT
		else:
			score += -threat * AITuning.PATROL_THREAT_WEIGHT
			score += -objective_distance * AITuning.PATROL_OBJECTIVE_WEIGHT
		score += -cohesion_distance * AITuning.COHESION_WEIGHT

		if score > best_score:
			best_score = score
			best_tile = tile

	return best_tile


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
