extends RefCounted

class_name GameMap

# =============================================================================
# PROPERTIES
# =============================================================================

const DEFAULT_DETECTION_RANGE := 10

# =====================================
# STATIC INFORMATION
# =====================================

# Map unique identifier.
var map_uuid: String
# Map width.
var map_width: int
# Map height.
var map_height: int
# Map terrain data, an array of integers that identify the type of terrain.
var terrain_data : Array

# =====================================
# DYNAMIC INFORMATION
# =====================================

# Keeps track of turns.
var round_number: int = 0
# If true the map is active, and the update function should advance the round.
var active:bool = false
# If true the map allows PVP.
var is_pvp_enabled:bool = false
# If true the map allows PVP.
var is_free_for_all_enabled:bool = true
# Stores all active NPC units by UUID.
var npc_units: Dictionary[String, MapEntity]
# Stores all active Player units by UUID.
var player_units: Dictionary[String, MapEntity]
# Stores all destroyed units by UUID.
var destroyed_units: Dictionary[String, MapEntity]
# Stores all active orders in the map.
var offensive_module_orders: Dictionary[String, UseModuleOrder]
var utility_module_orders: Dictionary[String, UseModuleOrder]
var move_orders: Dictionary[String, MoveOrder]
# AI controller.
var ai_controller: AIController
# The combat log.
var logs: Array[LogEntry]
# AStar2D graph.
var astar: AStar2D

signal on_log_added(log_entry: LogEntry)

# Emitted whenever we complete a round.
signal on_round_end()

# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================

func _init(p_map_uuid: String, p_map_width: int = 50, p_map_height: int = 50) -> void:
	map_uuid      = p_map_uuid
	map_width     = p_map_width
	map_height    = p_map_height
	ai_controller = AIController.new(self)
	astar         = AStar2D.new()

# =============================================================================
# TERRAIN FUNCTIONS
# =============================================================================

func in_bounds(arg1, arg2 = null) -> bool:
	if typeof(arg1) == TYPE_VECTOR2I:
		if arg1.x >= 0 and arg1.x < map_width and arg1.y >= 0 and arg1.y < map_height:
			return true
	elif typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
		if arg1 >= 0 and arg1 < map_width and arg2 >= 0 and arg2 < map_height:
			return true
	return false

func get_height_at(arg1, arg2 = null) -> int:
	if typeof(arg1) == TYPE_VECTOR2I:
		if in_bounds(arg1, arg2):
			return int(terrain_data[arg1.x][arg1.y])
	elif typeof(arg1) == TYPE_INT and typeof(arg2) == TYPE_INT:
		if in_bounds(arg1, arg2):
			return int(terrain_data[arg1][arg2])
	return -1

func is_occupied(position: Vector2i) -> bool:
	"""Check if the place is occupied."""
	return get_entity_at(position) != null

func is_walkable(position: Vector2i) -> bool:
	"""Check if the height is walkable."""
	var walkable_heights = _get_walkable_heights()
	return walkable_heights.has(get_height_at(position))

func can_move_to(position: Vector2i) -> bool:
	"""Check if the height is walkable."""
	return is_walkable(position) and not is_occupied(position)

func get_visible_tiles(position: Vector2i) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	for dx in range(-DEFAULT_DETECTION_RANGE, DEFAULT_DETECTION_RANGE + 1):
		for dy in range(-DEFAULT_DETECTION_RANGE, DEFAULT_DETECTION_RANGE + 1):
			var tile = position + Vector2i(dx, dy)
			if in_bounds(tile):
				if position.distance_to(tile) <= DEFAULT_DETECTION_RANGE:
					visible.append(tile)
	return visible

# =============================================================================
# ENTITIES FUNCTIONS
# =============================================================================

func is_npc(map_entity: MapEntity) -> bool:
	"""Returns true if the entity belongs to the npc_units dictionary (i.e., NPC)."""
	return npc_units.has(map_entity.entity.uuid)

func is_player(map_entity: MapEntity) -> bool:
	"""Returns true if the entity belongs to the player_units dictionary (i.e., Player)."""
	return player_units.has(map_entity.entity.uuid)

func is_enemy_of(me1: MapEntity, me2: MapEntity) -> bool:
	if is_npc(me1) and is_player(me2):
		return true
	if is_player(me1) and is_npc(me2):
		return true
	if is_npc(me1) and is_npc(me2):
		return is_free_for_all_enabled
	if is_player(me1) and is_player(me2):
		return is_pvp_enabled
	return false

func get_entity_at(position: Vector2i) -> MapEntity:
	"""Returns the entity in the given position."""
	if in_bounds(position):
		for entity in npc_units.values():
			if position == entity.position:
				return entity
		for entity in player_units.values():
			if position == entity.position:
				return entity
		for entity in destroyed_units.values():
			if position == entity.position:
				return entity
	return null

func get_units_in_range(
	source: MapEntity,
	position: Vector2i,
	radius: int,
	include_allies: bool = true,
	include_enemies: bool = true,
	exclude_units: Array[MapEntity] = []
) -> Array[MapEntity]:
	"""
	Returns all units within the specified range of a position.
	Parameters:
	- source: The unit doing the search (to determine ally/enemy).
	- position: The origin position for the search.
	- radius: The radius in tiles.
	- include_allies: Whether to include units on the same side as source.
	- include_enemies: Whether to include enemy units.
	- exclude_units: Optional list of units to ignore.
	"""
	var units_in_range: Array[MapEntity] = []
	for entity in player_units.values() + npc_units.values():
		if entity == source:
			continue
		if entity in exclude_units:
			continue
		if position.distance_to(entity.position) > radius:
			continue
		if include_allies and not is_enemy_of(source, entity):
			units_in_range.append(entity)
		elif include_enemies and is_enemy_of(source, entity):
			units_in_range.append(entity)
	return units_in_range

# =============================================================================
# PATH FINDING
# =============================================================================

func update_astar() -> void:
	# Step 1: Build the graph.
	for x in range(map_width):
		for y in range(map_height):
			var id = y * map_width + x
			var pos = Vector2(x, y)
			if is_walkable(Vector2i(x, y)):
				astar.add_point(id, pos)
	# Step 2: Connect neighbors.
	for x in range(map_width):
		for y in range(map_height):
			var id = y * map_width + x
			if not astar.has_point(id):
				continue
			for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var neighbor = Vector2(x, y) + offset
				var neighbor_id = int(neighbor.y) * map_width + int(neighbor.x)
				if astar.has_point(neighbor_id):
					astar.connect_points(id, neighbor_id)

func _position_to_astar_id(pos: Vector2i) -> int:
	# Example: use y * width + x as unique ID (or your own scheme)
	return pos.y * map_width + pos.x

func get_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	# Convert positions to point IDs
	var start_id = _position_to_astar_id(start)
	var end_id   = _position_to_astar_id(end)
	# If either point is not in the graph, return empty path
	if not astar.has_point(start_id) or not astar.has_point(end_id):
		return []
	var path: Array = astar.get_point_path(start_id, end_id)
	# Convert Vector2s back to Vector2i
	var result: Array[Vector2i] = []
	for p in path:
		result.append(Vector2i(p))
	return result

# =============================================================================
# LOGS
# =============================================================================

var log_indent_level := 0

func increase_indent() -> void:
	log_indent_level += 1

func decrease_indent() -> void:
	log_indent_level = max(log_indent_level - 1, 0)

func get_indent() -> String:
	var indentation: String = ""
	for i in range(log_indent_level):
		indentation += "    "
	return indentation

func add_log(log_type: Enums.LogType, message: String, sender: String = "") -> void:
	if log_type == Enums.LogType.AI:
		return
	var log_entry = LogEntry.new(log_type, get_indent() + message, sender)
	logs.append(log_entry)
	on_log_added.emit(log_entry)

func get_logs_by_type(log_type: Enums.LogType) -> Array[LogEntry]:
	return logs.filter(func(log_entry): return log_entry.log_type == log_type)

func get_formatted_logs() -> Array[String]:
	var formatted_logs: Array[String] = []
	for log_entry in logs:
		formatted_logs.append(str(log_entry))
	return formatted_logs

# =============================================================================
# MAP GENERATION
# =============================================================================

func _get_height_map() -> Array:
	"""Returns predefined height values for terrain generation."""
	return [1, 3, 5, 7, 9]

func _get_walkable_heights() -> Array:
	"""Returns the terrain heights considered walkable."""
	return [3, 5, 7]

func get_color_at(x: int, y: int) -> Color:
	"""Returns the colors associated with the height map."""
	return get_height_color(get_height_at(x, y))

func get_height_color(height: int) -> Color:
	"""Returns the colors associated with the height map."""
	if height == 1: return Color(0.0, 0.0, 0.5)  # Deep Sea (Dark Blue)
	if height == 3: return Color(0.1, 0.1, 0.8)  # Deep Sea (Dark Blue)
	if height == 5: return Color(0.0, 1.0, 0.0)  # Deep Sea (Dark Blue)
	if height == 7: return Color(0.5, 0.3, 0.0)  # Deep Sea (Dark Blue)
	if height == 9: return Color(0.5, 0.5, 0.5)  # Deep Sea (Dark Blue)
	return Color(1.0, 1.0, 1.0)

func generate_terrain():
	"""Generates procedural terrain and stores it."""
	var map_generator = MapGenerator.new(map_width, map_height)
	var height_map = _get_height_map()
	terrain_data = map_generator.generate(height_map)
	# Update the AStar graph.
	update_astar()

# =============================================================================
# ENEMY AI
# =============================================================================

func _generate_enemy_orders(map_entity: MapEntity):
	"""Generates both a utility and offensive action for an enemy unit."""
	
	add_log(Enums.LogType.SYSTEM, "-- SCHEDULE UTILITY ----------------------------------------")
	
	# 1) Select a utility module (if available)
	var utility_module_order = ai_controller.schedule_utility_module_order(map_entity)
	if utility_module_order:
		utility_module_orders[map_entity.entity.uuid] = utility_module_order
	
	add_log(Enums.LogType.SYSTEM, "-- SCHEDULE OFFENSIVE --------------------------------------")
	
	# 2) Select an offensive module (if available)
	var offensive_module_order = ai_controller.schedule_offensive_module_order(map_entity)
	if offensive_module_order:
		offensive_module_orders[map_entity.entity.uuid] = offensive_module_order
	
	add_log(Enums.LogType.SYSTEM, "-- SCHEDULE MOVEMENT ---------------------------------------")
	
	# 3) Select movement
	if not offensive_module_order:
		var move_order = ai_controller.schedule_move_order(map_entity)
		if move_order:
			move_orders[map_entity.entity.uuid] = move_order

# =============================================================================
# ACTION EXECUTION
# =============================================================================

func _apply_damage_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.entity
	var target_mek: Mek = order.target.entity
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF damage.
	if effect.target_self():
		var result = source_mek.take_damage_from_effect(effect)
		add_log(
			Enums.LogType.ATTACK,
			"%s hurts itself with %s → %d shield, %d armor, %d health (reduced %d %s)" % [
				source_mek.template.name,
				order.module.name,
				result.shield,
				result.armor,
				result.health,
				result.reduced,
				Enums.DamageType.keys()[effect.damage_type]
			]
		)
	# Handle AREA damage.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var affected = get_units_in_range(order.source, center.position, effect.radius, true, true)
		for entity in affected:
			var mek = entity.entity
			if mek.is_dead():
				continue
			var result = mek.take_damage_from_effect(effect)
			add_log(
				Enums.LogType.ATTACK,
				"%s hits %s with AoE from %s → %d shield, %d armor, %d health (reduced %d %s)" % [
					source_mek.template.name,
					target_mek.template.name,
					order.module.name,
					result.shield,
					result.armor,
					result.health,
					result.reduced,
					Enums.DamageType.keys()[effect.damage_type]
				]
			)
	# Handle regular ENEMY / ALLY targeting.
	else:
		var result = target_mek.take_damage_from_effect(effect)
		add_log(
			Enums.LogType.ATTACK,
			"%s hits %s with %s → %d shield, %d armor, %d health (reduced %d %s)" % [
				source_mek.template.name,
				target_mek.template.name,
				order.module.name,
				result.shield,
				result.armor,
				result.health,
				result.reduced,
				Enums.DamageType.keys()[effect.damage_type]
			]
		)

func _apply_repair_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.entity
	var target_mek: Mek = order.target.entity
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF repair.
	if effect.target_self():
		var result = source_mek.repair_from_effect(effect)
		add_log(
			Enums.LogType.SUPPORT,
			"%s restores %d %s to itself using %s" % [
				source_mek.template.name,
				result.amount,
				result.stat,
				order.module.name
			]
		)
	# Handle AREA repair.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = get_units_in_range(order.source, center.position, effect.radius, include_allies, include_enemies, [])
		for entity in affected:
			var mek = entity.entity
			if mek.is_dead():
				continue
			var result = mek.repair_from_effect(effect)
			add_log(
				Enums.LogType.SUPPORT,
				"%s restores %d %s to %s using %s (AoE)" % [
					source_mek.template.name,
					result.amount,
					result.stat,
					mek.template.name,
					order.module.name
				]
			)
	# Handle ENEMY / ALLY repair.
	else:
		if target_mek.is_dead():
			return
		var result = target_mek.repair_from_effect(effect)
		add_log(
			Enums.LogType.SUPPORT,
			"%s restores %d %s to %s using %s" % [
				source_mek.template.name,
				result.amount,
				result.stat,
				target_mek.template.name,
				order.module.name
			]
		)

func _apply_modifier_effect(order: UseModuleOrder, effect: ItemEffect) -> void:
	var source_mek: Mek = order.source.entity
	var target_mek: Mek = order.target.entity
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Handle SELF-targeted effects.
	if effect.target_self():
		source_mek.add_effect(order.module, effect, order.source)
		add_log(
			Enums.LogType.SUPPORT,
			"%s applies %s to itself → %d for %d turns (%s)" % [
				source_mek.template.name,
				effect.get_effect_type_label(),
				effect.amount,
				effect.duration,
				order.module.name
			]
		)
	# Handle AREA-based effects.
	elif effect.target_area():
		var center = order.target if effect.center_on_target else order.source
		var include_allies = effect.target_ally() or effect.target_self()
		var include_enemies = effect.target_enemy()
		var affected = get_units_in_range(order.source, center.position, effect.radius, include_allies, include_enemies, [order.source])
		for entity in affected:
			var mek = entity.entity
			if mek.is_dead():
				continue
			mek.add_effect(order.module, effect, order.source)
			add_log(
				Enums.LogType.SUPPORT,
				"%s applies %s to %s → %d for %d turns (%s, AoE)" % [
					source_mek.template.name,
					effect.get_effect_type_label(),
					mek.template.name,
					effect.amount,
					effect.duration,
					order.module.name
				]
			)

	# Handle direct ENEMY / ALLY targeting.
	else:
		target_mek.add_effect(order.module, effect, order.source)
		add_log(
			Enums.LogType.SUPPORT,
			"%s applies %s to %s → %d for %d turns (%s)" % [
				source_mek.template.name,
				effect.get_effect_type_label(),
				target_mek.template.name,
				effect.amount,
				effect.duration,
				order.module.name
			]
		)

func _execute_utility_module_order(order: UseModuleOrder) -> void:
	var source_mek: Mek = order.source.entity
	var target_mek: Mek = order.target.entity
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Deduct power.
	source_mek.power -= order.module.power_on_use
	# Start cooldown if necessary.
	if order.module.cooldown > 0:
		source_mek.cooldown_manager.start_cooldown(order.item, order.module)
	add_log(
		Enums.LogType.SYSTEM,
		"%s used %s (power left: %d%s)" % [
			source_mek.template.name,
			order.module.name,
			source_mek.power,
			", cooldown: " + str(order.module.cooldown) if order.module.cooldown else ""
		]
	)
	increase_indent()
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
			add_log(Enums.LogType.SYSTEM, "Effect %s not yet implemented" % Enums.EffectType.keys()[effect.type])
		if source_mek.is_dead() or target_mek.is_dead():
			break
	decrease_indent()

func _execute_offensive_module_order(order: UseModuleOrder) -> void:
	var source_mek: Mek = order.source.entity
	var target_mek: Mek = order.target.entity
	if source_mek.is_dead() or target_mek.is_dead():
		return
	# Deduct power
	source_mek.power -= order.module.power_on_use
	# Start cooldown if necessary
	if order.module.cooldown > 0:
		source_mek.cooldown_manager.start_cooldown(order.item, order.module)
	# Perform accuracy check
	var base_accuracy = 90 + source_mek.accuracy_modifier
	# Adjust based on movement.
	var move_penalty = -min(source_mek.tiles_moved_last_turn * 5, 30) # -5% per tile, up to -30%
	# Adjust based on dodge.
	var dodge_bonus  = -min(target_mek.tiles_moved_last_turn * 3, 15) # -3% dodge per tile, up to -15%
	# Height-based adjustment
	var source_height = get_height_at(order.source.position)
	var target_height = get_height_at(order.target.position)
	var height_diff = source_height - target_height
	# Rule of thumb: +/-2% accuracy per height difference (capped at ±10%)
	var height_bonus = clamp(height_diff * 2, -10, 10)
	var final_accuracy = min(base_accuracy + move_penalty + dodge_bonus + height_bonus, 90)
	var roll = randi() % 100
	var hit_success = roll < final_accuracy
	add_log(
		Enums.LogType.SYSTEM,
		"%s attacking %s with %s: base=%d, move=%d, dodge=%d, height=%d → accuracy=%d%% (roll=%d): %s %s" % [
			source_mek.template.name,
			target_mek.template.name,
			order.module.name,
			base_accuracy,
			move_penalty,
			dodge_bonus,
			height_bonus,
			final_accuracy,
			roll,
			"HIT" if hit_success else "MISS",
			"(cooldown: " + str(order.module.cooldown) +")" if order.module.cooldown else ""
		]
	)
	increase_indent()
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
			add_log(Enums.LogType.SYSTEM, "Effect %s not yet implemented" % Enums.EffectType.keys()[effect.type])
		if source_mek.is_dead() or target_mek.is_dead():
			break
	decrease_indent()


func _execute_move_order(order: MoveOrder):
	var mek = order.source.entity
	var start = order.source.position
	var end   = order.destination
	if mek.is_dead():
		return
	# Track movement distance for accuracy/dodge purposes.
	mek.tiles_moved_last_turn = start.distance_to(end)
	add_log(Enums.LogType.MOVEMENT, "%s moved from %s to %s (%d tiles)" % [
		mek.template.name, start, end, mek.tiles_moved_last_turn
	])
	order.source.position = order.destination

# =============================================================================
# ORDERS
# =============================================================================

func _destroy_mek(entity: MapEntity) -> void:
	var mek = entity.entity
	if player_units.has(mek.uuid):
		player_units.erase(mek.uuid)
	elif npc_units.has(mek.uuid):
		npc_units.erase(mek.uuid)
	add_log(
		Enums.LogType.SYSTEM,
		"%s has been destroyed!" % mek.template.name
	)

func _check_destroyed_units() -> void:
	var to_remove_player: Array[String] = []
	var to_remove_enemy: Array[String] = []
	# Collect dead player units
	for uuid in player_units:
		var entity: MapEntity = player_units[uuid]
		if entity.entity.is_dead():
			to_remove_player.append(uuid)
	# Collect dead enemy units
	for uuid in npc_units:
		var entity: MapEntity = npc_units[uuid]
		if entity.entity.is_dead():
			to_remove_enemy.append(uuid)
	# Now safely remove and destroy
	for uuid in to_remove_player:
		_destroy_mek(player_units[uuid])
	for uuid in to_remove_enemy:
		_destroy_mek(npc_units[uuid])

func queue_offensive_module_orders(order: UseModuleOrder):
	"""Queues an offensive module activation order, replacing any existing one for the unit."""
	offensive_module_orders[order.source.uuid] = order

func queue_utility_module_orders(order: UseModuleOrder):
	"""Queues a module activation order, replacing any existing one for the unit."""
	utility_module_orders[order.source.uuid] = order

func queue_move_order(order: MoveOrder):
	"""Queues a movement order, replacing any existing one for the unit."""
	move_orders[order.source.uuid] = order

func process_round():
	add_log(Enums.LogType.SYSTEM, "============================================================")
	add_log(Enums.LogType.SYSTEM, "============================================================")
	add_log(Enums.LogType.SYSTEM, "Executing round " + str(round_number) + "...")
	
	
	add_log(Enums.LogType.SYSTEM, "== RUN AI ==================================================")
	
	# 1) Generate AI actions.
	for unit_uuid in npc_units:
		_generate_enemy_orders(npc_units[unit_uuid])
	
	add_log(Enums.LogType.SYSTEM, "== EXECUTE UTILITY =========================================")
	
	# 2) Process utility module activations.
	for unit_uuid in utility_module_orders:
		_execute_utility_module_order(utility_module_orders[unit_uuid])
	utility_module_orders.clear()
	
	add_log(Enums.LogType.SYSTEM, "== EXECUTE OFFENSIVE =======================================")
	
	# 3) Process offensive module activations.
	for unit_uuid in offensive_module_orders:
		_execute_offensive_module_order(offensive_module_orders[unit_uuid])
	offensive_module_orders.clear()
	
	_check_destroyed_units()
	
	add_log(Enums.LogType.SYSTEM, "== EXECUTE MOVEMENT ========================================")
	
	# 4.1) Reset movement tracking for all Meks.
	for unit_uuid in player_units:
		player_units[unit_uuid].entity.tiles_moved_last_turn = 0

	for unit_uuid in npc_units:
		npc_units[unit_uuid].entity.tiles_moved_last_turn = 0

	# 4.2) Process movement orders.
	for unit_uuid in move_orders:
		_execute_move_order(move_orders[unit_uuid])
	move_orders.clear()
	
	add_log(Enums.LogType.SYSTEM, "== REGENERATE ==============================================")
	
	# 5) Regenerate all units
	for unit in player_units.values():
		unit.entity.regenerate()

	for unit in npc_units.values():
		unit.entity.regenerate()
	
	add_log(Enums.LogType.SYSTEM, "== PROCESS TICKS ===========================================")
	
	# 5) Tick active effects, cooldowns, and durations
	for unit_dict in [player_units, npc_units]:
		for unit_uuid in unit_dict:
			var map_entity = unit_dict[unit_uuid]
			var mek: Mek = map_entity.entity

			# Process time-based effects like DOT, HOT, buffs
			var dot_result = mek.take_dot_damage()
			if dot_result.total > 0:
				add_log(
					Enums.LogType.ATTACK,
					"%s suffers DOT → %d shield, %d armor, %d health" % [
						mek.template.name,
						dot_result.shield,
						dot_result.armor,
						dot_result.health
					]
				)
			
			# Decrement durations for active modules
			mek.active_effect_manager.decrement_durations()
			# Decrement cooldowns
			mek.cooldown_manager.decrement_cooldowns()
	
	_check_destroyed_units()
	
	# 6) Round end
	on_round_end.emit()
	round_number += 1
	add_log(Enums.LogType.SYSTEM, "")

# =============================================================================
# ENEMY SPAWNING
# =============================================================================

func _find_valid_spawn_positions() -> Array:
	"""Finds valid positions for spawning entities based on the height map."""
	var valid_positions = []
	for x in range(map_width):
		for y in range(map_height):
			var position = Vector2i(x, y)
			# Check if the height is walkable.
			if can_move_to(position):
				valid_positions.append(position)
	return valid_positions

func _get_enemy_count(difficulty: int) -> int:
	"""Determines the number of enemies to spawn based on difficulty and map size."""
	var base_count = 1 + int(((difficulty + 1) * (difficulty + 1)) / 3.0)
	var map_factor = (map_width * map_height) / ((map_width + map_height) * 3.0)
	return base_count + int(map_factor)

func spawn_enemies_on_map(difficulty: int) -> void:
	"""Places multiple enemies on the map based on difficulty level."""
	# Determine the number of enemies based on difficulty.
	var enemy_count = _get_enemy_count(difficulty)
	# Keep track of valid spawn locations on the map.
	var spawn_points = _find_valid_spawn_positions()
	# Spawn and place each enemy.
	for i in range(enemy_count):
		if spawn_points.is_empty():
			push_error("We ran out of spawn points.")
			return
		# Generate the enemy.
		var enemy_mek = LoadoutGenerator.generate_random_enemy(difficulty)
		if not enemy_mek:
			push_error("Failed to generate an enemy Mek.")
			continue
		# Choose a random valid position.
		var spawn_point = spawn_points.pick_random()
		spawn_points.erase(spawn_point)
		# Place the enemy on the map.
		npc_units[enemy_mek.uuid] = MapEntity.new(spawn_point, enemy_mek)

# =============================================================================
# SAVE & LOAD
# =============================================================================

static func _serialize_npc_units(units: Dictionary[String, MapEntity]) -> Dictionary:
	"""Converts enemy units dictionary to a JSON-compatible format."""
	var serialized = {}
	for unit_uuid in units:
		var map_entity = units[unit_uuid]
		var mek: Mek   = map_entity.entity
		serialized[unit_uuid] = {
			"position": ("%d,%d" % [map_entity.position.x, map_entity.position.y]),
			"entity": mek.to_client_dict(),
			"active": map_entity.active
		}
	return serialized
	
static func _deserialize_npc_units(data: Dictionary) -> Dictionary[String, MapEntity]:
	"""Reconstructs enemy units dictionary from a JSON-compatible format."""
	var units: Dictionary[String, MapEntity] = {}
	for unit_uuid in data:
		var enemy_unit = data[unit_uuid]
		var coordinates = enemy_unit["position"].split(",")
		var position = Vector2i(int(coordinates[0]), int(coordinates[1]))
		var entity = Mek.new(enemy_unit["entity"])
		units[unit_uuid] = MapEntity.new(position, entity)
	return units

static func from_dict(data: Dictionary) -> GameMap:
	"""Loads map data from a dictionary."""
	if not data.has_all(["map_uuid", "map_width", "map_height", "terrain_data"]):
		push_error("Invalid map data format!")
		return null
	var map = GameMap.new(
		data["map_uuid"],
		data["map_width"],
		data["map_height"]
	)
	map.terrain_data = data["terrain_data"]
	map.npc_units    = _deserialize_npc_units(data["npc_units"])
	
	# Update the AStar graph.
	map.update_astar()
	
	return map
	

func to_dict() -> Dictionary:
	"""Converts the map data into a dictionary for saving."""
	return {
		"map_uuid": map_uuid,
		"map_width": map_width,
		"map_height": map_height,
		"terrain_data": terrain_data.duplicate(),
		"npc_units": _serialize_npc_units(npc_units),
	}
