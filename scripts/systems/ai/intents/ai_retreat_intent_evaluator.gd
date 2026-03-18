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

	var profile: AIActionProfile = AITacticalBrainResolver.resolve_retreat_profile(source)
	if not profile:
		return null

	var reachable_tiles: Array[Vector2i] = context.get_reachable_tiles()
	if reachable_tiles.is_empty():
		return null

	var utility_modules: Array[EquippedModule] = context.get_utility_modules()
	var candidate_tiles: Array[Dictionary] = []

	for tile: Vector2i in reachable_tiles:
		if tile != source.position and context.game_map.is_occupied(tile):
			continue

		var preliminary_context: Dictionary = {
			"source": source,
			"target": source,
			"planning_context": context,
			"tile": tile,
		}
		var preliminary_score: float = profile.evaluate_preliminary(preliminary_context)
		(
			candidate_tiles
			. append(
				{
					"tile": tile,
					"preliminary_score": preliminary_score,
				}
			)
		)

	if candidate_tiles.is_empty():
		return null

	candidate_tiles.sort_custom(
		func(a: Dictionary, b: Dictionary): return a["preliminary_score"] > b["preliminary_score"]
	)

	var best_tile: Vector2i = source.position
	var best_score: float = -INF
	var best_base_score: float = 0.0
	var best_reachable_bonus: float = 0.0
	var max_targets: int = mini(profile.get_max_targets_to_narrow_phase(), candidate_tiles.size())

	for candidate_index in range(max_targets):
		var candidate: Dictionary = candidate_tiles[candidate_index]
		var tile: Vector2i = candidate["tile"]

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

		var score_context: Dictionary = {
			"source": source,
			"target": source,
			"planning_context": context,
			"tile": tile,
		}
		var base_score: float = profile.evaluate_preliminary(score_context)
		var score: float = base_score
		var reachable_bonus: float = 0.0
		if tile != source.position:
			reachable_bonus = profile.reachable_bonus
			score += reachable_bonus

		_log(
			source,
			"option: tile=%s base=%.2f reachable=%.2f total=%.2f"
			% [
				MetaTag.pos_tag(tile),
				base_score,
				reachable_bonus,
				score,
			],
		)

		if score > best_score:
			best_score = score
			best_base_score = base_score
			best_reachable_bonus = reachable_bonus
			best_tile = tile
			_log(
				source,
				"best updated: tile=%s score=%.2f"
				% [MetaTag.pos_tag(best_tile), best_score],
			)

	if best_tile == source.position:
		_log(source, "intent produced no valid retreat tile")
		return null

	var best_equipped_module: EquippedModule = null
	var best_module_score: float = -INF
	for equipped_module: EquippedModule in utility_modules:
		if not _can_module_target_self(equipped_module.module, source):
			continue

		var module_context: Dictionary = {
			"source": source,
			"target": source,
			"module": equipped_module.module,
			"planning_context": context,
			"tile": best_tile,
		}
		var module_score: float = profile.evaluate_final(module_context)
		if module_score > best_module_score:
			best_module_score = module_score
			best_equipped_module = equipped_module

	var retreat_score_context: Dictionary = {
		"source": source,
		"target": source,
		"planning_context": context,
		"tile": best_tile,
	}
	var retreat_breakdown: Dictionary = profile.evaluate_preliminary_breakdown(retreat_score_context)
	var module_breakdown: Dictionary = {
		"score": best_module_score,
		"components": [],
	}
	if best_equipped_module:
		var module_context: Dictionary = {
			"source": source,
			"target": source,
			"module": best_equipped_module.module,
			"planning_context": context,
			"tile": best_tile,
		}
		module_breakdown = profile.evaluate_final_breakdown(module_context)

	var current_tile_threat: float = context.get_threat(source.position)
	var destination_tile_threat: float = context.get_threat(best_tile)

	_log(
		source,
		(
			"breakdown: tile=%s base=%.2f reachable=%.2f total=%.2f threat: current=%.2f destination=%.2f"
			% [
				best_tile,
				best_base_score,
				best_reachable_bonus,
				best_score,
				current_tile_threat,
				destination_tile_threat,
			]
		),
	)
	for component in retreat_breakdown.components:
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
	if best_equipped_module:
		_log(
			source,
			(
				"module selected (%s): score=%.2f (not added to retreat score)"
				% [best_equipped_module.get_chat_tag(), module_breakdown.score]
			),
		)
		for component in module_breakdown.components:
			_log(
				source,
				(
					"    - %s: input=%.2f curve=%.2f weight=%.2f contrib=%.2f"
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

	return (
		AIPlanBuilder
		. build_plan(
			context,
			AIPlan.Intent.RETREAT,
			clampf(best_score, 0.0, 100.0),
			source,
			best_equipped_module,
			best_tile,
		)
	)


static func _can_module_target_self(module: ItemModule, _source: MapCombatEntity) -> bool:
	for effect: BaseEffect in module.effects:
		if effect.target == Enums.TargetType.SELF or effect.target == Enums.TargetType.AREA:
			return true
	return false


static func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)
