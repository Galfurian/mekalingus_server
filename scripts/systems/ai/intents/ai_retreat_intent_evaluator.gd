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
	var best_module_score: float = -INF
	var best_used_module: bool = false
	var best_reachable_bonus: float = 0.0
	var best_equipped_module: EquippedModule = null
	var max_targets: int = mini(profile.get_max_targets_to_narrow_phase(), candidate_tiles.size())
	var module_score: float = 0.0

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

		best_module_score = -INF
		var selected_module: EquippedModule = null
		for equipped_module: EquippedModule in utility_modules:
			if not _can_module_target_self(equipped_module.module, source):
				continue

			var module_context: Dictionary = {
				"source": source,
				"target": source,
				"module": equipped_module.module,
				"planning_context": context,
				"tile": tile,
			}
			module_score = profile.evaluate_final(module_context)
			if module_score > best_module_score:
				best_module_score = module_score
				selected_module = equipped_module

		var score_context: Dictionary = {
			"source": source,
			"target": source,
			"planning_context": context,
			"tile": tile,
		}
		var base_score: float = profile.evaluate_final(score_context)
		module_score = best_module_score
		var used_module: bool = false
		if selected_module and module_score > base_score:
			used_module = true
		var score: float = maxf(base_score, module_score)
		var reachable_bonus: float = 0.0
		if tile != source.position:
			reachable_bonus = profile.reachable_bonus
			score += reachable_bonus

		if score > best_score:
			best_score = score
			best_module_score = module_score
			best_used_module = used_module
			best_reachable_bonus = reachable_bonus
			best_tile = tile
			best_equipped_module = selected_module

	if best_tile == source.position:
		return null

	var retreat_score_context: Dictionary = {
		"source": source,
		"target": source,
		"planning_context": context,
		"tile": best_tile,
	}
	var retreat_breakdown: Dictionary = profile.evaluate_final_breakdown(retreat_score_context)
	var module_breakdown: Dictionary = {
		"score": best_module_score,
		"components": [],
	}
	if best_used_module and best_equipped_module:
		var module_context: Dictionary = {
			"source": source,
			"target": source,
			"module": best_equipped_module.module,
			"planning_context": context,
			"tile": best_tile,
		}
		module_breakdown = profile.evaluate_final_breakdown(module_context)

	_log(
		source,
		(
			"breakdown: tile=%s base=%.2f module=%.2f reachable=%.2f total=%.2f"
			% [
				best_tile,
				retreat_breakdown.score,
				best_module_score,
				best_reachable_bonus,
				best_score,
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
	if best_used_module:
		_log(
			source,
			"Module breakdown (%s): score=%.2f"
			% [best_equipped_module.get_chat_tag(), module_breakdown.score],
		)
		for component in module_breakdown.components:
			_log(
				source,
				"    - %s: input=%.2f curve=%.2f weight=%.2f contrib=%.2f"
				% [
					component.get("name"),
					component.get("normalized_input"),
					component.get("curve"),
					component.get("weight"),
					component.get("contribution"),
				],
			)

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
