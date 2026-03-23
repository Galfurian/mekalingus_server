class_name AIActionProfile
extends RefCounted

var profile_name: String = "default"
var considerations: Array[AIConsideration] = []
var activation_threshold: float = 0.5


func _init(
	p_profile_name: String = "default",
	p_activation_threshold: float = 0.5,
	p_considerations: Array[AIConsideration] = [],
) -> void:
	profile_name = p_profile_name
	activation_threshold = clampf(p_activation_threshold, 0.0, 1.0)
	considerations = p_considerations


func evaluate(
	context: Dictionary,
) -> float:
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


func should_activate(
	context: Dictionary,
) -> bool:
	var max_score: float = get_max_score()
	if max_score <= 0.0:
		return false
	var normalized_score: float = evaluate(context) / max_score
	return normalized_score >= activation_threshold


static func from_dict(data: Dictionary) -> AIActionProfile:
	var d_profile_name: String = data.get("profile_name", "default")
	var d_activation_threshold: float = float(data.get("activation_threshold", 0.5))
	var d_considerations_data: Array = data.get("considerations", [])
	var d_considerations: Array[AIConsideration] = []
	for consideration_entry in d_considerations_data:
		var consideration: AIConsideration = AIConsideration.from_dict(consideration_entry)
		if consideration:
			d_considerations.append(consideration)
	return AIActionProfile.new(d_profile_name, d_activation_threshold, d_considerations)
