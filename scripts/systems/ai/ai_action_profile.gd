class_name AIActionProfile
extends Resource

const DEFAULT_MAX_TARGETS_TO_NARROW_PHASE: int = 3

@export var profile_name: String = "default"
@export var preliminary_considerations: Array[Resource] = []
@export var final_considerations: Array[Resource] = []
@export var max_targets_to_narrow_phase: int = DEFAULT_MAX_TARGETS_TO_NARROW_PHASE
@export var in_range_los_bonus: float = 10.0
@export var reachable_bonus: float = 6.0


func evaluate_preliminary(context: Dictionary) -> float:
	return _evaluate_considerations(preliminary_considerations, context)


func evaluate_final(context: Dictionary) -> float:
	var score: float = _evaluate_considerations(final_considerations, context)
	if score <= 0.0:
		score = _evaluate_considerations(preliminary_considerations, context)
	return score


func get_max_targets_to_narrow_phase() -> int:
	return maxi(1, max_targets_to_narrow_phase)


func _evaluate_considerations(considerations: Array[Resource], context: Dictionary) -> float:
	var score: float = 0.0
	for consideration: Resource in considerations:
		if not consideration:
			continue
		if consideration.has_method("evaluate"):
			score += consideration.evaluate(context)
	return score


func evaluate_preliminary_breakdown(context: Dictionary) -> Dictionary:
	return _evaluate_considerations_breakdown(preliminary_considerations, context)


func evaluate_final_breakdown(context: Dictionary) -> Dictionary:
	var breakdown: Dictionary = _evaluate_considerations_breakdown(final_considerations, context)
	if breakdown.score <= 0.0:
		breakdown = _evaluate_considerations_breakdown(preliminary_considerations, context)
	return breakdown


func _evaluate_considerations_breakdown(
	considerations: Array[Resource],
	context: Dictionary,
) -> Dictionary:
	var score: float = 0.0
	var components: Array[Dictionary] = []
	for consideration: Resource in considerations:
		if not consideration:
			continue
		if not consideration.has_method("evaluate"):
			continue

		var normalized_input: float = clampf(
			consideration.get_normalized_input(context),
			0.0,
			1.0,
		)
		var curve_multiplier: float = 0.0
		if consideration.response_curve:
			curve_multiplier = clampf(
				consideration.response_curve.sample(normalized_input),
				0.0,
				1.0,
			)
		var contribution: float = curve_multiplier * consideration.weight
		score += contribution
		(
			components
			. append(
				{
					"name": consideration.consideration_name,
					"normalized_input": normalized_input,
					"curve": curve_multiplier,
					"weight": consideration.weight,
					"contribution": contribution,
				}
			)
		)

	return {
		"score": score,
		"components": components,
	}
