class_name AIController
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# A reference to the game map.
var game_map

# Create a planner instance and generate a plan.
var _planner = AIPlanner.new()
# The current plans for the AI.
var _current_plans: Dictionary[String, AIPlan] = {}
# The orders for offensive modules.
var _use_offensive_module_orders: Dictionary[String, UseOffensiveModuleOrder] = {}
# The orders for utility modules.
var _use_utility_module_orders: Dictionary[String, UseUtilityModuleOrder] = {}
# The orders for movement.
var _move_orders: Dictionary[String, MoveOrder] = {}

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================


func _init(p_game_map) -> void:
	"""
	Initialize the AI controller with a game map.
	"""
	game_map = p_game_map


func log_message(msg: String):
	"""
	Logs a message to the game server and the combat logger.
	"""
	GameServer.log_message(msg)


func clear():
	"""
	Clears the internal state of the AI controller.
	"""
	_current_plans.clear()
	_clear_orders()


func _add_log(message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.AI, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


func get_current_plan(source) -> AIPlan:
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


func queue_offensive_module_order(order: UseOffensiveModuleOrder):
	"""
	Queues an offensive module order, replacing any existing one for the unit.
	"""
	if order:
		_use_offensive_module_orders[order.source.combatant.uuid] = order


func queue_utility_module_order(order: UseUtilityModuleOrder):
	"""
	Queues a utility module order, replacing any existing one for the unit.
	"""
	if order:
		_use_utility_module_orders[order.source.combatant.uuid] = order


func queue_move_order(order: MoveOrder):
	"""
	Queues a movement order, replacing any existing one for the unit.
	"""
	if order:
		_move_orders[order.source.combatant.uuid] = order


func execute_utility_module_orders() -> void:
	"""
	Executes all queued utility module orders.
	"""
	for order in _use_utility_module_orders.values():
		order.execute(game_map)
	_use_utility_module_orders.clear()


func execute_offensive_module_orders() -> void:
	"""
	Executes all queued offensive module orders.
	"""
	for order in _use_offensive_module_orders.values():
		order.execute(game_map)
	_use_offensive_module_orders.clear()


func execute_move_orders() -> void:
	"""
	Executes all queued movement orders.
	"""
	# Resets the movement tracking for all Meks.
	for unit_uuid in game_map.player_units:
		game_map.player_units[unit_uuid].combatant.tiles_moved_last_turn = 0
	for unit_uuid in game_map.npc_units:
		game_map.npc_units[unit_uuid].combatant.tiles_moved_last_turn = 0
	# Execute all queued movement orders.
	for order in _move_orders.values():
		order.execute(game_map)
	_move_orders.clear()


func plan_for_unit(source) -> void:
	"""
	Generates a plan for the given unit if the current one is missing or no longer valid.
	"""
	if source.combatant.is_alive():
		# Check if we already have a valid plan.
		var current_plan = get_current_plan(source)
		# If the plan is valid, no need to re-plan.
		if current_plan and current_plan.is_valid():
			return
		# Get the clan aggressiveness and generate a plan.
		var aggressiveness = source.owner.clan.aggressiveness
		# Generate the plan for the source unit.
		var new_plan = _planner.generate_plan(source, game_map, aggressiveness)
		# Save the new plan.
		_current_plans[source.combatant.uuid] = new_plan


func generate_orders_for_unit(source) -> void:
	"""
	Generates an order for the given unit based on its current plan.
	If the plan is invalid or has been completed, re-planning may occur.
	"""
	if source.combatant.is_dead():
		# If the unit is dead, no order can be generated.
		return
	
	# Ensure the unit has a current plan, or regenerate if needed.
	plan_for_unit(source)

	# Retrieve the current plan from the cache.
	var current_plan = get_current_plan(source)

	# If no plan is available, return.
	if not current_plan:
		return

	if not current_plan.is_valid():
		# If the plan is invalid, we need to re-plan.
		return

	# If the plan is already complete, there's nothing left to do this turn.
	if current_plan.is_complete():
		return
	
	# Generate the order for the current plan.
	var order = current_plan.generate_order()

	_add_log("%s generated order for plan %s : %s" % [source.combatant.get_chat_tag(), str(current_plan), str(order)])

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


func generate_npc_orders():
	"""
	Generates and queues an order for each NPC unit using the AI planner system.
	"""
	for unit in game_map.npc_units.values():
		# Generate or reuse the current plan.
		game_map.ai_controller.plan_for_unit(unit)
		# Generate the next order based on the current plan.
		game_map.ai_controller.generate_orders_for_unit(unit)


func _filter_order_with_dead_mek(_key: String, order) -> bool:
	"""
	Checks if the order is valid and the source and target are not dead.
	"""
	if is_instance_of(order, UseModuleOrder):
		return order.source.combatant.is_dead() or order.target.combatant.is_dead()
	if is_instance_of(order, MoveOrder):
		return order.source.combatant.is_dead()
	return false


func _clear_orders() -> void:
	"""
	Clears all orders for the AI controller.
	"""
	_use_offensive_module_orders.clear()
	_use_utility_module_orders.clear()
	_move_orders.clear()
