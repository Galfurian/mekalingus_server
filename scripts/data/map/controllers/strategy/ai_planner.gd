class_name AIPlanner
extends RefCounted

const INTENT_PRIORITY = {
	AIPlan.Intent.ATTACK: 100,
	AIPlan.Intent.SUPPORT: 80,
	AIPlan.Intent.RETREAT: 60,
	AIPlan.Intent.REPOSITION: 10
}

# =============================================================================
# PLAN GENERATION ENTRY POINT
# =============================================================================

func generate_plan(source: MapMek, game_map: GameMap, aggressiveness: float = 1.0) -> AIPlan:
	var plan := AIPlan.new(source, game_map)
	var best_score := -INF

	# Evaluate all intents
	var attack_plan = _evaluate_attack_intent(plan, aggressiveness)
	if attack_plan and attack_plan.score > best_score:
		plan = attack_plan
		best_score = plan.score

	var support_plan = _evaluate_support_intent(plan)
	if support_plan and support_plan.score > best_score:
		plan = support_plan
		best_score = plan.score

	var retreat_plan = _evaluate_retreat_intent(plan)
	if retreat_plan and retreat_plan.score > best_score:
		plan = retreat_plan
		best_score = plan.score
	
	var reposition_plan = _evaluate_reposition_intent(plan)
	if reposition_plan and reposition_plan.score > best_score:
		plan = reposition_plan
		best_score = plan.score

	return plan

# =============================================================================
# INTENT EVALUATORS
# =============================================================================

func _evaluate_attack_intent(plan: AIPlan, aggressiveness: float) -> AIPlan:
	# Get the source unit from the plan.
	var source: MapMek = plan.source
	# This will keep track of the best score for the attack.
	var best_score := -INF
	# This will keep track of the best target to attack.
	var best_target: MapMek = null
	# This will keep track of the best equipped module for the attack.
	var best_equipped_module: EquippedModule = null

	# Iterate through all equipped modules on the source unit.
	for equipped_module in AIUtils.find_matching_modules(source.mek, true, false, false):
		# Get all the enemies in range.
		for target in AIUtils.get_enemies_in_range(plan.game_map, source, 999):
			if target.mek.is_dead():
				continue
			# Get the priority of the target.			
			var priority = AIUtils.score_offensive_module_on_target(equipped_module.module, target)
			# Scale the priority based on the aggressiveness level.
			priority *= lerp(1.0, 1.2, aggressiveness)
			# If the priority is higher than the best score, update the best score and target.
			if priority > best_score:
				best_score = priority
				best_target = target
				best_equipped_module = equipped_module
	
	# If we have found a valid target, create an attack plan.
	if best_target:
		var attack_plan := AIPlan.new(source, plan.game_map)
		attack_plan.intent = AIPlan.Intent.ATTACK
		attack_plan.phase = AIPlan.Phase.MOVE_THEN_ACT
		attack_plan.target = best_target
		attack_plan.equipped_module = best_equipped_module
		attack_plan.destination = Vector2i.ZERO
		attack_plan.score = clamp(best_score, 0, 100) + INTENT_PRIORITY[AIPlan.Intent.ATTACK]
		return attack_plan
	return null


func _evaluate_support_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source: MapMek = plan.source
	# This will keep track of the best score for the support action.
	var best_score := -INF
	# This will keep track of the best target to support.
	var best_target: MapMek = null
	# This will keep track of the best equipped module to use.
	var best_equipped_module: EquippedModule = null

	# Iterate through all utility modules the unit can currently use.
	for equipped_module in AIUtils.find_matching_modules(source.mek, false, false, false):
		# Get all allies within the range of this module.
		for target in [source] + AIUtils.get_allies_in_range(plan.game_map, source, 999):
			if target.mek.is_dead():
				continue
			# Score how useful the module would be on this target.
			var priority := AIUtils.score_utility_module_on_target(equipped_module.module, source, target)
			# Update best values if this is the most promising so far.
			if priority > best_score:
				best_score = priority
				best_target = target
				best_equipped_module = equipped_module


	# If we found a valuable support plan, return it.
	if best_target:
		var support_plan := AIPlan.new(source, plan.game_map)
		support_plan.intent = AIPlan.Intent.SUPPORT
		support_plan.phase = AIPlan.Phase.MOVE_THEN_ACT
		support_plan.target = best_target
		support_plan.equipped_module = best_equipped_module
		support_plan.destination = Vector2i.ZERO
		support_plan.score = clamp(best_score, 0, 100) + INTENT_PRIORITY[AIPlan.Intent.SUPPORT]
		return support_plan

	return null


func _evaluate_retreat_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source: MapMek = plan.source
	# Get the current thread level.
	var current_threat: float = AIUtils.get_threat_level(plan.game_map, source.position, source)
	# Get the health ratio of the source unit.
	var health_ratio := float(source.mek.health + source.mek.armor + source.mek.shield) / float(source.mek.max_health + source.mek.max_armor + source.mek.max_shield)

	# Check if the source unit is in a critical state.
	if health_ratio > 0.5 and current_threat < 10:
		return null

	# This will keep track of the tile.
	var best_tile: Vector2i = source.position
	# This will keep track of the best score for the retreat (lower is better).
	var best_score: float = INF

	# Evaluate all reachable tiles within the unit's speed.
	for tile in AIUtils.get_reachable_tiles(plan.game_map, source.position, source.mek.speed):
		# Check if the tile is occupied by an enemy unit.
		if plan.game_map.is_occupied(tile):
			continue
		# Get the threat level of the tile.
		var threat := AIUtils.get_threat_level(plan.game_map, tile, source)
		# Check if the tile is a better retreat option.
		if threat < best_score:
			best_score = threat
			best_tile = tile

	# If the best tile is the same as the source position, we can't retreat.
	if best_tile == source.position:
		return null

	# Build the retreat plan.
	var retreat_plan := AIPlan.new(source, plan.game_map)
	retreat_plan.intent = AIPlan.Intent.RETREAT
	retreat_plan.phase = AIPlan.Phase.MOVE_THEN_ACT
	retreat_plan.destination = best_tile
	retreat_plan.score = INTENT_PRIORITY[AIPlan.Intent.RETREAT] + clamp(best_score, 0, 100)
	return retreat_plan


func _evaluate_reposition_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source: MapMek = plan.source
	# Find a random reachable tile within the unit's speed.
	var fallback_tile = AIUtils.find_random_reachable_tile(plan.game_map, source.position, source.mek.speed)
 	# If the fallback tile is the same as the source position, we can't reposition.
	if fallback_tile == Vector2i.ZERO or fallback_tile == source.position:
		return null
	# If we have found a valid tile, create a reposition plan.
	var reposition_plan := AIPlan.new(source, plan.game_map)
	reposition_plan.intent = AIPlan.Intent.REPOSITION
	reposition_plan.phase = AIPlan.Phase.MOVE_THEN_ACT
	reposition_plan.destination = fallback_tile
	reposition_plan.score = INTENT_PRIORITY[AIPlan.Intent.REPOSITION]
	return reposition_plan
