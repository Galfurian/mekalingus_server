@abstract class_name AIConsideration
extends Resource

var consideration_name: String = "Unnamed Consideration"
var weight: float = 1.0


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


static func from_dict(data: Dictionary) -> AIConsideration:
	var consideration_type: String = data.get("type", "")
	var consideration: AIConsideration = null

	match consideration_type:
		"target_survivability":
			consideration = TargetSurvivabilityConsideration.new()
		"target_distance":
			consideration = TargetDistanceConsideration.new()
		"offensive_module_effectiveness":
			consideration = OffensiveModuleEffectivenessConsideration.new()
		"utility_module_effectiveness":
			consideration = UtilityModuleEffectivenessConsideration.new()
		"source_survivability":
			consideration = SourceSurvivabilityConsideration.new()
		"tile_threat":
			consideration = TileThreatConsideration.new()
		"local_force_superiority":
			consideration = LocalForceSuperioritConsideration.new()
		"retreat_direction":
			consideration = RetreatDirectionConsideration.new()
		_:
			push_warning("Unknown AI consideration type '%s'" % consideration_type)
	if not consideration:
		return null
	consideration.consideration_name = consideration_type
	consideration.weight = float(data.get("weight", 1.0))
	return consideration
