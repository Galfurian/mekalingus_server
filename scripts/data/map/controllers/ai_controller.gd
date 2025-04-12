class_name AIController
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

# A reference to the game map.
var game_map: GameMap

# Create a planner instance and generate a plan.
var _planner = AIPlanner.new()
# The current plans for the AI.
var _current_plans: Dictionary[String, AIPlan] = {}


# =============================================================================
# GENERIC FUNCTIONS
# =============================================================================


func _init(p_game_map: GameMap) -> void:
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


func _add_log(message: String) -> void:
	if is_instance_valid(game_map):
		game_map.combat_logger.add_log(Enums.LogType.AI, message)
		return


func _format_pos_tag(pos: Vector2i) -> String:
	return "[url=pos:%d,%d](%d,%d)[/url]" % [pos.x, pos.y, pos.x, pos.y]


func plan_for_unit(source: MapMek) -> void:
	"""
	Generates a plan for the given unit if the current one is missing or no longer valid.
	"""
	# Check if we already have a valid plan.
	var current_plan = _current_plans.get(source.mek.uuid, null)
	# If the plan is valid, no need to re-plan.
	if current_plan and current_plan.is_valid():
		return # No need to re-plan
	# Get the clan aggressiveness and generate a plan.
	var aggressiveness = source.owner.clan.aggressiveness
	# Generate the plan for the source unit.
	var new_plan = _planner.generate_plan(source, game_map, aggressiveness)
	# Save the new plan.
	_current_plans[source.mek.uuid] = new_plan


func generate_order_for_unit(source: MapMek) -> Order:
	"""
	Generates an order for the given unit based on its current plan.
	If the plan is invalid or has been completed, re-planning may occur.
	"""
	# Ensure the unit has a current plan, or regenerate if needed.
	plan_for_unit(source)

	# Retrieve the current plan from the cache.
	var current_plan = _current_plans.get(source.mek.uuid, null)
	if current_plan:
		# If the plan is already complete, there's nothing left to do this turn.
		if current_plan.is_complete():
			return null
		# If the plan is still valid, generate the next order.
		if current_plan.is_valid():
			var order = current_plan.generate_order()
			_add_log("%s generated order for plan %s : %s" % [
				source.mek.get_chat_tag(),
				str(current_plan),
				str(order)
			])
			return order
		# The plan is not valid but not yet marked complete — regenerate a new one.
		plan_for_unit(source)
		# Retrieve the new plan.
		current_plan = _current_plans.get(source.mek.uuid, null)
		# If the new plan is valid and not yet complete, execute it.
		if current_plan and not current_plan.is_complete() and current_plan.is_valid():
			return current_plan.generate_order()
	# No valid order could be generated.
	return null
