class_name StructureAIController
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

# =============================================================================
# PROPERTIES
# =============================================================================

var game_map

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_game_map) -> void:
	game_map = p_game_map


func clear() -> void:
	"""
	Clears runtime state for structure AI systems.
	"""
	# No cached state yet.
	pass


func execute_turret_actions() -> void:
	"""
	Ticks turret cooldowns and executes one attack when a target is in range.
	"""
	for turret: MapTurret in game_map.turrets.values():
		if not turret or not turret.active:
			continue

		var payload: Dictionary = turret.get_offensive_payload()
		if payload.is_empty():
			continue
		var module: ItemModule = payload["module"]
		var effect: ItemEffect = payload["effect"]

		turret.tick_cooldown()
		if not turret.can_fire():
			continue

		var target = _find_turret_target(turret, module.module_range)
		if not target or not target.mek or target.combatant.is_dead():
			continue

		var result = target.combatant.take_damage_from_effect(effect)
		turret.start_cooldown(max(1, module.cooldown))

		game_map.combat_logger.add_log(
			Enums.LogType.ATTACK,
			"%s uses %s on %s -> %d shield, %d armor, %d health" % [
				_turret_tag(turret),
				module.module_name,
				target.combatant.get_chat_tag(),
				result.shield,
				result.armor,
				result.health,
			]
		)


func _find_turret_target(turret: MapTurret, attack_range: int) -> MapCombatEntity:
	"""
	Selects the closest hostile living mek within turret firing range.
	"""
	var closest_target = null
	var closest_distance: float = INF

	for candidate in game_map.player_units.values() + game_map.npc_units.values():
		if not candidate or not candidate.mek or candidate.combatant.is_dead():
			continue
		if not game_map.can_owners_attack(turret.owner, candidate.owner):
			continue

		var distance := turret.position.distance_to(candidate.position)
		if distance > attack_range:
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
