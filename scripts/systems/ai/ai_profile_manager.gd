extends Node

const PROFILE_FOLDER_PATH: String = "res://data/ai_profiles/"
const DEFAULT_PROFILE_ID: String = "default_basic"

var _profile_cache: Dictionary[String, AIProfile] = {}


func clear_cache() -> void:
	_profile_cache.clear()


func validate_profile_id(profile_id: String) -> bool:
	var resolved_id: String = profile_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = DEFAULT_PROFILE_ID

	var profile: AIProfile = _load_profile_resource(resolved_id)
	if not profile:
		push_error(
			(
				"AI profile id '%s' is invalid. Missing resource at '%s%s.tres'."
				% [resolved_id, PROFILE_FOLDER_PATH, resolved_id]
			)
		)
		return false

	return _validate_profile(profile, resolved_id)


func warm_source(source: MapCombatEntity) -> void:
	_resolve_profile_bundle(source)


func get_profile(unit: MapCombatEntity) -> AIProfile:
	var ai_profile: AIProfile = _resolve_profile_bundle(unit)
	if not ai_profile:
		push_error(
			"Failed to resolve AI profile for %s. Returning null." % unit.combatant.get_chat_tag()
		)
		return null
	return ai_profile


func _resolve_profile_bundle(source: MapCombatEntity) -> AIProfile:
	# Get the profile ID based on the source entity's owner or clan.
	var profile_id: String = _resolve_profile_id(source)

	# Check cache first to avoid redundant loading/parsing.
	if _profile_cache.has(profile_id):
		return _profile_cache[profile_id]

	var ai_profile: AIProfile = _load_profile_resource(profile_id)
	if not ai_profile:
		push_error(
			(
				(
					"Failed to load AI profile resource for profile_id '%s'. "
					+ "Expected .tres profile in '%s'."
				)
				% [profile_id, PROFILE_FOLDER_PATH]
			)
		)
		return null

	if not _validate_profile(ai_profile, profile_id):
		return null

	# Store the loaded profile bundle in cache for future retrievals.
	_profile_cache[profile_id] = ai_profile

	return ai_profile


func _resolve_profile_id(source: MapCombatEntity) -> String:
	if source and source.owner:
		if is_instance_of(source.owner, NPCOwned):
			var npc_owner: NPCOwned = source.owner
			if not npc_owner.ai_profile_path.is_empty():
				return npc_owner.ai_profile_path

		if source.owner.clan and not source.owner.clan.ai_profile_path.is_empty():
			return source.owner.clan.ai_profile_path

	push_error(
		(
			"No AI profile specified for %s or its clan. Using default profile."
			% source.combatant.get_chat_tag()
		)
	)
	return DEFAULT_PROFILE_ID


func _load_profile_resource(profile_id: String) -> AIProfile:
	var profile_path: String = PROFILE_FOLDER_PATH + profile_id + ".tres"
	if not ResourceLoader.exists(profile_path):
		return null
	return load(profile_path) as AIProfile


func _validate_profile(profile: AIProfile, profile_id: String) -> bool:
	if not profile:
		push_error("AI profile '%s' is null." % profile_id)
		return false

	var attack_intent = profile.get("attack")
	var support_intent = profile.get("support")
	var retreat_intent = profile.get("retreat")

	var errors: Array[String] = []

	if not attack_intent:
		errors.append("missing attack intent profile")
	elif not attack_intent.get("target_phase"):
		errors.append("missing attack.target_phase")
	elif not _validate_phase_profile(
		attack_intent.get("target_phase"),
		AIEvaluationContext.Phase.TARGET,
		"attack.target_phase",
		profile_id,
	):
		errors.append("has invalid considerations in attack.target_phase")

	if not support_intent:
		errors.append("missing support intent profile")
	elif not support_intent.get("target_phase"):
		errors.append("missing support.target_phase")
	elif not _validate_phase_profile(
		support_intent.get("target_phase"),
		AIEvaluationContext.Phase.TARGET,
		"support.target_phase",
		profile_id,
	):
		errors.append("has invalid considerations in support.target_phase")

	if not retreat_intent:
		errors.append("missing retreat intent profile")
	else:
		if not retreat_intent.get("activation_phase"):
			errors.append("missing retreat.activation_phase")
		elif not _validate_phase_profile(
			retreat_intent.get("activation_phase"),
			AIEvaluationContext.Phase.INTENT,
			"retreat.activation_phase",
			profile_id,
		):
			errors.append("has invalid considerations in retreat.activation_phase")
		if not retreat_intent.get("destination_phase"):
			errors.append("missing retreat.destination_phase")
		elif not _validate_phase_profile(
			retreat_intent.get("destination_phase"),
			AIEvaluationContext.Phase.TILE,
			"retreat.destination_phase",
			profile_id,
		):
			errors.append("has invalid considerations in retreat.destination_phase")

	if errors.is_empty():
		return true

	for error_message: String in errors:
		push_error("AI profile '%s' %s." % [profile_id, error_message])

	return false


func _validate_phase_profile(
	phase_profile: AIActionProfile,
	required_phase: int,
	phase_label: String,
	profile_id: String,
) -> bool:
	if not phase_profile:
		return false

	for consideration: AIConsideration in phase_profile.considerations:
		if not consideration:
			continue

		if (
			not consideration.allowed_phases.is_empty()
			and not consideration.allowed_phases.has(required_phase)
		):
			push_error(
				(
					"AI profile '%s' invalid phase binding: %s contains consideration '%s' not"
					+ " allowed in phase '%s'."
				)
				% [
					profile_id,
					phase_label,
					consideration.consideration_name,
					AIEvaluationContext.Phase.keys()[required_phase],
				]
			)
			return false

	return true
