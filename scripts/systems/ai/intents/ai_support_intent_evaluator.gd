class_name AISupportIntentEvaluator
extends "res://scripts/systems/ai/intents/ai_intent_evaluator.gd"

const INTENT_LABEL: String = "Support"
const ACTIVATION_UTILITY_WEIGHT: float = 0.50
const OPTION_UTILITY_WEIGHT: float = 0.50


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])


func get_intent() -> AIPlan.Intent:
	return AIPlan.Intent.SUPPORT


func get_unavailable_reason() -> String:
	return "no valid support candidate"


func evaluate_intent(planning_context: AIPlanningContext) -> AIPlan:
	return evaluate(planning_context)


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating intent %10s -----" % [INTENT_LABEL.to_upper()]
	)
	var source: MapCombatEntity = planning_context.source

	# Get the AI Profile.
	var ai_profile: AIProfile = AIProfileManager.get_profile(source)

	if not ai_profile or not ai_profile.support or not ai_profile.support.target_phase:
		# No support profile means this brain contributes zero utility to SUPPORT intents.
		_log(source, "intent unavailable: missing profile or support target phase")
		return null

	# Get the support target phase profile for this unit.
	var profile: AIActionProfile = ai_profile.support.target_phase
	var intent_bias_value = ai_profile.support.get("intent_bias")
	var intent_bias: float = 1.0 if intent_bias_value == null else float(intent_bias_value)
	var activation_phase: AIActionProfile = ai_profile.support.get("activation_phase")

	var activation_normalized: float = 1.0
	var activation_threshold: float = 0.0
	if activation_phase:
		var activation_context = AIEvaluationContext.for_intent(source, planning_context)
		var activation_max: float = activation_phase.get_max_score()
		if activation_max <= 0.0:
			_log(source, "intent unavailable: support activation phase has zero max score")
			return null
		var activation_raw: float = activation_phase.evaluate(activation_context)
		activation_normalized = clampf(activation_raw / activation_max, 0.0, 1.0)
		activation_threshold = activation_phase.activation_threshold
		if activation_normalized < activation_threshold:
			_log(
				source,
				(
					"intent unavailable: activation %.2f below threshold %.2f"
					% [activation_normalized, activation_threshold]
				),
			)
			return null

	var utility_modules: Array[EquippedModule] = planning_context.get_unit_utility_modules()
	if utility_modules.is_empty():
		return null

	var allies_with_self: Array[MapCombatEntity] = planning_context.get_allies(true)
	var max_module_range: int = _get_max_module_range(source, utility_modules)
	var max_candidate_distance: int = source.combatant.speed + max_module_range

	var best_score: float = -INF
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var best_destination: Vector2i = source.position
	var evaluated_options: int = 0
	var rejected_unreachable: int = 0

	for target: MapCombatEntity in allies_with_self:
		if target.combatant.is_dead():
			continue

		for equipped_module: EquippedModule in utility_modules:
			evaluated_options += 1
			if not _can_module_target(equipped_module.module, source, target):
				continue

			var module_range: int = (
				equipped_module.module.module_range + source.combatant.range_modifier
			)
			var source_distance: int = _manhattan_distance(source.position, target.position)
			var can_use_from_source: bool = _is_in_range(
				source_distance,
				module_range,
				target,
				source,
			)
			var destination: Vector2i = source.position

			if not can_use_from_source:
				var move_data: Dictionary = _find_support_destination(
					planning_context,
					source,
					target,
					module_range,
				)
				if not move_data["reachable"]:
					rejected_unreachable += 1
					continue
				destination = move_data["destination"]

			var score_context: AIEvaluationContext = AIEvaluationContext.for_target(
				source,
				target,
				equipped_module.module,
				equipped_module.item,
				planning_context,
				destination,
				float(max_candidate_distance),
			)
			var score: float = profile.evaluate(score_context)

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
							target.combatant.get_chat_tag(),
							equipped_module.get_chat_tag(),
							score,
						]
					),
				)

	if not best_target:
		_log(source, "intent produced no valid target")
		return null

	_log(source, "scored %.2f" % best_score)
	var option_quality: float = 0.0
	var option_max: float = profile.get_max_score()
	if option_max > 0.0:
		option_quality = clampf(best_score / option_max, 0.0, 1.0)

	var final_utility: float = clampf(
		(
			activation_normalized * ACTIVATION_UTILITY_WEIGHT
			+ option_quality * OPTION_UTILITY_WEIGHT
		) * 100.0 * intent_bias,
		0.0,
		100.0,
	)

	var plan: AIPlan = AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.SUPPORT,
		final_utility,
		best_target,
		best_equipped_module,
		best_destination
	)
	plan.debug_details = {
		"evaluated_options": evaluated_options,
		"rejected_unreachable": rejected_unreachable,
		"activation_normalized": activation_normalized,
		"activation_threshold": activation_threshold,
		"option_quality": option_quality,
		"intent_bias": intent_bias,
		"final_utility": final_utility,
		"best_target": best_target.combatant.get_chat_tag(),
		"best_module": best_equipped_module.get_chat_tag(),
		"best_destination": best_destination,
	}
	return plan


static func _find_support_destination(
	planning_context: AIPlanningContext,
	source: MapCombatEntity,
	target: MapCombatEntity,
	module_range: int,
) -> Dictionary:
	var candidate_tiles: Array[Dictionary] = []
	for tile: Vector2i in planning_context.get_reachable_tiles():
		if tile == source.position:
			continue

		var distance_to_target: int = _manhattan_distance(tile, target.position)
		if distance_to_target > module_range:
			continue

		var tile_threat: float = planning_context.get_tile_threat_score(source, tile)
		(
			candidate_tiles
			. append(
				{
					"tile": tile,
					"tile_threat": tile_threat,
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
		func(a: Dictionary, b: Dictionary):
			if a["tile_threat"] == b["tile_threat"]:
				return a["distance_to_source"] < b["distance_to_source"]
			return a["tile_threat"] < b["tile_threat"]
	)

	var destination: Vector2i = candidate_tiles[0]["tile"]
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


static func _is_in_range(
	distance: int,
	module_range: int,
	target: MapCombatEntity,
	source: MapCombatEntity,
) -> bool:
	if target == source:
		return true
	return distance <= module_range


static func _can_module_target(
	module: ItemModule,
	source: MapCombatEntity,
	target: MapCombatEntity,
) -> bool:
	for effect: BaseEffect in module.effects:
		match effect.target:
			Enums.TargetType.SELF:
				if target == source:
					return true
			Enums.TargetType.ALLY:
				if target.owner == source.owner and target != source:
					return true
			Enums.TargetType.AREA:
				return true
	return false


static func _get_max_module_range(
	source: MapCombatEntity,
	utility_modules: Array[EquippedModule],
) -> int:
	var max_range: int = 0
	for equipped_module: EquippedModule in utility_modules:
		var range_with_modifier: int = (
			equipped_module.module.module_range + source.combatant.range_modifier
		)
		max_range = maxi(max_range, range_with_modifier)
	return max_range


static func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
