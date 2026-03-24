class_name AIController
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

# Enable AI action recovery (replan & reissue) when orders become invalid mid-turn.
const ENABLE_ACTION_RECOVERY: bool = true

# =============================================================================
# PROPERTIES
# =============================================================================

# A reference to the game map.
var game_map: GameMap
# Create a planner instance and generate a plan.
var planner: AIPlanner

# The current plans for the AI.
var _current_plans: Dictionary[String, AIPlan] = {}
# The orders for offensive modules.
var _use_offensive_module_orders: Dictionary[String, UseOffensiveModuleOrder] = {}
# The orders for utility modules.
var _use_utility_module_orders: Dictionary[String, UseUtilityModuleOrder] = {}
# The orders for movement.
var _move_orders: Dictionary[String, MoveOrder] = {}
# Tiles reserved by queued movement to reduce allied collisions.
var _reserved_move_tiles: Dictionary = {}

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================


func _init(p_game_map: GameMap) -> void:
	"""
	Initialize the AI controller with a game map.
	"""
	assert(p_game_map, "AIController requires a valid GameMap reference.")
	game_map = p_game_map
	planner = AIPlanner.new(p_game_map)


func log_message(msg: String) -> void:
	"""
	Logs a message to the game server and the combat logger.
	"""
	GameServer.log_message(msg)


func clear() -> void:
	"""
	Clears the internal state of the AI controller.
	"""
	_current_plans.clear()
	_use_offensive_module_orders.clear()
	_use_utility_module_orders.clear()
	_move_orders.clear()
	_reserved_move_tiles.clear()


func _add_action_log(message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.AI, message)
		return


func _add_thought(source: MapCombatEntity, message: String) -> void:
	if not source or not source.combatant:
		return
	source.combatant.add_ai_thought(message)


func _format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


func get_current_plan(source: MapCombatEntity) -> AIPlan:
	"""
	Retrieves the current plan for the given unit.
	"""
	return _current_plans.get(source.combatant.uuid, null)


func remove_orders_of_dead_units() -> void:
	"""
	Removes orders and plans for dead units.
	"""
	for key in Utils.filter(_use_offensive_module_orders, _filter_order_with_dead_mek):
		_use_offensive_module_orders.erase(key)
	for key in Utils.filter(_use_utility_module_orders, _filter_order_with_dead_mek):
		_use_utility_module_orders.erase(key)
	for key in Utils.filter(_move_orders, _filter_order_with_dead_mek):
		_move_orders.erase(key)
	for unit_uuid in game_map.player_units:
		if game_map.player_units[unit_uuid].combatant.is_dead():
			_current_plans.erase(unit_uuid)
	for unit_uuid in game_map.npc_units:
		if game_map.npc_units[unit_uuid].combatant.is_dead():
			_current_plans.erase(unit_uuid)
	for structure_uuid in game_map.structures:
		if game_map.structures[structure_uuid].combatant.is_dead():
			_current_plans.erase(structure_uuid)


func queue_offensive_module_order(order: UseOffensiveModuleOrder) -> void:
	"""
	Queues an offensive module order, replacing any existing one for the unit.
	"""
	if order:
		_use_offensive_module_orders[order.source.combatant.uuid] = order
		_add_thought(order.source, "Queued: %s" % str(order))


func queue_utility_module_order(order: UseUtilityModuleOrder) -> void:
	"""
	Queues a utility module order, replacing any existing one for the unit.
	"""
	if order:
		_use_utility_module_orders[order.source.combatant.uuid] = order
		_add_thought(order.source, "Queued: %s" % str(order))


func queue_move_order(order: MoveOrder) -> void:
	"""
	Queues a movement order, replacing any existing one for the unit.
	"""
	if order:
		_move_orders[order.source.combatant.uuid] = order
		_reserved_move_tiles[_tile_key(order.destination)] = true
		_add_thought(order.source, "Queued: %s" % str(order))


func _process_order_with_recovery(order: Order, expected_type: Object) -> void:
	"""Executes an order and optionally reissues it if invalid."""
	if not order or not is_instance_of(order, expected_type):
		return

	if order.validate():
		order.execute(game_map)
		_add_thought(order.source, "Executed: %s" % str(order))
	else:
		_add_thought(order.source, "Invalid: %s" % str(order))
		if ENABLE_ACTION_RECOVERY:
			var replacement: Order = _reissue_order_for_source(order.source)
			if replacement:
				if is_instance_of(replacement, expected_type):
					replacement.execute(game_map)
					_add_thought(replacement.source, "Executed replacement: %s" % str(replacement))
				elif replacement:
					_queue_generated_order(replacement)

	var plan: AIPlan = get_current_plan(order.source)
	if plan and plan.is_complete():
		_add_thought(order.source, "Completed: %s" % str(plan))


func execute_utility_module_orders() -> void:
	"""
	Executes all queued utility module orders.
	"""
	for source_uuid: String in _use_utility_module_orders.keys():
		var order: UseUtilityModuleOrder = _use_utility_module_orders[source_uuid]
		if not order:
			continue
		_process_order_with_recovery(order, UseUtilityModuleOrder)
	_use_utility_module_orders.clear()


func execute_offensive_module_orders() -> void:
	"""
	Executes all queued offensive module orders.
	"""
	for source_uuid: String in _use_offensive_module_orders.keys():
		var order: UseOffensiveModuleOrder = _use_offensive_module_orders[source_uuid]
		if not order:
			continue
		_process_order_with_recovery(order, UseOffensiveModuleOrder)
	_use_offensive_module_orders.clear()


func _process_move_order_with_recovery(order: MoveOrder) -> void:
	"""Executes a move order, with optional recovery when it becomes invalid."""
	if not order or not order.source or order.source.combatant.is_dead():
		return

	if order.destination == order.source.position:
		_add_thought(order.source, "Skipped move order (already at destination): %s" % str(order))
		return

	if game_map.is_occupied(order.destination):
		_add_thought(order.source, "Skipped move order (destination occupied): %s" % str(order))
		if ENABLE_ACTION_RECOVERY:
			var replacement: Order = _reissue_order_for_source(order.source)
			if replacement and is_instance_of(replacement, MoveOrder):
				_process_move_order_with_recovery(replacement)
			elif replacement:
				_queue_generated_order(replacement)
		return

	_reserved_move_tiles[_tile_key(order.destination)] = true
	order.execute(game_map)
	_add_thought(order.source, "Executed: %s" % str(order))

	var plan: AIPlan = get_current_plan(order.source)
	if plan and plan.is_complete():
		_add_thought(order.source, "Completed: %s" % str(plan))


func execute_move_orders() -> void:
	"""
	Executes all queued movement orders.
	"""
	# Reset movement tracking for all combat entities that may move.
	for unit_uuid in game_map.player_units:
		game_map.player_units[unit_uuid].combatant.tiles_moved_last_turn = 0
	for unit_uuid in game_map.npc_units:
		game_map.npc_units[unit_uuid].combatant.tiles_moved_last_turn = 0
	for structure_uuid in game_map.structures:
		game_map.structures[structure_uuid].combatant.tiles_moved_last_turn = 0
	_reserved_move_tiles.clear()
	# Execute movement orders in descending plan-score order and revalidate just-in-time.
	var source_ids: Array[String] = _move_orders.keys()
	source_ids.sort_custom(
		func(a: String, b: String):
			var score_a: float = _get_plan_score(a)
			var score_b: float = _get_plan_score(b)
			return score_a > score_b
	)

	for source_uuid: String in source_ids:
		var order: MoveOrder = _move_orders.get(source_uuid, null)
		_process_move_order_with_recovery(order)

	_move_orders.clear()
	_reserved_move_tiles.clear()


func plan_for_unit(source: MapCombatEntity) -> void:
	"""
	Generates a plan for the given unit if the current one is missing or no longer valid.
	"""
	# If the unit is dead, no order can be generated.
	if not source.combatant.is_alive():
		return

	if not _validate_profile_binding_for_source(source):
		_add_thought(source, "Missing or invalid AI profile binding; planning skipped.")
		return

	# Check if we already have a valid plan.
	var current_plan: AIPlan = get_current_plan(source)

	# If the plan is valid, no need to re-plan.
	if current_plan and current_plan.is_valid():
		return

	# Generate the plan for the source unit.
	var new_plan: AIPlan = planner.generate_plan(source)

	if not new_plan or not new_plan.is_valid():
		return
	# Save the new plan.
	_current_plans[source.combatant.uuid] = new_plan

	_add_thought(source, "Planned: %s" % str(new_plan))


func _validate_profile_binding_for_source(source: MapCombatEntity) -> bool:
	if not source or not source.owner:
		return false

	var profile_id: String = ""
	if is_instance_of(source.owner, NPCOwned):
		profile_id = (source.owner as NPCOwned).ai_profile_path

	if profile_id.strip_edges().is_empty() and source.owner.clan:
		profile_id = source.owner.clan.ai_profile_path

	if profile_id.strip_edges().is_empty():
		profile_id = AIProfileManager.DEFAULT_PROFILE_ID

	return AIProfileManager.validate_profile_id(profile_id)


func generate_orders_for_unit(source: MapCombatEntity) -> void:
	"""
	Generates an order for the given unit based on its current plan.
	If the plan is invalid or has been completed, re-planning may occur.
	"""
	# If the unit is dead, no order can be generated.
	if source.combatant.is_dead():
		return

	# Ensure the unit has a current plan, or regenerate if needed.
	plan_for_unit(source)

	# Retrieve the current plan from the cache.
	var current_plan: AIPlan = get_current_plan(source)

	# If still no valid plan, we cannot generate an order.
	if not current_plan or not current_plan.is_valid():
		return

	# If the plan is already complete, there's nothing left to do this turn.
	if current_plan.is_complete():
		return

	# Generate the order for the current plan.
	var order: Order = current_plan.generate_order(_reserved_move_tiles)
	if not order:
		_add_thought(
			source,
			(
				"%s plan generated no order; attempting one replan pass."
				% source.combatant.get_chat_tag()
			)
		)
		_current_plans.erase(source.combatant.uuid)
		plan_for_unit(source)
		current_plan = get_current_plan(source)
		if current_plan and current_plan.is_valid() and not current_plan.is_complete():
			order = current_plan.generate_order(_reserved_move_tiles)
		if not order:
			_current_plans.erase(source.combatant.uuid)
			_add_thought(
				source, "%s has no actionable order this turn." % source.combatant.get_chat_tag()
			)
		return

	_add_thought(source, "New order: %s" % str(order))
	_queue_generated_order(order)


func _queue_generated_order(order: Order) -> void:
	if not order:
		return

	if is_instance_of(order, UseOffensiveModuleOrder):
		# If the order is an offensive module order, queue it.
		queue_offensive_module_order(order)
	elif is_instance_of(order, UseUtilityModuleOrder):
		# If the order is a utility module order, queue it.
		queue_utility_module_order(order)
	elif is_instance_of(order, MoveOrder):
		# If the order is a movement order, queue it.
		queue_move_order(order)
	else:
		push_error("Unknown order type: %s" % str(order))


func _reissue_order_for_source(source: MapCombatEntity) -> Order:
	if not source or source.combatant.is_dead():
		return null
	_current_plans.erase(source.combatant.uuid)
	plan_for_unit(source)
	var refreshed_plan: AIPlan = get_current_plan(source)
	if not refreshed_plan or not refreshed_plan.is_valid() or refreshed_plan.is_complete():
		return null
	var replacement: Order = refreshed_plan.generate_order()
	if replacement:
		_add_thought(
			source,
			(
				"%s regenerated order after invalidation: %s"
				% [
					source.combatant.get_chat_tag(),
					str(replacement),
				]
			)
		)
	return replacement


func _iter_ai_controlled_entities() -> Array[MapCombatEntity]:
	var entities: Array[MapCombatEntity] = []

	for unit: MapCombatEntity in game_map.npc_units.values():
		if unit and unit.active and unit.combatant.is_alive():
			entities.append(unit)

	for structure: MapStructure in game_map.structures.values():
		if not structure or not structure.active or structure.combatant.is_dead():
			continue
		entities.append(structure)

	return entities


func generate_ai_orders() -> void:
	"""
	Generates and queues one order for each AI-controlled combat entity.
	"""
	_reserved_move_tiles.clear()
	game_map.directive_planner.advance_patrol_directives()
	var units: Array[MapCombatEntity] = _iter_ai_controlled_entities()
	units.sort_custom(
		func(a: MapCombatEntity, b: MapCombatEntity):
			return a.combatant.evaluate_combat_power() > b.combatant.evaluate_combat_power()
	)

	for unit: MapCombatEntity in units:
		# Generate or reuse the current plan.
		plan_for_unit(unit)
		# Generate the next order based on the current plan.
		generate_orders_for_unit(unit)


func precompute_next_turn_plans() -> void:
	"""
	Precomputes plans for the upcoming turn.

	This is intended to populate the plan cache after the current turn
	finishes so UI can display what the AI intends to do next.
	"""
	if not game_map:
		return

	_reserved_move_tiles.clear()

	for unit: MapCombatEntity in _iter_ai_controlled_entities():
		plan_for_unit(unit)


func _filter_order_with_dead_mek(_key: String, order) -> bool:
	"""
	Checks if the order is valid and the source and target are not dead.
	"""
	if is_instance_of(order, UseModuleOrder):
		return order.source.combatant.is_dead() or order.target.combatant.is_dead()
	if is_instance_of(order, MoveOrder):
		return order.source.combatant.is_dead()
	return false


func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]


func _get_plan_score(source_uuid: String) -> float:
	var plan: AIPlan = _current_plans.get(source_uuid, null)
	if not plan:
		return -INF
	return plan.score


func export_ai_baseline_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"turn":
		game_map.turn_manager.get_current_turn() if game_map and game_map.turn_manager else -1,
		"units": [],
	}

	for unit: MapCombatEntity in _iter_ai_controlled_entities():
		var plan: AIPlan = get_current_plan(unit)
		var unit_entry: Dictionary = {
			"uuid": unit.combatant.uuid,
			"unit": unit.combatant.get_chat_tag(),
			"position": unit.position,
			"has_plan": plan != null,
		}

		if plan:
			unit_entry["intent"] = AIPlan.Intent.keys()[plan.intent]
			unit_entry["score"] = plan.score
			unit_entry["destination"] = plan.destination
			if plan.target and plan.target.combatant:
				unit_entry["target"] = plan.target.combatant.get_chat_tag()
			if plan.equipped_module:
				unit_entry["item"] = plan.equipped_module.item.item_id
				unit_entry["module"] = plan.equipped_module.get_chat_tag()
			if plan.decision_trace:
				unit_entry["decision_trace"] = plan.decision_trace.to_dict()

		snapshot["units"].append(unit_entry)

	return snapshot
