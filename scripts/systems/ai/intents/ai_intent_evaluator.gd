@abstract class_name AIIntentEvaluator
extends RefCounted


@abstract func get_intent() -> AIPlan.Intent


@abstract func get_unavailable_reason() -> String


@abstract func evaluate_intent(planning_context: AIPlanningContext) -> AIPlan
