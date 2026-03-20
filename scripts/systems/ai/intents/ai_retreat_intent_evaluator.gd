class_name AIRetreatIntentEvaluator
extends RefCounted

const INTENT_LABEL: String = "Retreat"
const RETREAT_THREAT_WEIGHT: float = 1.0
const RETREAT_DIRECTION_WEIGHT: float = 0.8
const RETREAT_MAX_THREAT: float = 100.0
const RETREAT_DEFAULT_DIRECTION_SCORE: float = 0.5


static func evaluate(context: AIPlanningContext) -> AIPlan:
	_add_thought(context.source, "----- Evaluating %s intent -----" % [INTENT_LABEL.to_upper()])

	var source: MapCombatEntity = context.source
	if not source.can_move():
		_log(source, "intent unavailable: cannot move")
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
	var enemy_centroid: Vector2 = _get_known_enemy_centroid(source, context)
	if enemy_centroid != Vector2.ZERO:
		var centroid_tile: Vector2i = Vector2i(round(enemy_centroid.x), round(enemy_centroid.y))
		_log(source, "enemy centroid found at %s" % [MetaTag.pos_tag(centroid_tile)])
	else:
		_log(source, "no enemy centroid available (visible or remembered)")

	var reachable_tiles: Array[Vector2i] = context.get_reachable_tiles()
	if reachable_tiles.is_empty():
		_log(source, "intent unavailable: no reachable tiles")
		return null

	var best_tile: Vector2i = _find_safest_retreat_tile(
		source,
		context,
		reachable_tiles,
		enemy_centroid,
	)
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
	_log(
		source,
		(
			"retreat necessity calc (health=%.2f [%.2f/%.2f] threat=%.2f [%.2f] combined=%.2f)"
			% [
				health_score,
				combatant.health,
				combatant.max_health,
				threat_score,
				current_threat,
				combined_score
			]
		)
	)

	return {
		"should_retreat": should_retreat,
		"health_score": health_score,
		"threat_score": threat_score,
		"combined_score": combined_score,
	}


## Compute centroid from visible enemies.
static func _compute_enemy_centroid(enemies: Array[MapCombatEntity]) -> Vector2:
	if enemies.is_empty():
		return Vector2.ZERO

	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for enemy: MapCombatEntity in enemies:
		if not enemy or enemy.combatant.is_dead():
			continue
		sum += Vector2(enemy.position)
		count += 1

	if count == 0:
		return Vector2.ZERO

	return sum / float(count)


## Determine which enemy centroid to use (visible > remembered fallback).
static func _get_known_enemy_centroid(
	source: MapCombatEntity,
	context: AIPlanningContext,
) -> Vector2:
	var visible_enemies: Array[MapCombatEntity] = context.get_enemies()
	if not visible_enemies.is_empty():
		var centroid: Vector2 = _compute_enemy_centroid(visible_enemies)
		if source.combatant:
			source.combatant.last_enemy_centroid = centroid
		return centroid

	if source.combatant:
		return source.combatant.last_enemy_centroid

	return Vector2.ZERO


## Score direction for retreat: 0 (into enemy) .. 1 (away from enemy).
static func _calculate_direction_score(
	source_pos: Vector2i,
	tile_pos: Vector2i,
	enemy_centroid: Vector2,
) -> float:
	if enemy_centroid == Vector2.ZERO:
		return RETREAT_DEFAULT_DIRECTION_SCORE

	var source_dir: Vector2 = Vector2(source_pos) - enemy_centroid
	var candidate_dir: Vector2 = Vector2(tile_pos) - enemy_centroid
	if source_dir.length() == 0 or candidate_dir.length() == 0:
		return RETREAT_DEFAULT_DIRECTION_SCORE
	source_dir = source_dir.normalized()
	candidate_dir = candidate_dir.normalized()

	var dot: float = clampf(source_dir.dot(candidate_dir), -1.0, 1.0)
	return (dot + 1.0) * 0.5


static func _calculate_retreat_tile_score(
	source: MapCombatEntity,
	context: AIPlanningContext,
	tile: Vector2i,
	enemy_centroid: Vector2,
) -> float:
	var threat: float = context.get_threat(tile)
	var threat_score: float = 1.0 - clampf(threat / RETREAT_MAX_THREAT, 0.0, 1.0)
	var direction_score: float = _calculate_direction_score(source.position, tile, enemy_centroid)
	return threat_score * RETREAT_THREAT_WEIGHT + direction_score * RETREAT_DIRECTION_WEIGHT


## Find the safest reachable tile to retreat to (lowest threat among reachable tiles).
static func _find_safest_retreat_tile(
	source: MapCombatEntity,
	context: AIPlanningContext,
	reachable_tiles: Array[Vector2i],
	enemy_centroid: Vector2,
) -> Vector2i:
	var safest_tile: Vector2i = source.position
	var best_score: float = -INF

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

		var tile_score: float = _calculate_retreat_tile_score(source, context, tile, enemy_centroid)
		if tile_score > best_score:
			best_score = tile_score
			safest_tile = tile

	_log(source, "selected retreat tile %s score=%.3f" % [MetaTag.pos_tag(safest_tile), best_score])

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


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])
