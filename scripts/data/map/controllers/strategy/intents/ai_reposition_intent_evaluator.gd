class_name AIRepositionIntentEvaluator
extends RefCounted


static func evaluate(context: AIPlanningContext) -> AIPlan:
	var source: MapCombatEntity = context.source
	if not source.can_move():
		return null
	if not context.get_visible_enemies().is_empty():
		return null

	var owner_key: String = context.game_map.get_owner_key(source.owner)
	if owner_key.is_empty():
		return null

	var state: RefCounted = context.game_map.get_owner_directive(source.owner, source.position)
	if not state:
		return null

	var squad_center: Vector2i = context.get_squad_center(source.position)
	var destination: Vector2i = source.position
	var score: float = 0.0

	match state.directive:
		NpcDirectiveState.Directive.HOLD_PERIMETER:
			var hold_anchor: Vector2i = state.anchor_position
			if hold_anchor == Vector2i.ZERO:
				hold_anchor = squad_center
			destination = _pick_destination_for_objective(
				context,
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
				context, squad_center, patrol_target, Vector2i.ZERO, 0, state.compact_radius, false
			)
			score = AITuning.REPOSITION_PATROL_SCORE

		_:
			destination = source.position

	if destination == Vector2i.ZERO or destination == source.position:
		return null

	return AIPlanBuilder.build_plan(
		context, AIPlan.Intent.REPOSITION, score, null, null, destination
	)


static func _pick_destination_for_objective(
	context: AIPlanningContext,
	squad_center: Vector2i,
	objective: Vector2i,
	leash_center: Vector2i,
	leash_radius: int,
	compact_radius: int,
	prefer_low_threat: bool
) -> Vector2i:
	var source: MapCombatEntity = context.source
	var best_tile: Vector2i = source.position
	var best_score: float = -INF

	for tile: Vector2i in context.get_reachable_tiles():
		if context.game_map.is_occupied(tile):
			continue
		if leash_center != Vector2i.ZERO and tile.distance_to(leash_center) > leash_radius:
			continue
		if tile.distance_to(squad_center) > compact_radius:
			continue

		var threat: float = context.get_threat(tile)
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
