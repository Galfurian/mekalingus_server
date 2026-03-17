class_name TileThreatConsideration
extends "res://scripts/data/ai/ai_consideration.gd"


const DEFAULT_MAX_THREAT: float = 100.0


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	var source: MapCombatEntity = context.get("source", null)
	if not planning_context or not source:
		return 0.0

	var tile: Vector2i = context.get("tile", source.position)
	var threat: float = planning_context.get_threat(tile)
	if DEFAULT_MAX_THREAT <= 0.0:
		return 0.0

	return clampf(threat / DEFAULT_MAX_THREAT, 0.0, 1.0)