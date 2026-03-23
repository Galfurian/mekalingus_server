@abstract class_name AIConsideration
extends Resource

@export var consideration_name: String = "Unnamed Consideration"
@export var weight: float = 1.0


func _init(
	p_consideration_name: String = "Unnamed Consideration",
	p_weight: float = 1.0,
) -> void:
	consideration_name = p_consideration_name
	weight = p_weight


func evaluate(
	context: Dictionary,
) -> float:
	# Get the normalized input value for this consideration based on the provided context.
	var normalized_input: float = get_normalized_input(context)
	assert(
		normalized_input >= 0.0 and normalized_input <= 1.0,
		"Normalized input must be between 0 and 1."
	)
	# Apply the response curve to the normalized input, if a curve is defined.
	return normalized_input * weight


@abstract func get_normalized_input(context: Dictionary) -> float
