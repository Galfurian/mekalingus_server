extends Node

const PROFILE_FOLDER_PATH: String = "res://data/ai_profiles/"
const DEFAULT_PROFILE_ID: String = "default_basic"

var _profile_cache: Dictionary[String, AIProfile] = {}


func clear_cache() -> void:
	_profile_cache.clear()


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

	if not profile.attack_profile:
		push_error("AI profile '%s' missing attack_profile." % profile_id)
		return false
	if not profile.support_profile:
		push_error("AI profile '%s' missing support_profile." % profile_id)
		return false
	if not profile.retreat_profile:
		push_error("AI profile '%s' missing retreat_profile." % profile_id)
		return false
	if not profile.reposition_profile:
		push_error("AI profile '%s' missing reposition_profile." % profile_id)
		return false

	return true
