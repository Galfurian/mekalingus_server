class_name TargetDistanceConsideration
extends "res://scripts/systems/ai/ai_consideration.gd"


func get_normalized_input(context: Dictionary) -> float:
	var source: MapCombatEntity = context.get("source", null)
	var target: MapCombatEntity = context.get("target", null)
	var max_distance: float = float(context.get("max_distance", 1.0))
	if not source or not target:
		return 0.0
	if max_distance <= 0.0:
		return 0.0
	var distance: float = _manhattan_distance(source.position, target.position)
	return clampf(distance / max_distance, 0.0, 1.0)


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
