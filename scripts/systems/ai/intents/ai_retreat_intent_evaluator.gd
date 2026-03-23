class_name AIRetreatIntentEvaluator
extends RefCounted

const INTENT_LABEL: String = "Retreat"
const RETREAT_FORCE_RATIO_MAX: float = 2.0


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating intent %10s -----" % [INTENT_LABEL.to_upper()]
	)

	var source: MapCombatEntity = planning_context.source
	if not source.can_move():
		_log(source, "intent unavailable: cannot move")
		return null

	# Get the AI Profile.
	var ai_profile: AIProfile = AIProfileManager.get_profile(source)

	if not ai_profile or not ai_profile.retreat_profile:
		# No retreat profile means this brain contributes zero utility to RETREAT intents.
		_log(source, "intent unavailable: missing profile or retreat profile")
		return null

	# Get the retreat profile for this unit.
	var profile: AIActionProfile = ai_profile.retreat_profile

	# Decide if we should retreat from current position.
	var retreat_decision: Dictionary = _evaluate_retreat_necessity(
		source,
		planning_context,
		profile,
	)
	if not retreat_decision["should_retreat"]:
		_log(
			source,
			(
				"no retreat needed: normalized=%.2f (score=%.2f/%0.2f)"
				% [
					retreat_decision["normalized_score"],
					retreat_decision["raw_score"],
					retreat_decision["max_score"],
				]
			)
		)
		return null

	_log(
		source,
		(
			"retreat triggered: normalized=%.2f (score=%.2f/%0.2f)"
			% [
				retreat_decision["normalized_score"],
				retreat_decision["raw_score"],
				retreat_decision["max_score"],
			]
		)
	)

	# Find safest reachable retreat tile.
	var enemy_centroid: Vector2 = _get_known_enemy_centroid(source, planning_context)
	if enemy_centroid != Vector2.ZERO:
		var centroid_tile: Vector2i = Vector2i(round(enemy_centroid.x), round(enemy_centroid.y))
		_log(source, "enemy centroid found at %s" % [MetaTag.pos_tag(centroid_tile)])
	else:
		_log(source, "no enemy centroid available (visible or remembered)")

	var reachable_tiles: Array[Vector2i] = planning_context.get_reachable_tiles()
	if reachable_tiles.is_empty():
		_log(source, "intent unavailable: no reachable tiles")
		return null

	var tile_evaluation_result: Dictionary = _find_safest_retreat_tile(
		source,
		planning_context,
		profile,
		reachable_tiles,
	)
	var best_tile: Vector2i = tile_evaluation_result["tile"]
	var best_score: float = tile_evaluation_result["score"]

	if best_tile == source.position:
		_log(source, "no safe retreat destination found")
		return null

	# Select utility module for escape.
	var utility_modules: Array[EquippedModule] = planning_context.get_unit_utility_modules()

	var selected_module: EquippedModule = _select_retreat_module(
		source, planning_context, best_tile, utility_modules
	)

	# Log escape plan.
	_log(source, "retreating to %s score=%.2f" % [MetaTag.pos_tag(best_tile), best_score])
	if selected_module:
		_log(source, "with module: %s" % [selected_module.get_chat_tag()])

	var plan: AIPlan = AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.RETREAT,
		clampf(best_score, 0.0, 100.0),
		source,
		selected_module,
		best_tile
	)
	plan.debug_details = {
		"retreat_raw_score": retreat_decision["raw_score"],
		"retreat_normalized_score": retreat_decision["normalized_score"],
		"retreat_max_score": retreat_decision["max_score"],
		"retreat_destination_score": best_score,
		"best_destination": best_tile,
		"selected_module": selected_module.get_chat_tag() if selected_module else "none",
	}
	return plan


## Evaluate current position: should we retreat based on profile-configured considerations?
## Returns dict with "should_retreat" bool and component scores.
static func _evaluate_retreat_necessity(
	source: MapCombatEntity,
	planning_context: AIPlanningContext,
	profile: AIActionProfile,
) -> Dictionary:
	if not source or not source.combatant:
		return {
			"should_retreat": false,
			"raw_score": 0.0,
			"normalized_score": 0.0,
			"max_score": 0.0,
		}
	var evaluation_context: Dictionary = {
		"source": source,
		"planning_context": planning_context,
		"tile": source.position,
	}
	var raw_score: float = profile.evaluate(evaluation_context)
	var max_score: float = profile.get_max_score()
	var normalized_score: float = 0.0
	if max_score > 0.0:
		normalized_score = clampf(raw_score / max_score, 0.0, 1.0)
	var should_retreat: bool = profile.should_activate(evaluation_context)

	var retreat_message: String = (
		"retreat evaluation: normalized=%.2f (score=%.2f/%.2f) vs threshold %.2f -> %s"
		% [
			normalized_score,
			raw_score,
			max_score,
			profile.activation_threshold,
			"RETREAT" if should_retreat else "HOLD POSITION",
		]
	)
	_log(source, retreat_message)

	return {
		"should_retreat": should_retreat,
		"raw_score": raw_score,
		"normalized_score": normalized_score,
		"max_score": max_score,
	}


## Combat power-based enemy pressure: 0 (friendly dominates) .. 1 (enemies dominate 2x or more).
static func _calculate_force_retreat_pressure(
	planning_context: AIPlanningContext,
) -> Dictionary:
	var active_allies: Array[MapCombatEntity] = planning_context.get_allies(true)
	var total_allies_threat_score: float = 0.0
	for ally: MapCombatEntity in active_allies:
		total_allies_threat_score += planning_context.get_unit_threat_score(ally)
	var total_enemies_threat_score: float = 0.0
	for enemy: MapCombatEntity in planning_context.get_enemies():
		total_enemies_threat_score += planning_context.get_unit_threat_score(enemy)

	if total_allies_threat_score <= 0.0:
		total_allies_threat_score = 1.0

	var force_ratio: float = total_enemies_threat_score / total_allies_threat_score
	var normalized_force: float = clampf(force_ratio / RETREAT_FORCE_RATIO_MAX, 0.0, 1.0)
	return {
		"force_ratio": force_ratio,
		"normalized": normalized_force,
		"ally_power": total_allies_threat_score,
		"enemy_power": total_enemies_threat_score,
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
	planning_context: AIPlanningContext,
) -> Vector2:
	var visible_enemies: Array[MapCombatEntity] = planning_context.get_enemies()
	if not visible_enemies.is_empty():
		var centroid: Vector2 = _compute_enemy_centroid(visible_enemies)
		if source.combatant:
			source.combatant.last_enemy_centroid = centroid
		return centroid

	if source.combatant:
		return source.combatant.last_enemy_centroid

	return Vector2.ZERO


## Find the safest reachable tile to retreat to using profile-based scoring.
## Returns dict with "tile" (Vector2i) and "score" (float) for plan builder.
static func _find_safest_retreat_tile(
	source: MapCombatEntity,
	planning_context: AIPlanningContext,
	profile: AIActionProfile,
	reachable_tiles: Array[Vector2i],
) -> Dictionary:
	var safest_tile: Vector2i = source.position
	var best_score: float = -INF

	for tile: Vector2i in reachable_tiles:
		# Verify pathfinding.
		if tile != source.position:
			var path: Array[Vector2i] = planning_context.get_path(source.position, tile)
			if path.is_empty():
				continue

		# Evaluate tile using profile considerations.
		var evaluation_context: Dictionary = {
			"source": source,
			"planning_context": planning_context,
			"tile": tile,
		}
		var tile_score: float = profile.evaluate(evaluation_context)
		if tile_score > best_score:
			var previous_best_score: float = best_score
			best_score = tile_score
			safest_tile = tile
			_log(
				source,
				(
					"new best retreat tile candidate: %s score=%.2f (prev=%.2f)"
					% [MetaTag.pos_tag(tile), tile_score, previous_best_score]
				)
			)

	_log(source, "selected retreat tile %s score=%.2f" % [MetaTag.pos_tag(safest_tile), best_score])

	return {
		"tile": safest_tile,
		"score": best_score,
	}


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
