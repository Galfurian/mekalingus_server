class_name AIPlan
extends RefCounted

enum Intent {
	NONE,
	ATTACK,
	SUPPORT,
	RETREAT,
	REPOSITION
}

# ========== PLAN STATE ==========


# Defines the high-level goal of the plan.
var intent: Intent = Intent.NONE
# Check if the plan is complete.
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


# ========== CORE METHODS ==========


func _init(p_source, p_game_map) -> void:
	intent = Intent.NONE
	completed = false

	game_map = p_game_map
	
	source = p_source
	target = null
	destination = Vector2i.ZERO
	equipped_module = null
	score = 0.0


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


func is_valid() -> bool:
	if source == null or source.combatant.is_dead():
		return false
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		if target == null or target.combatant.is_dead():
			return false
		if equipped_module == null:
			return false
		if not AIUtils.is_equipped_module_available(source.combatant, equipped_module):
			return false
		if not AIUtils.can_module_be_used_now(source.combatant, equipped_module.item, equipped_module.module):
			return false
	if intent == Intent.RETREAT or intent == Intent.REPOSITION:
		if destination == Vector2i.ZERO:
			return false
	if is_complete():
		return false
	return true


func is_complete() -> bool:
	if intent == Intent.NONE:
		return true
	if completed:
		return true
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		if equipped_module and source.combatant.cooldown_manager.is_on_cooldown(equipped_module.item, equipped_module.module):
			return true
	if intent == Intent.RETREAT or intent == Intent.REPOSITION:
		if source.position == destination:
			return true
	return false


func generate_order() -> Order:
	# Get the range modifier for the enemy unit.
	var range_modifier = source.combatant.range_modifier
	
	# Check if the intent is that to attack or support.
	if intent == Intent.ATTACK or intent == Intent.SUPPORT:
		# Check the essential parameters.
		if not target:
			return null
		if not equipped_module:
			return null
		# Get the mek speed.
		var movement_speed: int = source.combatant.speed
		# Get the module range.
		var module_range = equipped_module.module.module_range + range_modifier
		# Compute the distance to the target to determine if we need to move.
		var distance = source.position.distance_to(target.position)
		# Check if the target is in range of the module.
		var target_in_range = (source == target) or (distance >= 0 and distance <= module_range)
		# If the target is out of range, we need to move to the target.
		if not target_in_range:
			if not source.can_move() or movement_speed <= 0:
				completed = true
				return null
			# This will keep track of the best tile to act from.
			var target_tile: Vector2i = Vector2i.ZERO
			# Check if the target is an enemy of the source.
			if game_map.is_enemy_of(source, target):
				# We need to find the best tile to act from.
				target_tile = AIUtils.find_best_attack_tile(game_map, source, target, 0, module_range, movement_speed)
			else:
				target_tile = AIUtils.find_closest_reachable_tile(game_map, source, target, 0, module_range, movement_speed)
			# If the best tile is the same as the source position, we can't move, so we move randomly.
			if target_tile == source.position:
				target_tile = AIUtils.find_random_reachable_tile(game_map, source.position, movement_speed)
			# Move to the best tile to act from.
			if target_tile == Vector2i.ZERO:
				return null
			return MoveOrder.new(source, target_tile)
		# Mark the plan as completed.
		completed = true
		# Check if the target is an enemy of the source.
		if game_map.is_enemy_of(source, target):
			# Generate the order to use the offensive module on the target.
			return UseOffensiveModuleOrder.new(source, target, equipped_module)
		# Generate the order to use the utility module on the target.
		return UseUtilityModuleOrder.new(source, target, equipped_module)

	if intent == Intent.RETREAT:
		# Check the essential parameters.
		if destination == Vector2i.ZERO:
			return null
		# Generate the order to move to the destination.
		return MoveOrder.new(source, destination)

	if intent == Intent.REPOSITION:
		# Check the essential parameters.
		if destination == Vector2i.ZERO:
			return null
		# Generate the order to move to the destination.
		return MoveOrder.new(source, destination)

	if intent == Intent.NONE:
		# No intent to act on.
		push_error("AIPlan: No intent to act on.")
		return null

	# No valid order was generated.
	push_error("AIPlan: No valid order generated.")
	return null

func _to_string() -> String:
	var s := "AIPlan(intent=%s, completed=%s" % [AIPlan.Intent.keys()[intent], str(completed)]
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
