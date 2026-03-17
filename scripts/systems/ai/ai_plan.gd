class_name AIPlan
extends RefCounted

enum Intent { NONE, ATTACK, SUPPORT, RETREAT, REPOSITION }

# Plan lifecycle state.
enum Status { NONE, PLANNED, ORDER_QUEUED, EXECUTING, COMPLETED }

# ========== PLAN STATE ===========

# Defines the high-level goal of the plan.
var intent: Intent = Intent.NONE
# A status enum describing where the plan currently stands.
var status: Status = Status.NONE
# Deprecated boolean for backwards compatibility.
var completed: bool = false


# ========== PLAN DATA ==========

# The game map associated with this plan.
var game_map
# The unit executing the plan.
var source = null
# The target of the action (if any).
var target = null
# The tile the AI wants to move to, if movement is part of the plan.
var destination: Vector2i
# The offensive or utility module involved in the action.
var equipped_module: EquippedModule = null
# The priority ranking assigned during planning.
var score: float = 0.0
func set_status(val: Status) -> void:
	status = val
	completed = status == Status.COMPLETED

func get_status() -> Status:
	return status
# ========== CORE METHODS ==========


func _init(p_source, p_game_map) -> void:
	intent = Intent.NONE
	set_status(Status.PLANNED)

	game_map = p_game_map

	source = p_source
	target = null
	destination = Vector2i.ZERO
	equipped_module = null
	score = 0.0


func _format_pos_tag(pos: Vector2i) -> String:
	return MetaTag.pos_tag(pos)


func is_valid() -> bool:
	if source == null or source.combatant.is_dead():
		return false

	var valid: bool = true
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		valid = target != null and not target.combatant.is_dead()
		if valid:
			valid = equipped_module != null
		if valid:
			valid = AIUtils.is_equipped_module_available(source.combatant, equipped_module)
		if valid:
			valid = AIUtils.can_module_be_used_now(
				source.combatant, equipped_module.item, equipped_module.module
			)
	elif intent == Intent.RETREAT or intent == Intent.REPOSITION:
		valid = destination != Vector2i.ZERO

	if not valid:
		return false

	return not is_complete()


func is_complete() -> bool:
	# A plan is considered complete once it has generated an order
	# (for combat plans) or the unit has arrived (movement plans).
	if intent == Intent.NONE:
		return true
	if status == Status.ORDER_QUEUED or status == Status.COMPLETED:
		return true
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		# If the module is on cooldown (meaning the order executed), treat as complete.
		if (
			equipped_module
			and source.combatant.cooldown_manager.is_on_cooldown(
				equipped_module.item, equipped_module.module
			)
		):
			return true
	if intent == Intent.RETREAT or intent == Intent.REPOSITION:
		if source.position == destination:
			status = Status.COMPLETED
			return true
	return false


func generate_order(reserved_tiles: Dictionary = {}) -> Order:
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		return _generate_combat_order(reserved_tiles)

	if intent == Intent.RETREAT:
		return _generate_move_order_for_destination()

	if intent == Intent.REPOSITION:
		return _generate_move_order_for_destination()

	if intent == Intent.NONE:
		# No intent to act on.
		push_error("AIPlan: No intent to act on.")
		return null

	# No valid order was generated.
	push_error("AIPlan: No valid order generated.")
	return null


func _generate_combat_order(reserved_tiles: Dictionary) -> Order:
	if not target or not equipped_module:
		return null

	var movement_speed: int = source.combatant.speed
	var range_modifier: int = source.combatant.range_modifier
	var module_range: int = equipped_module.module.module_range + range_modifier
	var is_enemy_target: bool = game_map.is_enemy_of(source, target)
	var min_range: int = 0
	if is_enemy_target:
		min_range = AIUtils.get_offensive_min_range(module_range)

	var distance: float = source.position.distance_to(target.position)
	var target_in_range: bool = (
		(source == target) or (distance >= min_range and distance <= module_range)
	)
	var order: Order = null
	if target_in_range:
		set_status(Status.ORDER_QUEUED)
		if is_enemy_target:
			order = UseOffensiveModuleOrder.new(source, target, equipped_module)
		else:
			order = UseUtilityModuleOrder.new(source, target, equipped_module)
	elif not source.can_move() or movement_speed <= 0:
		set_status(Status.COMPLETED)
		return null
	else:
		AIPathfinder.set_reserved_tiles(reserved_tiles)
		var target_tile: Vector2i = destination
		if target_tile == Vector2i.ZERO:
			target_tile = _find_combat_approach_tile(
				is_enemy_target,
				module_range,
				min_range,
				movement_speed,
			)
		if not (target_tile == Vector2i.ZERO or target_tile == source.position):
			order = MoveOrder.new(source, target_tile)

	return order


func _find_combat_approach_tile(
	is_enemy_target: bool, module_range: int, min_range: int, movement_speed: int
) -> Vector2i:
	if is_enemy_target:
		return AIPathfinder.find_best_attack_tile(
			game_map, source, target, min_range, module_range, movement_speed
		)

	return AIPathfinder.find_closest_reachable_tile(
		game_map, source, target, 0, module_range, movement_speed
	)


func _generate_move_order_for_destination() -> Order:
	if destination == Vector2i.ZERO:
		return null
	return MoveOrder.new(source, destination)


func _to_string() -> String:
	var s := "AIPlan(intent=%s, status=%s" % [
		AIPlan.Intent.keys()[intent],
		AIPlan.Status.keys()[status],
	]
	if source:
		s += ", source=%s" % source.combatant.get_chat_tag()
	if target:
		s += ", target=%s" % target.combatant.get_chat_tag()
	if equipped_module:
		s += ", module=%s" % equipped_module.get_chat_tag()
	if destination != Vector2i.ZERO:
		s += ", tile=%s" % _format_pos_tag(destination)
	s += ", score=%.2f)" % score
	return s
