class_name DeployOrder
extends Order

var source
var deploy: bool = true


func _init(p_source, p_deploy: bool) -> void:
	source = p_source
	deploy = p_deploy


func validate() -> bool:
	if not source or not source.combatant:
		return false
	if source.combatant.is_dead():
		return false

	var has_deploy_module: bool = false
	for item: Item in source.combatant.items:
		if not item or not item.template:
			continue
		for module: ItemModule in item.template.modules:
			if Enums.RuntimeState.DEPLOYED in module.required_states:
				has_deploy_module = true
				break
		if has_deploy_module:
			break
	if not has_deploy_module:
		return false

	var is_deployed: bool = source.combatant.has_runtime_state(Enums.RuntimeState.DEPLOYED)
	if deploy and is_deployed:
		return false
	if not deploy and not is_deployed:
		return false
	return true


func execute(game_map) -> bool:
	if not validate():
		return false

	if deploy:
		source.combatant.add_runtime_state(Enums.RuntimeState.DEPLOYED)
		if is_instance_valid(game_map):
			game_map.combat_logger.add_log(
				Enums.LogType.SUPPORT,
				"%s deploys." % source.combatant.get_chat_tag(),
			)
	else:
		source.combatant.remove_runtime_state(Enums.RuntimeState.DEPLOYED)
		if is_instance_valid(game_map):
			game_map.combat_logger.add_log(
				Enums.LogType.SUPPORT,
				"%s undeploys." % source.combatant.get_chat_tag(),
			)

	return true


func _to_string() -> String:
	if not source or not source.combatant:
		return "<DeployOrder invalid>"
	if deploy:
		return "%s is deploying" % source.combatant.get_chat_tag()
	return "%s is undeploying" % source.combatant.get_chat_tag()
