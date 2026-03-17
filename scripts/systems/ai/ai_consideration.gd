class_name AIConsideration
extends Resource


@export var consideration_name: String = "Unnamed Consideration"
@export var weight: float = 1.0
@export var response_curve: Curve


func evaluate(context: Dictionary) -> float:
	var normalized_input: float = clampf(get_normalized_input(context), 0.0, 1.0)
	var curve_multiplier: float = _sample_curve(normalized_input)
	return curve_multiplier * weight


func get_normalized_input(_context: Dictionary) -> float:
	return 0.0


func _sample_curve(value: float) -> float:
	if not response_curve:
		return value
	return clampf(response_curve.sample(value), 0.0, 1.0)
