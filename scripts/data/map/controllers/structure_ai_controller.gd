class_name StructureAIController
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

const TURRET_COOLDOWN_TURNS: int = 2

# =============================================================================
# PROPERTIES
# =============================================================================

var game_map: GameMap

# =============================================================================
# GENERAL FUNCTIONS
# =============================================================================


func _init(p_game_map: GameMap) -> void:
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

		turret.tick_cooldown()
		if not turret.can_fire():
			continue

		var target: MapMek = _find_turret_target(turret)
		if not target or not target.mek or target.mek.is_dead():
			continue

		var damage_effect: ItemEffect = turret.get_fire_effect()
		if not damage_effect:
			continue

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
