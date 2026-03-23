class_name AIAttackIntentEvaluator
extends "res://scripts/systems/ai/intents/ai_intent_evaluator.gd"

const DEFAULT_MAX_LOS_TILE_CANDIDATES: int = 6
const INTENT_LABEL: String = "Attack"


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])


func get_intent() -> AIPlan.Intent:
	return AIPlan.Intent.ATTACK


func get_unavailable_reason() -> String:
	return "no valid attack candidate"


func evaluate_intent(planning_context: AIPlanningContext) -> AIPlan:
	return evaluate(planning_context)


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating intent %10s -----" % [INTENT_LABEL.to_upper()]
	)
	var source: MapCombatEntity = planning_context.source

	var visible_enemies: Array[MapCombatEntity] = planning_context.get_enemies()

	if visible_enemies.is_empty():
		_log(source, "intent unavailable: no visible enemies in sensor range")
		return null

	var offensive_modules: Array[EquippedModule] = planning_context.get_unit_offensive_modules()
	if offensive_modules.is_empty():
		_log(source, "intent unavailable: no offensive modules available")
		return null

	# Get the AI Profile.
	var ai_profile: AIProfile = AIProfileManager.get_profile(source)

	if not ai_profile or not ai_profile.attack or not ai_profile.attack.target_phase:
		# No attack profile means this brain contributes zero utility to ATTACK intents.
		_log(source, "intent unavailable: missing profile or attack target phase")
		return null

	# Get the attack target phase profile for this unit.
	var profile: AIActionProfile = ai_profile.attack.target_phase

	var max_module_range: int = _get_max_module_range(source, offensive_modules)
	var max_candidate_distance: int = (
		source.combatant.get_stat(Enums.StatType.SPEED) + max_module_range
	)

	var best_score: float = -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var best_destination: Vector2i = Vector2i.ZERO
	var evaluated_options: int = 0
	var rejected_unreachable: int = 0

	for target: MapCombatEntity in visible_enemies:
		if target.combatant.is_dead():
			continue

		var distance: int = _manhattan_distance(source.position, target.position)
		if distance > max_candidate_distance:
			continue

		var has_los: bool = planning_context.has_line_of_sight(source.position, target.position)

		for equipped_module: EquippedModule in offensive_modules:
			evaluated_options += 1
			var module_range: int = (
				equipped_module.module.module_range
				+ source.combatant.get_stat(Enums.StatType.RANGE_MODIFIER)
			)
			var min_range: int = AIUtils.get_offensive_min_range(module_range)
			var source_distance: int = _manhattan_distance(source.position, target.position)
			var can_attack_from_source: bool = (
				has_los and source_distance >= min_range and source_distance <= module_range
			)
			var destination: Vector2i = source.position

			if not can_attack_from_source:
				var move_data: Dictionary = _find_attack_destination_with_los(
					planning_context,
					source,
					target,
					min_range,
					module_range,
				)
				if not move_data["reachable"]:
					rejected_unreachable += 1
					_log(
						source,
						(
							"option rejected: target=%s module=%s reason=unreachable"
							% [target.combatant.get_chat_tag(), equipped_module.get_chat_tag()]
						),
					)
					continue
				destination = move_data["destination"]

			var score_context: AIEvaluationContext = AIEvaluationContext.for_target(
				source,
				target,
				equipped_module.module,
				planning_context,
				destination,
				float(max_candidate_distance),
			)
			var base_score: float = profile.evaluate_variant(score_context)
			var score: float = base_score

			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module
				best_destination = destination
				_log(
					source,
					(
						"best updated: target=%s module=%s score=%.2f"
						% [
							best_target.combatant.get_chat_tag(),
							best_equipped_module.get_chat_tag(),
							best_score,
						]
					),
				)

	if not best_target:
		_log(source, "intent produced no valid target")
		return null

	_log(
		source,
		(
			"selected: target=%s module=%s score=%.2f tile=%s"
			% [
				best_target.combatant.get_chat_tag(),
				best_equipped_module.get_chat_tag(),
				best_score,
				MetaTag.pos_tag(best_destination),
			]
		),
	)

	_log(source, "scored %.2f" % best_score)

	var plan: AIPlan = AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.ATTACK,
		clampf(best_score, 0.0, 100.0),
		best_target,
		best_equipped_module,
		best_destination
	)
	plan.debug_details = {
		"evaluated_options": evaluated_options,
		"rejected_unreachable": rejected_unreachable,
		"best_target": best_target.combatant.get_chat_tag(),
		"best_module": best_equipped_module.get_chat_tag(),
		"best_destination": best_destination,
	}
	return plan


static func _find_attack_destination_with_los(
	planning_context: AIPlanningContext,
	source: MapCombatEntity,
	target: MapCombatEntity,
	min_range: int,
	max_range: int,
) -> Dictionary:
	var candidate_tiles: Array[Dictionary] = []
	for tile: Vector2i in planning_context.get_reachable_tiles():
		var distance_to_target: int = _manhattan_distance(tile, target.position)
		if distance_to_target < min_range or distance_to_target > max_range:
			continue

		(
			candidate_tiles
			. append(
				{
					"tile": tile,
					"distance_to_source": _manhattan_distance(source.position, tile),
				}
			)
		)

	if candidate_tiles.is_empty():
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
		}

	candidate_tiles.sort_custom(
		func(a: Dictionary, b: Dictionary): return a["distance_to_source"] < b["distance_to_source"]
	)

	var max_los_candidates: int = mini(DEFAULT_MAX_LOS_TILE_CANDIDATES, candidate_tiles.size())
	var destination: Vector2i = Vector2i.ZERO

	for tile_index in range(max_los_candidates):
		var tile: Vector2i = candidate_tiles[tile_index]["tile"]
		if planning_context.has_line_of_sight(tile, target.position):
			destination = tile
			break

	if destination == Vector2i.ZERO:
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
		}

	var path: Array[Vector2i] = planning_context.get_path(source.position, destination)
	if path.is_empty():
		return {
			"reachable": false,
			"destination": Vector2i.ZERO,
		}

	return {
		"reachable": true,
		"destination": destination,
	}


static func _get_max_module_range(
	source: MapCombatEntity,
	offensive_modules: Array[EquippedModule],
) -> int:
	var max_range: int = 0
	for equipped_module: EquippedModule in offensive_modules:
		var range_with_modifier: int = (
			equipped_module.module.module_range
			+ source.combatant.get_stat(Enums.StatType.RANGE_MODIFIER)
		)
		max_range = maxi(max_range, range_with_modifier)
	return max_range


static func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
