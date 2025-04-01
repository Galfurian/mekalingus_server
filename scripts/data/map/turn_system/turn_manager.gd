# This class handles the turn management for a specific game map.
# It is responsible for executing turns, processing orders, and
# managing the game state.
class_name TurnManager
extends Node

# ====================================================================
# SIGNALS
# ====================================================================

# Emitted when the turn is started.
signal turn_started(turn_number: int)
# Emitted when the turn is ended.
signal turn_ended(turn_number: int)

# ===================================================================
# PROPERTIES
# ===================================================================

# The game map associated with this turn manager.
var game_map: GameMap
# The orders for offensive modules.
var offensive_module_orders: Dictionary[String, UseModuleOrder]
# The orders for utility modules.
var utility_module_orders: Dictionary[String, UseModuleOrder]
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
		turn_started.emit(_current_turn)

		# 1) Generate the NPCs order for the current turn.
		for unit_uuid in game_map.npc_units:
			_generate_enemy_orders(game_map.npc_units[unit_uuid])
		# 2) Process utility module activations.
		_execute_utility_module_orders()
		# 3) Process offensive module activations.
		_execute_offensive_module_orders()
		# 4) Process movement orders.
		_execute_move_orders()
		# 5) Regenerate all units
		_update_time_based_effects()

		# Emit the turn ended signal.
		turn_ended.emit(_current_turn)
		# Increment the current turn.
		_current_turn += 1


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


func queue_offensive_module_orders(order: UseModuleOrder):
	"""
	Queues an offensive module activation order, replacing any existing one for the unit.
	"""
	if order:
		offensive_module_orders[order.source.mek.uuid] = order


func queue_utility_module_order(order: UseModuleOrder):
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
	for unit_uuid in offensive_module_orders:
		_execute_offensive_module_order(offensive_module_orders[unit_uuid])
	offensive_module_orders.clear()
	# Check if any units are destroyed after executing the orders.
	_erase_destroyed_units()


func _execute_utility_module_orders() -> void:
	"""
	Executes all queued utility module orders.
	"""
	for unit_uuid in utility_module_orders:
		_execute_utility_module_order(utility_module_orders[unit_uuid])
	utility_module_orders.clear()


func _execute_move_orders() -> void:
	"""
	Executes all queued movement orders.
	"""
	# Reset movement tracking for all Meks.
	for unit_uuid in game_map.player_units:
		game_map.player_units[unit_uuid].mek.tiles_moved_last_turn = 0
	for unit_uuid in game_map.npc_units:
		game_map.npc_units[unit_uuid].mek.tiles_moved_last_turn = 0
	# Then, execute the orders.
	for unit_uuid in move_orders:
		_execute_move_order(move_orders[unit_uuid])
	move_orders.clear()


func _update_time_based_effects():
	"""
	Updates time-based effects for all units.
	"""
	# First regenerate the units.
	for unit in game_map.player_units.values():
		unit.mek.regenerate()
	for unit in game_map.npc_units.values():
		unit.mek.regenerate()
	# Then, tick active effects, cooldowns, and durations.
	for unit_dict in [game_map.player_units, game_map.npc_units]:
		for unit_uuid in unit_dict:
			var map_entity = unit_dict[unit_uuid]
			var mek: Mek = map_entity.mek
			# Process time-based effects like DOT, HOT, buffs
			var dot_result = mek.take_dot_damage()
			if dot_result.total > 0:
				game_map.add_log(
					Enums.LogType.ATTACK,
					(
						"%s suffers DOT -> %d shield, %d armor, %d health"
						% [
							mek.template.mek_name,
							dot_result.shield,
							dot_result.armor,
							dot_result.health
						]
					)
				)
	# Check if any of the meks did die.
	_erase_destroyed_units()


# =============================================================================
# ENEMY AI
# =============================================================================


func _generate_enemy_orders(map_entity: MapEntity):
	"""Generates both a utility and offensive action for an enemy unit."""
	# 1. Generate the use of utility modules.
	queue_utility_module_order(ai_controller.schedule_utility_module_order(map_entity))
	# 2. Generate the use of offensive modules.
	queue_offensive_module_orders(ai_controller.schedule_offensive_module_order(map_entity))
	# 3. Generate the movement order.
	queue_move_order(ai_controller.schedule_move_order(map_entity))


# =============================================================================
# ACTION EXECUTION
# =============================================================================


func _apply_damage_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.mek
	var target_mek: Mek = order.target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF damage.
	if effect.target_self():
		var result = source_mek.take_damage_from_effect(effect)
		game_map.add_log(
			Enums.LogType.ATTACK,
			(
				"%s hurts itself with %s -> %d shield, %d armor, %d health (reduced %d %s)"
				% [
					source_mek.template.mek_name,
					order.module.module_name,
					result.shield,
					result.armor,
					result.health,
					result.reduced,
					Enums.DamageType.keys()[effect.damage_type]
				]
			)
		)
	# Handle AREA damage.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var affected = game_map.get_units_in_range(
			order.source, center.position, effect.radius, true, true
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			var result = mek.take_damage_from_effect(effect)
			game_map.add_log(
				Enums.LogType.ATTACK,
				(
					"%s hits %s with AoE from %s -> %d shield, %d armor, %d health (reduced %d %s)"
					% [
						source_mek.template.mek_name,
						target_mek.template.mek_name,
						order.module.module_name,
						result.shield,
						result.armor,
						result.health,
						result.reduced,
						Enums.DamageType.keys()[effect.damage_type]
					]
				)
			)
	# Handle regular ENEMY / ALLY targeting.
	else:
		var result = target_mek.take_damage_from_effect(effect)
		game_map.add_log(
			Enums.LogType.ATTACK,
			(
				"%s hits %s with %s -> %d shield, %d armor, %d health (reduced %d %s)"
				% [
					source_mek.template.mek_name,
					target_mek.template.mek_name,
					order.module.module_name,
					result.shield,
					result.armor,
					result.health,
					result.reduced,
					Enums.DamageType.keys()[effect.damage_type]
				]
			)
		)


func _apply_repair_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.mek
	var target_mek: Mek = order.target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF repair.
	if effect.target_self():
		var result = source_mek.repair_from_effect(effect)
		game_map.add_log(
			Enums.LogType.SUPPORT,
			(
				"%s restores %d %s to itself using %s"
				% [
					source_mek.template.mek_name,
					result.amount,
					result.stat,
					order.module.module_name
				]
			)
		)
	# Handle AREA repair.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = game_map.get_units_in_range(
			order.source, center.position, effect.radius, include_allies, include_enemies, []
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			var result = mek.repair_from_effect(effect)
			game_map.add_log(
				Enums.LogType.SUPPORT,
				(
					"%s restores %d %s to %s using %s (AoE)"
					% [
						source_mek.template.mek_name,
						result.amount,
						result.stat,
						mek.template.mek_name,
						order.module.module_name
					]
				)
			)
	# Handle ENEMY / ALLY repair.
	else:
		if target_mek.is_dead():
			return
		var result = target_mek.repair_from_effect(effect)
		game_map.add_log(
			Enums.LogType.SUPPORT,
			(
				"%s restores %d %s to %s using %s"
				% [
					source_mek.template.mek_name,
					result.amount,
					result.stat,
					target_mek.template.mek_name,
					order.module.module_name
				]
			)
		)


func _apply_modifier_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.mek
	var target_mek: Mek = order.target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF-targeted effects.
	if effect.target_self():
		source_mek.add_effect(order.module, effect, order.source)
		game_map.add_log(
			Enums.LogType.SUPPORT,
			(
				"%s applies %s to itself -> %d for %d turns (%s)"
				% [
					source_mek.template.mek_name,
					effect.get_effect_type_label(),
					effect.amount,
					effect.duration,
					order.module.module_name
				]
			)
		)
	# Handle AREA-based effects.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = game_map.get_units_in_range(
			order.source,
			center.position,
			effect.radius,
			include_allies,
			include_enemies,
			[order.source]
		)
		for entity in affected:
			var mek = entity.mek
			if mek.is_dead():
				continue
			mek.add_effect(order.module, effect, order.source)
			game_map.add_log(
				Enums.LogType.SUPPORT,
				(
					"%s applies %s to %s -> %d for %d turns (%s, AoE)"
					% [
						source_mek.template.mek_name,
						effect.get_effect_type_label(),
						mek.template.mek_name,
						effect.amount,
						effect.duration,
						order.module.module_name
					]
				)
			)

	# Handle direct ENEMY / ALLY targeting.
	else:
		target_mek.add_effect(order.module, effect, order.source)
		game_map.add_log(
			Enums.LogType.SUPPORT,
			(
				"%s applies %s to %s -> %d for %d turns (%s)"
				% [
					source_mek.template.mek_name,
					effect.get_effect_type_label(),
					target_mek.template.mek_name,
					effect.amount,
					effect.duration,
					order.module.module_name
				]
			)
		)


func _execute_utility_module_order(order: UseModuleOrder) -> void:
	var source_mek: Mek = order.source.mek
	var target_mek: Mek = order.target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Check if the Mek has enough power.
	if source_mek.power < order.module.power_on_use:
		return
	# Deduct power.
	source_mek.power -= order.module.power_on_use
	# Start cooldown if necessary.
	if order.module.cooldown > 0:
		source_mek.cooldown_manager.start_cooldown(order.item, order.module)
	game_map.add_log(
		Enums.LogType.SYSTEM,
		(
			"[url=mek:%s]%s[/url] used [url=item:%s:%s]%s[/url] (power left: %d%s)"
			% [
				source_mek.uuid,
				source_mek.template.mek_name,
				source_mek.uuid,
				order.item.uuid,
				order.module.module_name,
				source_mek.power,
				", cooldown: " + str(order.module.cooldown) if order.module.cooldown else ""
			]
		)
	)
	game_map.increase_indent()
	for effect in order.module.effects:
		if effect.is_damage():
			_apply_damage_effect(order, effect)
		elif effect.is_repair():
			_apply_repair_effect(order, effect)
		elif effect.is_dot():
			_apply_modifier_effect(order, effect)
		elif effect.is_regen():
			_apply_modifier_effect(order, effect)
		elif effect.is_damage_reduction():
			_apply_modifier_effect(order, effect)
		elif effect.is_modifier():
			_apply_modifier_effect(order, effect)
		else:
			game_map.add_log(
				Enums.LogType.SYSTEM,
				"Effect %s not yet implemented" % Enums.EffectType.keys()[effect.type]
			)
		if source_mek.is_dead() or target_mek.is_dead():
			break
	game_map.decrease_indent()


func _execute_offensive_module_order(order: UseModuleOrder) -> void:
	var source_mek: Mek = order.source.mek
	var target_mek: Mek = order.target.mek
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Check if the Mek has enough power.
	if source_mek.power < order.module.power_on_use:
		return
	# Deduct power.
	source_mek.power -= order.module.power_on_use
	# Start cooldown if necessary
	if order.module.cooldown > 0:
		source_mek.cooldown_manager.start_cooldown(order.item, order.module)
	# Perform accuracy check
	var base_accuracy = 90 + source_mek.accuracy_modifier
	# Adjust based on movement.
	var move_penalty = -min(source_mek.tiles_moved_last_turn * 5, 30)  # -5% per tile, up to -30%
	# Adjust based on dodge.
	var dodge_bonus = -min(target_mek.tiles_moved_last_turn * 3, 15)  # -3% dodge per tile, up to -15%
	# Height-based adjustment
	var source_height = game_map.get_tile_height(order.source.position)
	var target_height = game_map.get_tile_height(order.target.position)
	var height_diff = source_height - target_height
	# Rule of thumb: +/-2% accuracy per height difference (capped at +-10%)
	var height_bonus = clamp(height_diff * 2, -10, 10)
	var final_accuracy = min(base_accuracy + move_penalty + dodge_bonus + height_bonus, 90)
	var roll = randi() % 100
	var hit_success = roll < final_accuracy
	# Generate the log.
	var log_text := (
		"[url=mek:%s]%s[/url] attacking [url=mek:%s]%s[/url] with %s:"
		% [
			source_mek.uuid,
			source_mek.template.mek_name,
			target_mek.uuid,
			target_mek.template.mek_name,
			order.module.module_name
		]
	)
	log_text += (
		" base=%d, move=%d, dodge=%d, height=%d"
		% [base_accuracy, move_penalty, dodge_bonus, height_bonus]
	)
	log_text += (
		" -> accuracy=%d%% (roll=%d): %s" % [final_accuracy, roll, "HIT" if hit_success else "MISS"]
	)
	if order.module.cooldown:
		log_text += " (cooldown: %d)" % order.module.cooldown
	game_map.add_log(Enums.LogType.SYSTEM, log_text)

	if not hit_success:
		return

	game_map.increase_indent()
	for effect in order.module.effects:
		if effect.is_damage():
			_apply_damage_effect(order, effect)
		elif effect.is_repair():
			_apply_repair_effect(order, effect)
		elif effect.is_dot():
			_apply_modifier_effect(order, effect)
		elif effect.is_regen():
			_apply_modifier_effect(order, effect)
		elif effect.is_damage_reduction():
			_apply_modifier_effect(order, effect)
		elif effect.is_modifier():
			_apply_modifier_effect(order, effect)
		else:
			game_map.add_log(
				Enums.LogType.SYSTEM,
				"Effect %s not yet implemented" % Enums.EffectType.keys()[effect.type]
			)
		if source_mek.is_dead() or target_mek.is_dead():
			break
	game_map.decrease_indent()


func _execute_move_order(order: MoveOrder):
	var mek = order.source.mek
	if mek.is_dead():
		return
	var start_pos = order.source.position
	var end_pos = order.destination
	# Track movement distance for accuracy/dodge purposes.
	mek.tiles_moved_last_turn = start_pos.distance_to(end_pos)
	(
		game_map
		. add_log(
			Enums.LogType.MOVEMENT,
			(
				"[url=mek:%s]%s[/url] moved from [url=pos:%d,%d]%s[/url] to [url=pos:%d,%d]%s[/url] (%d tiles)"
				% [
					mek.uuid,
					mek.template.mek_name,
					start_pos.x,
					start_pos.y,
					str(start_pos),
					end_pos.x,
					end_pos.y,
					str(end_pos),
					mek.tiles_moved_last_turn
				]
			)
		)
	)
	order.source.position = order.destination
