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

# ====================================================================
# CONSTANTS
# ====================================================================

# The maximum number of turns in a day.
const TURNS_PER_DAY: int = 48

# ===================================================================
# PROPERTIES
# ===================================================================

# The game map associated with this turn manager.
var game_map: Object

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


func _init(p_game_map, p_turn_interval: float = 1.0) -> void:
	"""
	Initialize the turn manager with a game map.
	"""
	# Initialize the game map.
	game_map = p_game_map

	# Initialize the internal state.
	_current_turn = int(TURNS_PER_DAY / 2.0)
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
	return (_current_turn % TURNS_PER_DAY) / float(TURNS_PER_DAY)


func get_current_turn() -> int:
	"""
	Returns the current turn number.
	"""
	return _current_turn


func get_turn_interval() -> float:
	"""
	Returns the current round duration in seconds.
	"""
	return _turn_interval


func get_time_until_next_turn() -> float:
	"""
	Returns remaining time before the next automatic turn execution.
	"""
	if not _is_active:
		return 0.0
	return maxf(0.0, _turn_interval - _timer)


func set_turn_interval(value: float) -> void:
	"""
	Sets the round duration (seconds), clamped to a safe lower bound.
	"""
	_turn_interval = maxf(0.1, value)


func set_time_of_day_hours(hours: float) -> void:
	"""
	Sets the time of day by adjusting the current turn index within the day cycle.
	"""
	var normalized_hours: float = fposmod(hours, 24.0)
	var normalized_day_fraction: float = normalized_hours / 24.0
	var day_base: int = int(floor(float(_current_turn) / float(TURNS_PER_DAY))) * TURNS_PER_DAY
	var day_turn: int = int(floor(normalized_day_fraction * float(TURNS_PER_DAY)))
	day_turn = clampi(day_turn, 0, TURNS_PER_DAY - 1)
	_current_turn = day_base + day_turn


func step_once() -> void:
	"""
	Executes a single turn immediately, without waiting for the timer.
	"""
	if not game_map:
		return

	var was_active: bool = _is_active
	if _is_active:
		stop()

	_execute_turn()

	# Preserve whatever run/paused state was in effect before stepping. This allows stepping through
	# turns even when there are no hostiles.
	if was_active:
		start()


func is_active() -> bool:
	"""
	Returns whether the turn manager is active.
	"""
	return _is_active


func clear() -> void:
	"""
	Clears the turn manager state.
	"""
	_current_turn = 1
	_is_active = false
	_timer = 0.0
	_turn_interval = 0.0


func start() -> void:
	"""
	Starts the turn manager.
	"""
	_is_active = true
	_timer = 0.0


func stop() -> void:
	"""
	Stops the turn manager.
	"""
	_is_active = false
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
		_execute_turn()


func _execute_turn() -> void:
	# Reset the timer.
	_timer = 0.0
	# Emit the turn started signal.
	on_turn_started.emit(_current_turn)

	# 1) Generate AI orders for all AI-controlled combat entities.
	game_map.ai_controller.generate_ai_orders()

	# 3.1) Process use of offensive module activations.
	game_map.ai_controller.execute_offensive_module_orders()
	# 3.2) Process use of utility module activations.
	game_map.ai_controller.execute_utility_module_orders()
	# 3.3) Check if any units are destroyed after executing the orders.
	_erase_destroyed_units()

	# 4) Process movement orders.
	game_map.ai_controller.execute_move_orders()

	# 5.1) Regenerate all units.
	_regenerate_units()
	# 5.2) Update time-based effects.
	_update_time_based_effects()
	# 5.2) Check if any units are destroyed after executing the orders.
	_erase_destroyed_units()

	# Always precompute plans for the next turn so the UI can display intent, even when there are no
	# hostile pairs remaining. This keeps the AI plan cache up to date for the next step.
	if game_map and game_map.ai_controller:
		game_map.ai_controller.precompute_next_turn_plans()

	# Emit the turn ended signal.
	on_turn_ended.emit(_current_turn)
	# Increment the current turn.
	_current_turn += 1

	var combat_continues: bool = game_map.has_hostile_pairs()
	if not combat_continues:
		_is_active = false
		(
			game_map
			. combat_logger
			. add_log(
				Enums.LogType.SYSTEM,
				"Combat ended on turn %d: no hostile units remain." % _current_turn,
			)
		)


static func format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


# =============================================================================
# ORDERS
# =============================================================================


func _filter_dead_unit(_key: String, unit: MapEntity) -> bool:
	"""
	Checks if the unit is dead.
	"""
	return unit.combatant.is_dead()


func _erase_destroyed_units() -> void:
	"""
	Checks for destroyed units and removes them from the game map.
	"""
	# Erase the dead units from the game map.
	game_map.remove_destroyed_units()
	# Remove orders for dead units.
	game_map.ai_controller.remove_orders_of_dead_units()


func _regenerate_units() -> void:
	"""
	Regenerates all units.
	"""
	for unit in game_map.player_units.values():
		unit.combatant.regenerate()
	for unit in game_map.npc_units.values():
		unit.combatant.regenerate()


func _update_time_based_effects() -> void:
	"""
	Updates time-based effects for all units.
	"""
	# Then, tick active effects, cooldowns, and durations.
	for unit in game_map.player_units.values() + game_map.npc_units.values():
		# Process time-based effects like DOT, HOT, buffs.
		var dot_result: Dictionary = unit.combatant.take_dot_damage()
		if dot_result.total > 0:
			game_map.combat_logger.add_log(
				Enums.LogType.ATTACK,
				(
					"%s suffers DOT -> %d shield, %d armor, %d health"
					% [
						unit.combatant.get_chat_tag(),
						dot_result.shield,
						dot_result.armor,
						dot_result.health
					]
				)
			)
		unit.combatant.apply_regen_effects()
		unit.combatant.active_effect_manager.decrement_durations()
		unit.combatant.cooldown_manager.decrement_cooldowns()
