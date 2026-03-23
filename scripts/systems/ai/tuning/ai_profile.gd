class_name AIProfile
extends RefCounted

var attack_profile: AIActionProfile
var support_profile: AIActionProfile
var retreat_profile: AIActionProfile
var reposition_profile: AIActionProfile


func _init(
	p_attack_profile: AIActionProfile,
	p_support_profile: AIActionProfile,
	p_retreat_profile: AIActionProfile,
	p_reposition_profile: AIActionProfile,
) -> void:
	attack_profile = p_attack_profile
	support_profile = p_support_profile
	retreat_profile = p_retreat_profile
	reposition_profile = p_reposition_profile


static func from_dict(data: Dictionary) -> AIProfile:
	var d_attack_profile: AIActionProfile = AIActionProfile.from_dict(
		data.get("attack_profile", {})
	)
	var d_support_profile: AIActionProfile = AIActionProfile.from_dict(
		data.get("support_profile", {})
	)
	var d_retreat_profile: AIActionProfile = AIActionProfile.from_dict(
		data.get("retreat_profile", {})
	)
	var d_reposition_profile: AIActionProfile = AIActionProfile.from_dict(
		data.get("reposition_profile", {})
	)
	return AIProfile.new(
		d_attack_profile, d_support_profile, d_retreat_profile, d_reposition_profile
	)
