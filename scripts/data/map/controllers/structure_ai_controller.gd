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
	Executes one autonomous attack for each armed structure.
	"""
	for structure: MapStructure in game_map.structures.values():
		if not structure or not structure.active:
			continue

		var payload: Dictionary = structure.get_offensive_payload()
		if payload.is_empty():
			continue

		var item: Item = payload["item"]
		var module: ItemModule = payload["module"]
		var effect: ItemEffect = payload["effect"]
		if structure.combatant.cooldown_manager.is_on_cooldown(item, module):
			continue

		var target: MapCombatEntity = _find_structure_target(structure, module.module_range)
		if not target or target.combatant.is_dead():
			continue

		var result: Dictionary = target.combatant.take_damage_from_effect(effect)
		structure.combatant.cooldown_manager.start_cooldown(item, module)

		game_map.combat_logger.add_log(
			Enums.LogType.ATTACK,
			"%s uses %s on %s -> %d shield, %d armor, %d health" % [
				_structure_tag(structure),
				module.module_name,
				target.combatant.get_chat_tag(),
				result.shield,
				result.armor,
				result.health,
			]
		)


func _find_structure_target(structure: MapStructure, attack_range: int) -> MapCombatEntity:
	"""
	Selects the closest hostile living unit within structure firing range.
	"""
	var closest_target: MapCombatEntity = null
	var closest_distance: float = INF

	for candidate in game_map.player_units.values() + game_map.npc_units.values():
		if not candidate or candidate.combatant.is_dead():
			continue
		if not game_map.can_owners_attack(structure.owner, candidate.owner):
			continue

		var distance: float = structure.position.distance_to(candidate.position)
		if distance > attack_range:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_target = candidate

	return closest_target


func _structure_tag(structure: MapStructure) -> String:
	return "[url=pos:%d,%d]%s[/url]" % [
		structure.position.x,
		structure.position.y,
		structure.combatant.get_structure_name(),
	]
