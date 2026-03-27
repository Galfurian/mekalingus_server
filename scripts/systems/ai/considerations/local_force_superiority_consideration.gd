## Local force superiority consideration for retreat intent.
##
## This evaluates whether there are more nearby enemy threats than friendly strength.
## Output is a bounded urgency score in [0.0, 1.0]:
## - 0.0 means equal or favorable local force balance (no retreat pressure)
## - 1.0 means strong enemy superiority (highest retreat pressure)
class_name LocalForceSuperioritConsideration
extends AIConsideration


func _init() -> void:
	consideration_name = "local_force_superiority"
	allowed_phases = PackedInt32Array(
		[
			AIEvaluationContext.Phase.INTENT,
			AIEvaluationContext.Phase.TILE,
		]
	)
	required_keys = PackedStringArray(["planning_context", "source", "tile"])


func get_normalized_input(context: Dictionary) -> float:
	var planning_context: AIPlanningContext = context.get("planning_context", null)
	var source: MapCombatEntity = context.get("source", null)
	var tile: Vector2i = context.get("tile", Vector2i.ZERO)

	if not planning_context:
		push_error("Missing planning_context for LocalForceSuperioritConsideration.")
		return 0.0
	if not source:
		push_error("Missing source for LocalForceSuperioritConsideration.")
		return 0.0
	if tile == Vector2i.ZERO:
		tile = source.position

	var source_threat: float = planning_context.get_unit_threat_score(source)
	var enemy_threat_level: float = planning_context.get_tile_threat_score(source, tile)

	if source_threat <= 0.0:
		# Source has no measurable threat; treat enemy presence as max pressure.
		return 0.0 if enemy_threat_level <= 0.0 else 1.0

	# Using the normalized difference formula to keep result in (-1, 1) before clamping.
	# This is stable for all positive values and avoids scale-specific cutoffs.
	var diff: float = enemy_threat_level - source_threat
	var total: float = enemy_threat_level + source_threat
	if total <= 0.0:
		return 0.0

	var normalized_force_disadvantage: float = diff / total
	return clampf(normalized_force_disadvantage, 0.0, 1.0)
