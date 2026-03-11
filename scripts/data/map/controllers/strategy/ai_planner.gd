class_name AIPlanner
extends RefCounted

# =============================================================================
# PLAN GENERATION ENTRY POINT
# =============================================================================

func generate_plan(source, game_map, aggressiveness: float = 1.0) -> AIPlan:
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
	var source = plan.source
	# This will keep track of the best score for the attack.
	var best_score := -INF
	# This will keep track of the best target to attack.
	var best_target = null
	# This will keep track of the best equipped module for the attack.
	var best_equipped_module: EquippedModule = null

	# Iterate through all equipped modules on the source unit.
	for equipped_module in AIUtils.find_matching_modules(source.combatant, true, false, false):
		# Get all the enemies in range.
		for target in AIUtils.get_enemies_in_range(plan.game_map, source, 999):
			if target.combatant.is_dead():
				continue
			# Get the score of the target.			
			var score = AIUtils.score_offensive_module_on_target(equipped_module.module, target)
			# Scale the score based on the aggressiveness level.
			score *= lerp(1.0, 1.2, aggressiveness)
			# If the score is higher than the best score, update the best score and target.
			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module
	
	# If we have found a valid target, create an attack plan.
	if best_target:
		var new_plan := AIPlan.new(source, plan.game_map)
		new_plan.intent = AIPlan.Intent.ATTACK
		new_plan.target = best_target
		new_plan.equipped_module = best_equipped_module
		new_plan.destination = Vector2i.ZERO
		new_plan.score = clamp(best_score, 0, 100)
		return new_plan
	return null


func _evaluate_support_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source = plan.source
	# This will keep track of the best score for the support action.
	var best_score := -INF
	# This will keep track of the best target to support.
	var best_target = null
	# This will keep track of the best equipped module to use.
	var best_equipped_module: EquippedModule = null

	# Iterate through all utility modules the unit can currently use.
	for equipped_module in AIUtils.find_matching_modules(source.combatant, false, false, false):
		# Get all allies within the range of this module.
		for target in [source] + AIUtils.get_allies_in_range(plan.game_map, source, 999):
			if target.combatant.is_dead():
				continue
			# Score how useful the module would be on this target.
			var score := AIUtils.score_utility_module_on_target(equipped_module.module, source, target)
			# Update best values if this is the most promising so far.
			if score > best_score:
				best_score = score
				best_target = target
				best_equipped_module = equipped_module
				if source == target:
					best_score *= 1.5 # Boost the score if the source is the target.


	# If we found a valuable support plan, return it.
	if best_target:
		var new_plan := AIPlan.new(source, plan.game_map)
		new_plan.intent = AIPlan.Intent.SUPPORT
		new_plan.target = best_target
		new_plan.equipped_module = best_equipped_module
		new_plan.destination = Vector2i.ZERO
		new_plan.score = clamp(best_score, 0, 100)
		return new_plan

	return null


func _evaluate_retreat_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source = plan.source
	# Get the current thread level.
	var current_threat: float = AIUtils.get_threat_level(plan.game_map, source.position, source)
	# Get the health ratio of the source unit.
	var health_ratio := float(source.combatant.health + source.combatant.armor + source.combatant.shield) / float(source.combatant.max_health + source.combatant.max_armor + source.combatant.max_shield)
	# This will keep track of the best equipped module to use.
	var best_equipped_module: EquippedModule = null

	# Check if the source unit is in a critical state.
	if health_ratio > 0.5 and current_threat < 10:
		return null

	# This will keep track of the tile.
	var best_tile: Vector2i = source.position
	# This will keep track of the best score for the retreat (lower is better).
	var best_score: float = INF

	# Evaluate all reachable tiles within the unit's speed.
	for tile in AIUtils.get_reachable_tiles(plan.game_map, source.position, source.combatant.speed):
		# Check if the tile is occupied by an enemy unit.
		if plan.game_map.is_occupied(tile):
			continue
		# Get the threat level of the tile.
		var threat := AIUtils.get_threat_level(plan.game_map, tile, source)
		# Check if the tile is a better retreat option.
		if threat < best_score:
			best_score = threat
			best_tile = tile

	# Look for a valid emergency utility module (self-use only)
	for equipped_module in AIUtils.find_matching_modules(source.combatant, false, false, false):
		var score := AIUtils.score_utility_module_on_target(equipped_module.module, source, source)
		if score > best_score:
			best_score = score
			best_equipped_module = equipped_module

	# If the best tile is the same as the source position, we can't retreat.
	if best_tile == source.position:
		return null

	# Build the retreat plan.
	var new_plan := AIPlan.new(source, plan.game_map)
	new_plan.intent = AIPlan.Intent.RETREAT
	new_plan.target = source
	new_plan.equipped_module = best_equipped_module
	new_plan.destination = best_tile
	new_plan.score = clamp(best_score, 0, 100)
	return new_plan


func _evaluate_reposition_intent(plan: AIPlan) -> AIPlan:
	# Get the source unit from the plan.
	var source = plan.source
	# Find a random reachable tile within the unit's speed.
	var fallback_tile = AIUtils.find_random_reachable_tile(plan.game_map, source.position, source.combatant.speed)
 	# If the fallback tile is the same as the source position, we can't reposition.
	if fallback_tile == Vector2i.ZERO or fallback_tile == source.position:
		return null
	# If we have found a valid tile, create a reposition plan.
	var new_plan := AIPlan.new(source, plan.game_map)
	new_plan.intent = AIPlan.Intent.REPOSITION
	new_plan.destination = fallback_tile
	new_plan.score = 1
	return new_plan
