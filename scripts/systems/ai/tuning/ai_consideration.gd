@abstract class_name AIConsideration
extends Resource

@export var consideration_name: String = "Unnamed Consideration"
@export var weight: float = 1.0
@export var invert_output: bool = false
@export var allowed_phases: PackedInt32Array = PackedInt32Array()
@export var required_keys: PackedStringArray = PackedStringArray()


func _init(
	p_consideration_name: String = "Unnamed Consideration",
	p_weight: float = 1.0,
	p_invert_output: bool = false,
) -> void:
	consideration_name = p_consideration_name
	weight = p_weight
	invert_output = p_invert_output


func evaluate(
	context: Dictionary,
) -> float:
	return evaluate_variant(context)


func evaluate_variant(context: Variant) -> float:
	var normalized_context: Dictionary = _normalize_context(context)
	if normalized_context.is_empty():
		return 0.0

	var phase: int = _extract_phase(normalized_context)
	if not _supports_phase(phase):
		push_error(
			(
				"AIConsideration '%s' does not support phase '%s'."
				% [consideration_name, _phase_to_string(phase)]
			)
		)
		return 0.0

	if not _has_required_keys(normalized_context):
		return 0.0

	# Get the normalized input value for this consideration based on the provided context.
	var normalized_input: float = get_normalized_input(normalized_context)
	assert(
		normalized_input >= 0.0 and normalized_input <= 1.0,
		"Normalized input must be between 0 and 1."
	)

	if invert_output:
		normalized_input = clampf(1.0 - normalized_input, 0.0, 1.0)

	# Apply weight to transformed input.
	return normalized_input * weight


func _normalize_context(context: Variant) -> Dictionary:
	if context is AIEvaluationContext:
		return (context as AIEvaluationContext).to_dict()
	if context is Dictionary:
		return context
	push_error("AIConsideration '%s' received unsupported context type." % consideration_name)
	return {}


func _extract_phase(context: Dictionary) -> int:
	return int(context.get("phase", AIEvaluationContext.Phase.INTENT))


func _supports_phase(phase: int) -> bool:
	if allowed_phases.is_empty():
		return true
	return allowed_phases.has(phase)


func _has_required_keys(context: Dictionary) -> bool:
	for key: String in required_keys:
		if not context.has(key):
			push_error(
				"AIConsideration '%s' missing required key '%s'." % [consideration_name, key]
			)
			return false
		if context[key] == null:
			push_error("AIConsideration '%s' key '%s' is null." % [consideration_name, key])
			return false
	return true


func _phase_to_string(phase: int) -> String:
	if phase < 0 or phase >= AIEvaluationContext.Phase.size():
		return "UNKNOWN"
	return AIEvaluationContext.Phase.keys()[phase]


func _add_thought(source: MapCombatEntity, message: String) -> void:
	if source and source.combatant:
		source.combatant.add_ai_thought(message)


@abstract func get_normalized_input(context: Dictionary) -> float
