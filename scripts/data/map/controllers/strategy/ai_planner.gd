class_name AIPlanner
extends RefCounted

const NPC_DIRECTIVE_STATE = preload("res://scripts/data/map/controllers/strategy/npc_directive_state.gd")

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
	var visible_enemies: Array[MapCombatEntity] = _get_visible_enemies(plan.game_map, source)
	if visible_enemies.is_empty():
		return null
	# This will keep track of the best score for the attack.
	var best_score := -INF
	# This will keep track of the best target to attack.
	var best_target = null
	# This will keep track of the best equipped module for the attack.
	var best_equipped_module: EquippedModule = null

	# Iterate through all equipped modules on the source unit.
	for equipped_module in AIUtils.find_matching_modules(source.combatant, true, false, false):
		var module_range: int = equipped_module.module.module_range + source.combatant.range_modifier
		var min_range: int = AIUtils.get_offensive_min_range(module_range)
		# Evaluate enemies currently in sight for this unit.
		for target: MapCombatEntity in visible_enemies:
			if target.combatant.is_dead():
				continue
			# Get the score of the target.			
			var score = AIUtils.score_offensive_module_on_target(equipped_module.module, target)
			var distance_now: float = source.position.distance_to(target.position)
			var in_standoff_band: bool = distance_now >= min_range and distance_now <= module_range
			var can_reach_standoff_this_turn: bool = AIUtils.can_reach_target_this_turn(
				plan.game_map,
				source,
				target,
				min_range,
				module_range,
				source.combatant.speed
			)
			if in_standoff_band:
				score += 8.0
			elif can_reach_standoff_this_turn:
				score += 4.0
			else:
				score -= 12.0
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
	if not source.can_move():
		return null
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
	if not source.can_move():
		return null
	if not _get_visible_enemies(plan.game_map, source).is_empty():
		return null

	var owner_key: String = plan.game_map.get_owner_key(source.owner)
	if owner_key.is_empty():
		return null

	var state: RefCounted = plan.game_map.get_owner_directive(source.owner, source.position)
	if not state:
		return null

	var squad_entities: Array[MapCombatEntity] = plan.game_map.get_owned_combat_entities(source.owner)
	var squad_center: Vector2i = _compute_squad_center(squad_entities, source.position)
	var destination: Vector2i = source.position
	var score: float = 1.0

	match state.directive:
		NPC_DIRECTIVE_STATE.Directive.HOLD_PERIMETER:
			destination = _pick_destination_for_objective(
				plan,
				source,
				squad_center,
				state.anchor_position,
				state.anchor_position,
				state.leash_radius,
				state.compact_radius,
				true
			)
			score = 3.0

		NPC_DIRECTIVE_STATE.Directive.PATROL:
			var patrol_target: Vector2i = state.get_patrol_target()
			destination = _pick_destination_for_objective(
				plan,
				source,
				squad_center,
				patrol_target,
				state.anchor_position,
				state.leash_radius * 2,
				state.compact_radius,
				false
			)
			score = 4.0

		NPC_DIRECTIVE_STATE.Directive.SEEK_AND_DESTROY:
			var enemy_target: MapCombatEntity = AIUtils.get_most_vulnerable_enemy(plan.game_map, source, 9999)
			if enemy_target:
				destination = AIUtils.find_furthest_progress_along_path(
					plan.game_map,
					source.position,
					enemy_target.position,
					source.combatant.speed
				)
			score = 2.0

		NPC_DIRECTIVE_STATE.Directive.DEFEND_POINT:
			var defend_target: Vector2i = state.defend_position
			if defend_target == Vector2i.ZERO:
				defend_target = state.anchor_position
			destination = _pick_destination_for_objective(
				plan,
				source,
				squad_center,
				defend_target,
				defend_target,
				state.leash_radius,
				state.compact_radius,
				true
			)
			score = 3.5

		NPC_DIRECTIVE_STATE.Directive.RETREAT_TO_SAFE_ZONE:
			var safe_target: Vector2i = state.anchor_position
			destination = _pick_destination_for_objective(
				plan,
				source,
				squad_center,
				safe_target,
				safe_target,
				state.leash_radius,
				state.compact_radius,
				true
			)
			score = 4.5

		_:
			destination = source.position

	if destination == Vector2i.ZERO or destination == source.position:
		return null

	# If we have found a valid tile, create a reposition plan.
	var new_plan := AIPlan.new(source, plan.game_map)
	new_plan.intent = AIPlan.Intent.REPOSITION
	new_plan.destination = destination
	new_plan.score = score
	return new_plan


func _get_visible_enemies(game_map, source: MapCombatEntity) -> Array[MapCombatEntity]:
	return AIUtils.get_enemies_in_range(game_map, source, game_map.DEFAULT_DETECTION_RANGE)


func _compute_squad_center(entities: Array[MapCombatEntity], fallback: Vector2i) -> Vector2i:
	if entities.is_empty():
		return fallback

	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y

	return Vector2i(
		int(round(float(sum_x) / entities.size())),
		int(round(float(sum_y) / entities.size())),
	)


func _pick_destination_for_objective(
	plan: AIPlan,
	source: MapCombatEntity,
	squad_center: Vector2i,
	objective: Vector2i,
	leash_center: Vector2i,
	leash_radius: int,
	compact_radius: int,
	prefer_low_threat: bool
) -> Vector2i:
	var reachable_tiles: Array[Vector2i] = AIUtils.get_reachable_tiles(
		plan.game_map,
		source.position,
		source.combatant.speed
	)

	var best_tile: Vector2i = source.position
	var best_score: float = -INF

	for tile in reachable_tiles:
		if plan.game_map.is_occupied(tile):
			continue
		if leash_center != Vector2i.ZERO and tile.distance_to(leash_center) > leash_radius:
			continue
		if tile.distance_to(squad_center) > compact_radius:
			continue

		var threat: float = AIUtils.get_threat_level(plan.game_map, tile, source)
		var objective_distance: float = tile.distance_to(objective)
		var cohesion_distance: float = tile.distance_to(squad_center)

		var score: float = 0.0
		if prefer_low_threat:
			score += -threat * 1.6
			score += -objective_distance * 1.1
		else:
			score += -threat * 0.5
			score += -objective_distance * 1.6
		score += -cohesion_distance * 1.3

		if score > best_score:
			best_score = score
			best_tile = tile

	return best_tile
