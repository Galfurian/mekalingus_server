class_name AIActionProfile
extends Resource

@export var profile_name: String
@export_range(0.0, 1.0, 0.01) var activation_threshold: float
@export var considerations: Array[AIConsideration]


func evaluate(context: Variant) -> float:
	var score: float = 0.0
	for consideration in considerations:
		if consideration:
			score += consideration.evaluate(context)
	return score


func get_max_score() -> float:
	var max_score: float = 0.0
	for consideration: AIConsideration in considerations:
		if consideration:
			max_score += consideration.weight
	return max_score


func should_activate(context: Variant) -> bool:
	var max_score: float = get_max_score()
	if max_score <= 0.0:
		return false
	var normalized_score: float = evaluate(context) / max_score
	return normalized_score >= activation_threshold
