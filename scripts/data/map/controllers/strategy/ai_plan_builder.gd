class_name AIPlanBuilder
extends RefCounted


static func build_plan(
	context: AIPlanningContext,
	intent: AIPlan.Intent,
	score: float,
	target,
	equipped_module,
	destination: Vector2i
) -> AIPlan:
	var plan := AIPlan.new(context.source, context.game_map)
	plan.intent = intent
	plan.target = target
	plan.equipped_module = equipped_module
	plan.destination = destination
	plan.score = score
	return plan
