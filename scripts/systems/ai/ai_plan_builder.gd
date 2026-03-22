class_name AIPlanBuilder
extends RefCounted


static func build_plan(
	source: MapCombatEntity,
	game_map: GameMap,
	intent: AIPlan.Intent,
	score: float,
	target,
	equipped_module,
	destination: Vector2i
) -> AIPlan:
	assert(source, "Source cannot be null when building an AI plan.")
	assert(game_map, "Game map cannot be null when building an AI plan.")
	var plan := AIPlan.new(source, game_map)
	plan.intent = intent
	plan.target = target
	plan.equipped_module = equipped_module
	plan.destination = destination
	plan.score = score
	return plan
