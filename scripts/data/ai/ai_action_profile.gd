class_name AIActionProfile
extends Resource


const DEFAULT_MAX_TARGETS_TO_NARROW_PHASE: int = 3
const DEFAULT_MAX_EXPENSIVE_OPS_PER_FRAME: int = 3


@export var profile_name: String = "default"
@export var preliminary_considerations: Array[Resource] = []
@export var final_considerations: Array[Resource] = []
@export var max_targets_to_narrow_phase: int = DEFAULT_MAX_TARGETS_TO_NARROW_PHASE
@export var max_expensive_ops_per_frame: int = DEFAULT_MAX_EXPENSIVE_OPS_PER_FRAME
@export var in_range_los_bonus: float = 10.0
@export var reachable_bonus: float = 6.0
@export var unreachable_penalty: float = 8.0


func evaluate_preliminary(context: Dictionary) -> float:
	return _evaluate_considerations(preliminary_considerations, context)


func evaluate_final(context: Dictionary) -> float:
	var score: float = _evaluate_considerations(final_considerations, context)
	if score <= 0.0:
		score = _evaluate_considerations(preliminary_considerations, context)
	return score


func get_max_targets_to_narrow_phase() -> int:
	return maxi(1, max_targets_to_narrow_phase)


func get_max_expensive_ops_per_frame() -> int:
	return maxi(1, max_expensive_ops_per_frame)


func _evaluate_considerations(considerations: Array[Resource], context: Dictionary) -> float:
	var score: float = 0.0
	for consideration: Resource in considerations:
		if not consideration:
			continue
		if consideration.has_method("evaluate"):
			score += consideration.evaluate(context)
	return score
