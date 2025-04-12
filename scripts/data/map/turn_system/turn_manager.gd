# This class handles the turn management for a specific game map.
# It is responsible for executing turns, processing orders, and
# managing the game state.
class_name TurnManager
extends Node

# ====================================================================
# SIGNALS
# ====================================================================

# Emitted when the turn is started.
signal on_turn_started(turn_number: int)
# Emitted when the turn is ended.
signal on_turn_ended(turn_number: int)

# ===================================================================
# PROPERTIES
# ===================================================================

# The game map associated with this turn manager.
var game_map: GameMap
# The orders for offensive modules.
var offensive_module_orders: Dictionary[String, UseOffensiveModuleOrder]
# The orders for utility modules.
var utility_module_orders: Dictionary[String, UseUtilityModuleOrder]
# The orders for movement.
var move_orders: Dictionary[String, MoveOrder]
# The AI controller for managing enemy actions.
var ai_controller: AIController

# The current turn number.
var _current_turn: int
# Controls the execute of the turn manager.
var _is_active: bool
# The time interval for each turn.
var _timer: float
# The time interval for each turn in seconds.
var _turn_interval: float

# =================================================================
# PUBLIC API
# =================================================================


func _init(p_game_map: GameMap, p_turn_interval: float = 1.0) -> void:
	"""
	Initialize the turn manager with a game map.
	"""
	# Initialize the game map and other properties.
	game_map = p_game_map
	offensive_module_orders = {}
	utility_module_orders = {}
	move_orders = {}
	ai_controller = AIController.new(game_map)

	# Initialize the internal state.
	_current_turn = 1
	_is_active = false
	_timer = 0.0
	_turn_interval = p_turn_interval

func get_time_of_day() -> float:
	"""
	Returns the current time of day based on the current turn.
	"""
	if not game_map:
		return 0.0
	# Calculate the time of day based on the current turn.
	return (_current_turn % 48) / 48.0


func get_current_turn() -> int:
	"""
	Returns the current turn number.
	"""
	return _current_turn


func is_active() -> bool:
	"""
	Returns whether the turn manager is active.
	"""
	return _is_active


func clear() -> void:
	"""
	Clears the turn manager state.
	"""
	offensive_module_orders.clear()
	utility_module_orders.clear()
	move_orders.clear()
	_current_turn = 1
	if ai_controller:
		ai_controller.queue_free()
		ai_controller = null
	_current_turn = 1
	_is_active = false
	_timer = 0.0
	_turn_interval = 0.0


func start() -> void:
	"""
	Starts the turn manager.
	"""
	_is_active = true
	_current_turn = 1
	_timer = 0.0


func stop() -> void:
	"""
	Stops the turn manager.
	"""
	_is_active = false
	_current_turn = 1
	_timer = 0.0


func tick(delta: float) -> void:
	"""
	Called every frame to update the turn manager.
	"""
	if not game_map:
		return
	if not _is_active:
		return
	# Increment the timer.
	_timer += delta
	# If the timer exceeds the turn interval, execute the turn.
	# This is the main loop for the turn manager.
	if _timer >= _turn_interval:
		# Reset the timer.
		_timer = 0.0
		# Emit the turn started signal.
		on_turn_started.emit(_current_turn)

		# 1) Generate the NPCs order for the current turn.
		_generate_npc_orders()
		# 2) Process utility module activations.
		_execute_utility_module_orders()
		# 3.1) Process offensive module activations.
		_execute_offensive_module_orders()
		# 3.2) Check if any units are destroyed after executing the orders.
		_erase_destroyed_units()
		# 4.1) Reset movement tracking.
		_reset_movement_tracking()
		# 4.2) Process movement orders.
		_execute_move_orders()
		# 5.1) Regenerate all units.
		_regenerate_units()
		# 5.2) Update time-based effects.
		_update_time_based_effects()
		# 5.2) Check if any units are destroyed after executing the orders.
		_erase_destroyed_units()

		# Emit the turn ended signal.
		on_turn_ended.emit(_current_turn)
		# Increment the current turn.
		_current_turn += 1


static func format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# ORDERS
# =============================================================================


func _filter_order_with_dead_mek(_key: String, order) -> bool:
	"""
	Checks if the order is valid and the source and target are not dead.
	"""
	if is_instance_of(order, UseModuleOrder):
		return order.source.mek.is_dead() or order.target.mek.is_dead()
	if is_instance_of(order, MoveOrder):
		return order.source.mek.is_dead()
	return false


func _filter_dead_unit(_key: String, unit: MapEntity) -> bool:
	"""
	Checks if the unit is dead.
	"""
	return unit.mek.is_dead()


func _erase_destroyed_units() -> void:
	"""
	Checks for destroyed units and removes them from the game map.
	"""
	# Find all the orders that has the dead units and remove them.
	Utils.erase(
		offensive_module_orders, Utils.filter(offensive_module_orders, _filter_order_with_dead_mek)
	)
	Utils.erase(
		utility_module_orders, Utils.filter(utility_module_orders, _filter_order_with_dead_mek)
	)
	Utils.erase(move_orders, Utils.filter(move_orders, _filter_order_with_dead_mek))
	# Erase the dead units from the game map.
	Utils.erase(game_map.player_units, Utils.filter(game_map.player_units, _filter_dead_unit))
	Utils.erase(game_map.npc_units, Utils.filter(game_map.npc_units, _filter_dead_unit))


func queue_offensive_module_orders(order: UseOffensiveModuleOrder):
	"""
	Queues an offensive module activation order, replacing any existing one for the unit.
	"""
	if order:
		offensive_module_orders[order.source.mek.uuid] = order


func queue_utility_module_order(order: UseUtilityModuleOrder):
	"""
	Queues a module activation order, replacing any existing one for the unit.
	"""
	if order:
		utility_module_orders[order.source.mek.uuid] = order


func queue_move_order(order: MoveOrder):
	"""
	Queues a movement order, replacing any existing one for the unit.
	"""
	if order:
		move_orders[order.source.mek.uuid] = order


func _execute_offensive_module_orders() -> void:
	"""
	Executes all queued offensive module orders.
	"""
	# Execute the offensive module orders.
	for order in offensive_module_orders.values():
		order.execute(game_map)
	offensive_module_orders.clear()


func _execute_utility_module_orders() -> void:
	"""
	Executes all queued utility module orders.
	"""
	for order in utility_module_orders.values():
		order.execute(game_map)
	utility_module_orders.clear()


func _reset_movement_tracking() -> void:
	"""
	Resets the movement tracking for all Meks.
	"""
	for unit_uuid in game_map.player_units:
		game_map.player_units[unit_uuid].mek.tiles_moved_last_turn = 0
	for unit_uuid in game_map.npc_units:
		game_map.npc_units[unit_uuid].mek.tiles_moved_last_turn = 0


func _execute_move_orders() -> void:
	"""
	Executes all queued movement orders.
	"""
	# Then, execute the orders.
	for order in move_orders.values():
		order.execute(game_map)
	move_orders.clear()


func _regenerate_units() -> void:
	"""
	Regenerates all units.
	"""
	for unit: MapMek in game_map.player_units.values():
		unit.mek.regenerate()
	for unit: MapMek in game_map.npc_units.values():
		unit.mek.regenerate()


func _update_time_based_effects():
	"""
	Updates time-based effects for all units.
	"""
	# Then, tick active effects, cooldowns, and durations.
	for unit: MapMek in game_map.player_units.values() + game_map.npc_units.values():
		# Process time-based effects like DOT, HOT, buffs.
		var dot_result = unit.mek.take_dot_damage()
		if dot_result.total > 0:
			game_map.combat_logger.add_log(Enums.LogType.ATTACK, "%s suffers DOT -> %d shield, %d armor, %d health" % [
				unit.mek.get_chat_tag(),
				dot_result.shield,
				dot_result.armor,
				dot_result.health])


# =============================================================================
# ENEMY AI
# =============================================================================


func _generate_npc_orders():
	"""
	Generates and queues an order for each NPC unit using the AI planner system.
	"""
	for unit: MapMek in game_map.npc_units.values():
		# Generate or reuse the current plan.
		ai_controller.plan_for_unit(unit)
		# Generate the next order based on the current plan.
		var order: Order = ai_controller.generate_order_for_unit(unit)
		# Add the order to the queue.
		if is_instance_of(order, UseUtilityModuleOrder):
			queue_utility_module_order(order)
		elif is_instance_of(order, UseOffensiveModuleOrder):
			queue_offensive_module_orders(order)
		elif is_instance_of(order, MoveOrder):
			queue_move_order(order)
