class_name AIAttackIntentEvaluator
extends RefCounted

const DEFAULT_MAX_LOS_TILE_CANDIDATES: int = 6
const INTENT_LABEL: String = "Attack"


static func _log(source: MapCombatEntity, message: String) -> void:
	_add_thought(source, "%s %s" % [INTENT_LABEL, message])


static func evaluate(planning_context: AIPlanningContext) -> AIPlan:
	_add_thought(
		planning_context.source, "----- Evaluating %s intent -----" % [INTENT_LABEL.to_upper()]
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

	var profile: AIActionProfile = AITacticalBrainResolver.resolve_attack_profile(source)
	if not profile:
		# No attack profile means this brain contributes zero utility to ATTACK intents.
		_log(source, "intent unavailable: missing profile")
		return null

	var max_module_range: int = _get_max_module_range(source, offensive_modules)
	var max_candidate_distance: int = (
		source.combatant.get_stat(Enums.StatType.SPEED) + max_module_range
	)
	var candidate_targets: Array[Dictionary] = []

	for target: MapCombatEntity in visible_enemies:
		if target.combatant.is_dead():
			continue

		var distance: int = _manhattan_distance(source.position, target.position)
		if distance > max_candidate_distance:
			continue

		var preliminary_context: Dictionary = {
			"source": source,
			"target": target,
			"max_distance": float(max_candidate_distance),
		}
		var preliminary_score: float = profile.evaluate_preliminary(preliminary_context)
		_log(
			source,
			(
				"prelim: target=%s dist=%d prelim=%.2f"
				% [
					target.combatant.get_chat_tag(),
					distance,
					preliminary_score,
				]
			),
		)
		var candidate_data: Dictionary = {
			"target": target,
			"preliminary_score": preliminary_score,
		}
		candidate_targets.append(candidate_data)

	if candidate_targets.is_empty():
		return null

	candidate_targets.sort_custom(
		func(a: Dictionary, b: Dictionary): return a["preliminary_score"] > b["preliminary_score"]
	)

	var best_score: float = -INF
	var best_in_range: bool = false
	var best_target: MapCombatEntity = null
	var best_equipped_module: EquippedModule = null
	var best_destination: Vector2i = Vector2i.ZERO
	var max_targets: int = mini(profile.get_max_targets_to_narrow_phase(), candidate_targets.size())

	for candidate_index in range(max_targets):
		var candidate: Dictionary = candidate_targets[candidate_index]
		var target: MapCombatEntity = candidate["target"]
		_log(
			source,
			(
				"narrow-phase target=%s prelim=%.2f"
				% [target.combatant.get_chat_tag(), float(candidate["preliminary_score"])]
			),
		)

		var has_los: bool = planning_context.has_line_of_sight(source.position, target.position)

		for equipped_module: EquippedModule in offensive_modules:
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
					_log(
						source,
						(
							"option rejected: target=%s module=%s reason=unreachable"
							% [target.combatant.get_chat_tag(), equipped_module.get_chat_tag()]
						),
					)
					continue
				destination = move_data["destination"]

			var score_context: Dictionary = {
				"source": source,
				"target": target,
				"module": equipped_module.module,
				"max_distance": float(max_candidate_distance),
			}
			var base_score: float = profile.evaluate_final(score_context)
			var score: float = base_score
			var in_range_bonus: float = 0.0
			var reachable_bonus: float = 0.0
			if can_attack_from_source:
				in_range_bonus = profile.in_range_los_bonus
				score += in_range_bonus
			else:
				reachable_bonus = profile.reachable_bonus
				score += reachable_bonus

			_log(
				source,
				(
					"option: target=%s module=%s score=%.2f tile=%s"
					% [
						target.combatant.get_chat_tag(),
						equipped_module.get_chat_tag(),
						score,
						MetaTag.pos_tag(destination),
					]
				),
			)

			if score > best_score:
				best_score = score
				best_in_range = can_attack_from_source
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

	var attack_breakdown_context: Dictionary = {
		"source": source,
		"target": best_target,
		"module": best_equipped_module.module,
		"max_distance": float(max_candidate_distance),
	}
	var attack_breakdown: Dictionary = profile.evaluate_final_breakdown(attack_breakdown_context)
	var attack_bonus: float = (
		profile.in_range_los_bonus if best_in_range else profile.reachable_bonus
	)
	var attack_bonus_name: String = "in_range_los_bonus" if best_in_range else "reachable_bonus"
	_log(
		source,
		(
			"breakdown: base=%.2f %s=%.2f total=%.2f"
			% [attack_breakdown.score, attack_bonus_name, attack_bonus, best_score]
		),
	)
	for component in attack_breakdown.components:
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
			),
		)

	_log(source, "scored %.2f" % best_score)

	return AIPlanBuilder.build_plan(
		source,
		planning_context.get_game_map(),
		AIPlan.Intent.ATTACK,
		clampf(best_score, 0.0, 100.0),
		best_target,
		best_equipped_module,
		best_destination
	)


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
