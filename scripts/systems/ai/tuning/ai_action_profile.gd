class_name AIActionProfile
extends Resource

@export var profile_name: String
@export_range(0.0, 1.0, 0.01) var activation_threshold: float
@export var considerations: Array[AIConsideration]


func evaluate(
	context: Dictionary,
) -> float:
	return evaluate_variant(context)


func evaluate_variant(context: Variant) -> float:
	var score: float = 0.0
	for consideration in considerations:
		if consideration:
			score += consideration.evaluate_variant(context)
	return score


func get_max_score() -> float:
	var max_score: float = 0.0
	for consideration: AIConsideration in considerations:
		if consideration:
			max_score += consideration.weight
	return max_score


func should_activate(
	context: Dictionary,
) -> bool:
	return should_activate_variant(context)


func should_activate_variant(context: Variant) -> bool:
	var max_score: float = get_max_score()
	if max_score <= 0.0:
		return false
	var normalized_score: float = evaluate_variant(context) / max_score
	return normalized_score >= activation_threshold
