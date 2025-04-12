class_name AIPlan
extends RefCounted

enum Intent {
	NONE,
	ATTACK,
	SUPPORT,
	RETREAT,
	REPOSITION
}

enum Phase {
	UNINITIALIZED,
	MOVE_THEN_ACT,
	ACT_IN_PLACE,
	WAIT,
	COMPLETE
}


# ========== PLAN STATE ==========


# Defines the high-level goal of the plan.
var intent: Intent = Intent.NONE
# Tracks where we are in the execution (e.g., move first, act now, done).
var phase: Phase = Phase.UNINITIALIZED


# ========== PLAN DATA ==========


# The game map associated with this plan.
var game_map: GameMap
# The unit executing the plan.
var source: MapMek = null
# The target of the action (if any).
var target: MapMek = null
# The tile the AI wants to move to, if movement is part of the plan.
var destination: Vector2i
# The offensive or utility module involved in the action.
var equipped_module: EquippedModule = null
# The priority ranking assigned during planning.
var score: float = 0.0


# ========== CORE METHODS ==========


func _init(p_source: MapMek, p_game_map: GameMap) -> void:
	intent = Intent.NONE
	phase = Phase.UNINITIALIZED

	game_map = p_game_map
	
	source = p_source
	target = null
	destination = Vector2i.ZERO
	equipped_module = null
	score = 0.0


func is_valid() -> bool:
	# Plan requires an active source unit.
	if source == null or source.mek.is_dead():
		return false

	# If a target is specified, it must still be valid and active.
	if target != null and target.mek.is_dead():
		return false

	# If the plan requires a module, it must still be usable.
	if equipped_module != null:
		if not AIUtils.can_module_be_used_now(source.mek, equipped_module.item, equipped_module.module):
			return false

	# If the plan is already complete, it's not valid anymore.
	if is_complete():
		return false

	return true


func is_complete() -> bool:
	match phase:
		Phase.COMPLETE:
			return true
		Phase.MOVE_THEN_ACT:
			# Still moving to desired tile.
			return false
		Phase.ACT_IN_PLACE:
			# Still needs to perform action.
			return false
		Phase.WAIT, Phase.UNINITIALIZED:
			# No action to perform.
			return true
	return true


func generate_order() -> Order:
	match phase:
		Phase.ACT_IN_PLACE, Phase.MOVE_THEN_ACT:
			# Check if we need to move before acting.
			if phase == Phase.MOVE_THEN_ACT and source.position != destination and destination != Vector2i.ZERO:
				# Still in the process of reaching the action position.
				# Phase remains unchanged.
				return MoveOrder.new(source, destination)

			# We are in position to act.
			if target and equipped_module:
				# Get the module range.
				var module_range = equipped_module.module.module_range
				# Decide the best tile to act from.
				if target != source:
					# Compute the distance to the target to determine if we need to move.
					var distance = source.position.distance_to(target.position)
					# Check if the target is in range of the module.
					var already_in_range = distance >= 0 and distance <= module_range
					if not already_in_range:
						var destination: Vector2i = Vector2i.ZERO
						# Check if the target is an enemy of the source.
						if game_map.is_enemy_of(source, target):
							# We need to find the best tile to act from.
							destination = AIUtils.find_best_attack_tile(
								game_map,
								source,
								target,
								0,
								module_range,
								source.mek.speed
							)
						else:
							destination = AIUtils.find_closest_reachable_tile(
								game_map,
								source,
								target,
								0,
								module_range,
								source.mek.speed
							)
						# Move to the best tile to act from.
						if destination != Vector2i.ZERO and destination != source.position:
							return MoveOrder.new(source, destination)
						# No valid tile to move to.
						return null
				# Update the phase to complete after the order is generated.
				phase = Phase.COMPLETE
				# Check if the target is an enemy of the source.
				if game_map.is_enemy_of(source, target):
					# Generate the order to use the offensive module on the target.
					return UseOffensiveModuleOrder.new(source, target, equipped_module)
				else:
					# Generate the order to use the utility module on the target.
					return UseUtilityModuleOrder.new(source, target, equipped_module)

			# No target or equipped module, so we can't act.
			push_error("AIPlan: No target or equipped module to act with.")

		Phase.WAIT:
			# This unit is skipping its turn or waiting intentionally.
			pass

	# No valid order was generated.
	return null

func _to_string() -> String:
	var s := "AIPlan(intent=%s, phase=%s" % [
		AIPlan.Intent.keys()[intent],
		AIPlan.Phase.keys()[phase]
	]

	if source:
		s += ", source=%s" % source.mek.get_chat_tag()
	if target:
		s += ", target=%s" % target.mek.get_chat_tag()
	if equipped_module:
		s += ", module=%s" % equipped_module.get_chat_tag()
	if destination != Vector2i.ZERO:
		s += ", tile=%s" % str(destination)
	s += ", score=%.2f)" % score
	return s
