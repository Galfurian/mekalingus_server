# This class handles the turn management for a specific game map.
# It is responsible for executing turns, processing orders, and
# managing the game state.
class_name TurnManager
extends Node

# ====================================================================
# CONSTANTS
# ====================================================================

# The maximum number of turns in a day.
const TURNS_PER_DAY: int = 48
const TURRET_COOLDOWN_TURNS: int = 2

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
		# Reset the timer.
		_timer = 0.0
		# Emit the turn started signal.
		on_turn_started.emit(_current_turn)

		# 1) Generate the NPCs order for the current turn.
		game_map.ai_controller.generate_npc_orders()
		
		# 3.1) Process use of offensive module activations.
		game_map.ai_controller.execute_offensive_module_orders()
		# 3.2) Process use of utility module activations.
		game_map.ai_controller.execute_utility_module_orders()
		# 3.3) Process autonomous turret actions.
		_process_turret_actions()
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
		if not _has_hostile_pairs():
			_is_active = false
			game_map.combat_logger.add_log(
				Enums.LogType.SYSTEM,
				"Combat ended on turn %d: no hostile units remain." % _current_turn,
			)

		# Emit the turn ended signal.
		on_turn_ended.emit(_current_turn)
		# Increment the current turn.
		_current_turn += 1


static func format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


# =============================================================================
# ORDERS
# =============================================================================


func _filter_dead_unit(_key: String, unit: MapEntity) -> bool:
	"""
	Checks if the unit is dead.
	"""
	return unit.mek.is_dead()


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
		unit.mek.apply_regen_effects()
		unit.mek.active_effect_manager.decrement_durations()
		unit.mek.cooldown_manager.decrement_cooldowns()


func _process_turret_actions() -> void:
	"""
	Ticks turret cooldowns and executes one attack when a target is in range.
	"""
	for turret: MapTurret in game_map.turrets.values():
		if not turret or not turret.active:
			continue

		turret.tick_cooldown()
		if not turret.can_fire():
			continue

		var target: MapMek = _find_turret_target(turret)
		if not target or not target.mek or target.mek.is_dead():
			continue

		var damage_effect := ItemEffect.new({
			"type": Enums.EffectType.DAMAGE,
			"target": Enums.TargetType.ENEMY,
			"damage_type": Enums.DamageType.KINETIC,
			"amount": turret.damage,
			"duration": 0,
			"chance": 100,
			"radius": 0,
			"center_on_target": true,
		})

		var result = target.mek.take_damage_from_effect(damage_effect)
		turret.start_cooldown(TURRET_COOLDOWN_TURNS)

		game_map.combat_logger.add_log(
			Enums.LogType.ATTACK,
			"%s fires at %s -> %d shield, %d armor, %d health" % [
				_turret_tag(turret),
				target.mek.get_chat_tag(),
				result.shield,
				result.armor,
				result.health,
			]
		)


func _find_turret_target(turret: MapTurret) -> MapMek:
	"""
	Selects the closest hostile living mek within turret firing range.
	"""
	var closest_target: MapMek = null
	var closest_distance: float = INF

	for candidate: MapMek in game_map.player_units.values() + game_map.npc_units.values():
		if not candidate or not candidate.mek or candidate.mek.is_dead():
			continue
		if not game_map.can_owners_attack(turret.owner, candidate.owner):
			continue

		var distance := turret.position.distance_to(candidate.position)
		if distance > turret.fire_range:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_target = candidate

	return closest_target


func _turret_tag(turret: MapTurret) -> String:
	return "[url=pos:%d,%d]%s[/url]" % [
		turret.position.x,
		turret.position.y,
		turret.turret_name,
	]


func _has_hostile_pairs() -> bool:
	"""
	Returns true if at least one pair of living units can still attack each other.
	"""
	var alive_units: Array[MapMek] = []
	for unit: MapMek in game_map.player_units.values():
		if unit and unit.mek and unit.mek.is_alive():
			alive_units.append(unit)
	for unit: MapMek in game_map.npc_units.values():
		if unit and unit.mek and unit.mek.is_alive():
			alive_units.append(unit)
	for i in range(alive_units.size()):
		for j in range(i + 1, alive_units.size()):
			if game_map.is_enemy_of(alive_units[i], alive_units[j]):
				return true
	return false
