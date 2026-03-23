class_name AIEvaluationContext
extends RefCounted


enum Phase {
	INTENT,
	TARGET,
	TILE,
	MODULE,
}


var phase: Phase = Phase.INTENT
var source: MapCombatEntity = null
var planning_context: AIPlanningContext = null
var target: MapCombatEntity = null
var module: ItemModule = null
var tile: Vector2i = Vector2i.ZERO
var max_distance: float = 0.0


static func for_intent(
	p_source: MapCombatEntity,
	p_planning_context: AIPlanningContext,
) -> AIEvaluationContext:
	var context := AIEvaluationContext.new()
	context.phase = Phase.INTENT
	context.source = p_source
	context.planning_context = p_planning_context
	context.tile = p_source.position if p_source else Vector2i.ZERO
	return context


static func for_target(
	p_source: MapCombatEntity,
	p_target: MapCombatEntity,
	p_module: ItemModule,
	p_planning_context: AIPlanningContext,
	p_tile: Vector2i,
	p_max_distance: float,
) -> AIEvaluationContext:
	var context := AIEvaluationContext.new()
	context.phase = Phase.TARGET
	context.source = p_source
	context.target = p_target
	context.module = p_module
	context.planning_context = p_planning_context
	context.tile = p_tile
	context.max_distance = p_max_distance
	return context


static func for_tile(
	p_source: MapCombatEntity,
	p_planning_context: AIPlanningContext,
	p_tile: Vector2i,
) -> AIEvaluationContext:
	var context := AIEvaluationContext.new()
	context.phase = Phase.TILE
	context.source = p_source
	context.planning_context = p_planning_context
	context.tile = p_tile
	return context


func to_dict() -> Dictionary:
	return {
		"source": source,
		"target": target,
		"module": module,
		"planning_context": planning_context,
		"tile": tile,
		"max_distance": max_distance,
		"phase": phase,
	}
