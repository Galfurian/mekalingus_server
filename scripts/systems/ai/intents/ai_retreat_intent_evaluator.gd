class_name AIRetreatIntentEvaluator
extends RefCounted

const INTENT_LABEL: String = "Retreat"


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])


static func evaluate(context: AIPlanningContext) -> AIPlan:
	_add_thought(context.source, "----- Evaluating %s intent -----" % [INTENT_LABEL.to_upper()])

	var source: MapCombatEntity = context.source
	if not source.can_move():
		return null

	# Phase 1: Decide IF we should retreat from current tile (self_health + current_threat only)
	var retreat_decision: Dictionary = _evaluate_retreat_necessity(source, context)
	if not retreat_decision["should_retreat"]:
		_log(
			source,
			(
				"no retreat needed: health=%.2f threat=%.2f"
				% [retreat_decision["health_score"], retreat_decision["threat_score"]]
			),
		)
		return null

	_log(
		source,
		(
			"retreat triggered: health=%.2f threat=%.2f"
			% [retreat_decision["health_score"], retreat_decision["threat_score"]]
		),
	)

	# Phase 2: Find safest reachable retreat tile
	var reachable_tiles: Array[Vector2i] = context.get_reachable_tiles()
	if reachable_tiles.is_empty():
		return null

	var best_tile: Vector2i = _find_safest_retreat_tile(source, context, reachable_tiles)
	if best_tile == source.position:
		_log(source, "no safe retreat destination found")
		return null

	# Phase 3: Select utility module for escape
	var utility_modules: Array[EquippedModule] = context.get_utility_modules()
	var selected_module: EquippedModule = _select_retreat_module(
		source, context, best_tile, utility_modules
	)

	# Phase 4: Log escape plan
	_log(
		source,
		(
			"retreating to %s (threat: current=%.2f dest=%.2f)"
			% [
				MetaTag.pos_tag(best_tile),
				context.get_threat(source.position),
				context.get_threat(best_tile),
			]
		)
	)
	if selected_module:
		_log(source, "with module: %s" % [selected_module.get_chat_tag()])

	return (
		AIPlanBuilder
		. build_plan(
			context,
			AIPlan.Intent.RETREAT,
			75.0,
			source,
			selected_module,
			best_tile,
		)
	)


## Evaluate current position: should we retreat based on self_health and current tile threat?
## Returns dict with "should_retreat" bool and component scores.
static func _evaluate_retreat_necessity(
	source: MapCombatEntity,
	context: AIPlanningContext,
) -> Dictionary:
	var combatant: CombatEntity = source.combatant
	if not combatant:
		return {"should_retreat": false, "health_score": 0.0, "threat_score": 0.0}

	# Health score: 1.0 = full health, 0.0 = dead
	var health_ratio: float = float(combatant.health) / float(combatant.max_health)
	# Inverted: low health = high retreat score
	var health_score: float = 1.0 - clampf(health_ratio, 0.0, 1.0)

	# Threat score: how dangerous is current position? (0.0 to 1.0)
	var current_threat: float = context.get_threat(source.position)
	var threat_score: float = clampf(current_threat / 100.0, 0.0, 1.0)

	# Simple logic: retreat if EITHER is high (health critical OR threat extreme)
	# Threshold: combined score > 1.0 triggers retreat
	var combined_score: float = health_score + threat_score
	var should_retreat: bool = combined_score > 1.0

	return {
		"should_retreat": should_retreat,
		"health_score": health_score,
		"threat_score": threat_score,
		"combined_score": combined_score,
	}


## Find the safest reachable tile to retreat to (lowest threat among reachable tiles).
static func _find_safest_retreat_tile(
	source: MapCombatEntity,
	context: AIPlanningContext,
	reachable_tiles: Array[Vector2i],
) -> Vector2i:
	var safest_tile: Vector2i = source.position
	var lowest_threat: float = INF

	for tile: Vector2i in reachable_tiles:
		# Skip occupied tiles
		if tile != source.position and context.game_map.is_occupied(tile):
			continue

		# Verify pathfinding
		if tile != source.position:
			var path: Array[Vector2i] = (
				AIPathfinder
				. get_shortest_path(
					context.game_map,
					source.position,
					tile,
				)
			)
			if path.is_empty():
				continue

		# Check threat at this tile
		var threat: float = context.get_threat(tile)
		if threat < lowest_threat:
			lowest_threat = threat
			safest_tile = tile

	return safest_tile


## Select utility module for escape (secondary benefit, not part of retreat decision).
static func _select_retreat_module(
	source: MapCombatEntity,
	_context: AIPlanningContext,
	_tile: Vector2i,
	utility_modules: Array[EquippedModule],
) -> EquippedModule:
	var best_module: EquippedModule = null

	for equipped_module: EquippedModule in utility_modules:
		if not _can_module_target_self(equipped_module.module, source):
			continue

		# Use default/simple module scoring if available
		# For now, just pick first valid module
		best_module = equipped_module
		break

	return best_module


static func _can_module_target_self(module: ItemModule, _source: MapCombatEntity) -> bool:
	for effect: BaseEffect in module.effects:
		if effect.target == Enums.TargetType.SELF or effect.target == Enums.TargetType.AREA:
			return true
	return false


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
