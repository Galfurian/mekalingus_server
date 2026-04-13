class_name StateEffect
extends BaseEffect

var runtime_state: int = Enums.RuntimeState.DEPLOYED
var clear_state: bool = false
var state_stat_modifiers: Dictionary = {}


func is_modifier() -> bool:
	return true


func get_effect_class_name() -> String:
	return "StateEffect"


func get_effect_type_label() -> String:
	if clear_state:
		return "Clear State"
	return "Apply State"


func apply(actor) -> void:
	if not actor:
		return
	if clear_state:
		actor.remove_runtime_state(runtime_state)
		return
	actor.add_runtime_state(runtime_state, state_stat_modifiers)


func remove(actor) -> void:
	if not actor:
		return
	if clear_state:
		return
	actor.remove_runtime_state(runtime_state)


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	runtime_state = Enums.get_runtime_state_from_key(str(data.get("state_name", "")))
	if runtime_state < 0:
		runtime_state = Enums.RuntimeState.DEPLOYED
	clear_state = bool(data.get("clear_state", false))
	state_stat_modifiers = _parse_state_stat_modifiers(data.get("state_stat_modifiers", {}))


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["state_name"] = Enums.get_runtime_state_key(runtime_state)
	if clear_state:
		data["clear_state"] = true
	if not state_stat_modifiers.is_empty():
		data["state_stat_modifiers"] = _serialize_state_stat_modifiers()
	return data


func _parse_state_stat_modifiers(raw_modifiers: Variant) -> Dictionary:
	var output: Dictionary = {}
	if typeof(raw_modifiers) != TYPE_DICTIONARY:
		return output

	for raw_key in raw_modifiers.keys():
		var stat_type: int = Enums.get_stat_from_key(str(raw_key))
		if stat_type < 0:
			continue
		output[stat_type] = int(raw_modifiers[raw_key])
	return output


func _serialize_state_stat_modifiers() -> Dictionary:
	var output: Dictionary = {}
	for stat_type in state_stat_modifiers.keys():
		output[Enums.get_stat_key(int(stat_type))] = int(state_stat_modifiers[stat_type])
	return output
