class_name AITacticalBrainResolver
extends RefCounted

const DEFAULT_BRAIN_PATH: String = "res://data/ai_profiles/default_basic.tres"

static var _brain_cache: Dictionary = {}


static func resolve_attack_profile(source: MapCombatEntity) -> AIActionProfile:
	return _resolve_profile(source, "attack_profile")


static func resolve_support_profile(source: MapCombatEntity) -> AIActionProfile:
	return _resolve_profile(source, "support_profile")


static func resolve_retreat_profile(source: MapCombatEntity) -> AIActionProfile:
	return _resolve_profile(source, "retreat_profile")


static func _resolve_profile(source: MapCombatEntity, profile_key: String) -> AIActionProfile:
	var brain: Resource = _resolve_brain(source)
	if not brain:
		return null

	var profile: AIActionProfile = brain.get(profile_key)
	if not profile and source:
		push_warning(
			(
				"Missing %s in tactical brain for %s."
				% [
					profile_key,
					source.combatant.get_chat_tag(),
				]
			)
		)
	return profile


static func _resolve_brain(source: MapCombatEntity) -> Resource:
	var profile_path: String = ""
	if source and source.owner:
		if is_instance_of(source.owner, NPCOwned):
			var npc_owner: NPCOwned = source.owner
			if not npc_owner.ai_profile_path.is_empty():
				profile_path = npc_owner.ai_profile_path

		if (
			profile_path.is_empty()
			and source.owner.clan
			and not source.owner.clan.ai_profile_path.is_empty()
		):
			profile_path = source.owner.clan.ai_profile_path

	if profile_path.is_empty():
		profile_path = DEFAULT_BRAIN_PATH
		if source:
			push_warning(
				(
					"AI profile fallback to default for %s (%s)"
					% [
						source.combatant.get_chat_tag(),
						DEFAULT_BRAIN_PATH,
					]
				)
			)

	if _brain_cache.has(profile_path):
		return _brain_cache[profile_path]

	var loaded_brain: Resource = load(profile_path)
	if not loaded_brain:
		push_warning("Failed to load tactical brain path '%s', using default." % profile_path)
		loaded_brain = load(DEFAULT_BRAIN_PATH)
		if not loaded_brain:
			push_error("Failed to load default tactical brain, AI will not function.")
			return null

	_brain_cache[profile_path] = loaded_brain
	return loaded_brain
