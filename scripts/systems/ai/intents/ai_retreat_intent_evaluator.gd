class_name AIRetreatIntentEvaluator
extends RefCounted

const INTENT_LABEL: String = "Retreat"
const RETREAT_THREAT_WEIGHT: float = 1.0
const RETREAT_DIRECTION_WEIGHT: float = 0.8
const RETREAT_MAX_THREAT: float = 100.0

const RETREAT_DEFAULT_DIRECTION_SCORE: float = 0.5
const RETREAT_FORCE_RATIO_MAX: float = 2.0


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating %s intent -----" % [INTENT_LABEL.to_upper()]
	)

	var source: MapCombatEntity = planning_context.source
	if not source.can_move():
		_log(source, "intent unavailable: cannot move")
		return null

	# Phase 1: Decide IF we should retreat from current tile (self_health + current_threat only)
	var retreat_decision: Dictionary = _evaluate_retreat_necessity(source, planning_context)
	if not retreat_decision["should_retreat"]:
		_log(
			source,
			(
				"no retreat needed: survivability=%.2f threat=%.2f"
				% [retreat_decision["survivability_score"], retreat_decision["threat_score"]]
			),
		)
		return null

	_log(
		source,
		(
			"retreat triggered: survivability=%.2f threat=%.2f"
			% [retreat_decision["survivability_score"], retreat_decision["threat_score"]]
		),
	)

	# Phase 2: Resolve retreat profile for dynamic scoring
	var profile: AIActionProfile = AITacticalBrainResolver.resolve_retreat_profile(source)
	if not profile:
		_log(source, "intent unavailable: missing retreat profile")
		return null

	# Phase 3: Find safest reachable retreat tile
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

	# Phase 4: Select utility module for escape
	var utility_modules: Array[EquippedModule] = planning_context.get_unit_utility_modules()

	var selected_module: EquippedModule = _select_retreat_module(
		source, planning_context, best_tile, utility_modules
	)

	# Phase 5: Log escape plan
	_log(source, "retreating to %s score=%.2f" % [MetaTag.pos_tag(best_tile), best_score])
	if selected_module:
		_log(source, "with module: %s" % [selected_module.get_chat_tag()])

	return AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.RETREAT,
		clampf(best_score, 0.0, 100.0),
		source,
		selected_module,
		best_tile
	)


## Evaluate current position: should we retreat based on self_health and current tile threat?
## Returns dict with "should_retreat" bool and component scores.
static func _evaluate_retreat_necessity(
	source: MapCombatEntity,
	planning_context: AIPlanningContext,
) -> Dictionary:
	var combatant: CombatEntity = source.combatant
	if not combatant:
		return {"should_retreat": false, "survivability_score": 0.0, "threat_score": 0.0}

	# Get the maximum survivability score.
	var max_survivability: float = AIUtils.get_entity_max_survivability(source)
	# Get the current survivability score.
	var current_survivability: float = AIUtils.get_entity_current_survivability(source)
	# Surivability ratio: 1.0 = full health, 0.0 = dead
	var survivability_ratio: float = float(current_survivability) / float(max_survivability)
	# Inverted: low survivability = high retreat score
	var survivability_score: float = 1.0 - clampf(survivability_ratio, 0.0, 1.0)

	# Threat score: how dangerous is the local force balance (0.0..1.0)
	var force_data: Dictionary = _calculate_force_retreat_pressure(planning_context)
	var force_ratio: float = force_data["force_ratio"]
	var threat_score: float = force_data["normalized"]
	var ally_power: float = force_data["ally_power"]
	var enemy_power: float = force_data["enemy_power"]

	# Optional local map threat still available for debug (not used in final formula)
	var current_threat: float = planning_context.get_tile_threat_score()

	# Simple logic: retreat if EITHER is high (health critical OR force disadvantage)
	# Threshold: combined score > 1.0 triggers retreat
	var combined_score: float = survivability_score + threat_score
	var should_retreat: bool = combined_score > 1.0
	_log(
		source,
		(
			"retreat necessity calc (survivability=%.2f [%.1f/%.1f] force=%.2f [enemy=%.1f ally=%.1f] map=%.1f combined=%.2f)"
			% [
				survivability_score,
				current_survivability,
				max_survivability,
				force_ratio,
				enemy_power,
				ally_power,
				current_threat,
				combined_score,
			]
		)
	)

	return {
		"should_retreat": should_retreat,
		"survivability_score": survivability_score,
		"threat_score": threat_score,
		"combat_power_ratio": force_ratio,
		"combined_score": combined_score,
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
	var best_breakdown: Dictionary = {}

	for tile: Vector2i in reachable_tiles:
		# Verify pathfinding.
		if tile != source.position:
			var path: Array[Vector2i] = planning_context.get_path(source.position, tile)
			if path.is_empty():
				continue

		# Evaluate tile using profile considerations
		var evaluation_context: Dictionary = {
			"source": source,
			"tile": tile,
			"planning_context": planning_context,
		}
		var tile_score: float = profile.evaluate_final(evaluation_context)
		if tile_score > best_score:
			best_score = tile_score
			safest_tile = tile
			best_breakdown = profile.evaluate_final_breakdown(evaluation_context)
			_log(
				source,
				(
					"new best retreat tile candidate: %s score=%.2f (prev=%.2f)"
					% [MetaTag.pos_tag(tile), tile_score, best_score]
				)
			)

	_log(source, "selected retreat tile %s score=%.2f" % [MetaTag.pos_tag(safest_tile), best_score])

	# Log breakdown if available
	if best_breakdown.has("components"):
		for component in best_breakdown.components:
			_log(
				source,
				(
					"  - %s: input=%.2f curve=%.2f weight=%.2f contrib=%.2f"
					% [
						component.get("name"),
						component.get("normalized_input"),
						component.get("curve"),
						component.get("weight"),
						component.get("contribution"),
					]
				)
			)

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
