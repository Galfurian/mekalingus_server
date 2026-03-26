## Consideration for local force superiority assessment during retreat evaluation.
## Compares nearby enemy combat power (scaled by unit size) against source power.
## Higher values (enemy_power > source_power) indicate disadvantage and retreat urgency.
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

	# Get the source threat level (own combat value) from planning context.
	var source_threat: float = planning_context.get_unit_threat_score(source)
	# Get the total threat of nearby enemies at this tile.
	var enemy_threat_level: float = planning_context.get_tile_threat_score(source, tile)

	# If source has no threat (e.g. uninitialized or dead), fallback:
	# - no enemy threat -> 0 (safe)
	# - enemy threat present -> 1 (max urgency)
	if source_threat <= 0.0:
		return 0.0 if enemy_threat_level <= 0.0 else 1.0

	# Calculate force ratio (enemy_power / source_power), mainly for debugging or future tuning.
	# var force_ratio: float = enemy_threat_level / source_threat

	# Score local advantage by using a normalized difference fraction:
	# 0.0 at parity or friendly advantage, approaching 1.0 as enemy threat grows.
	# This avoids arbitrary hard max cutoffs and is globally bounded for all positive values.
	# formula: (enemy - source) / (enemy + source)
	# - enemy==source -> 0.0
	# - enemy>>source -> 1.0
	# - enemy<source -> negative (clamped to 0.0, no retreat pressure)
	var diff: float = enemy_threat_level - source_threat
	var total: float = enemy_threat_level + source_threat
	if total <= 0.0:
		return 0.0

	var normalized_force_disadvantage: float = diff / total
	return clampf(normalized_force_disadvantage, 0.0, 1.0)
