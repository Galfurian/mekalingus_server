extends Control


@onready var plan_info: RichTextLabel = $ScrollContainer/PlanInfo


func clear() -> void:
	plan_info.clear()


func display_plan(game_map: GameMap, map_entity: MapCombatEntity) -> void:
	if not game_map or not map_entity:
		clear()
		return

	var plan: AIPlan = game_map.ai_controller.get_current_plan(map_entity)
	if not plan:
		plan_info.clear()
		if map_entity.owner and map_entity.owner.is_player():
			plan_info.append_text(
				"[center][b]Plan[/b][/center]\nPlayer-controlled unit (no AI plan)."
			)
		else:
			plan_info.append_text(
				"[center][b]Plan[/b][/center]\nNo current plan (no actionable order)."
			)
		return


	var text: String = "[center][b]Plan[/b][/center]\n"
	text += "Intent    : %s\n" % AIPlan.Intent.keys()[plan.intent]
	text += "Status    : %s\n" % AIPlan.Status.keys()[plan.status]
	text += "Score     : %.2f\n" % plan.score

	if plan.source and plan.source.combatant:
		text += "Source    : %s\n" % MetaTag.entity_tag(
			plan.source.combatant.uuid,
			plan.source.combatant.get_chat_tag()
		)

	if plan.target and plan.target.combatant:
		text += "Target    : %s\n" % MetaTag.entity_tag(
			plan.target.combatant.uuid,
			plan.target.combatant.get_chat_tag()
		)

	if plan.equipped_module and plan.equipped_module.validate():
		var module_item: Item = plan.equipped_module.item
		var module_name: String = plan.equipped_module.module.module_name
		text += "Module    : %s -> %s\n" % [
			MetaTag.item_tag(module_item.uuid, module_item.template.item_name),
			module_name,
		]

	if plan.destination != Vector2i.ZERO:
		text += "Move To   : %s\n" % MetaTag.pos_tag(plan.destination)

	if map_entity.position:
		text += "Now At    : %s\n" % MetaTag.pos_tag(map_entity.position)

	if plan.target:
		var distance: float = map_entity.position.distance_to(plan.target.position)
		text += "Air Dist  : %.1f\n" % distance

	if plan.decision_trace:
		text += "\n[center][b]Decision Trace[/b][/center]\n"
		for line: String in plan.decision_trace.format_panel_lines():
			text += "%s\n" % line

	if not plan.debug_details.is_empty():
		text += "\n[center][b]Intent Details[/b][/center]\n"
		for key: String in plan.debug_details.keys():
			text += "%s: %s\n" % [key, str(plan.debug_details[key])]

	plan_info.clear()
	plan_info.append_text(text)
