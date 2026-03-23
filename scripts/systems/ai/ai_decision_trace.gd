class_name AIDecisionTrace
extends RefCounted


var source_uuid: String = ""
var source_tag: String = ""
var turn_number: int = 0
var selected_intent: AIPlan.Intent = AIPlan.Intent.NONE
var selected_score: float = 0.0
var intents: Array[Dictionary] = []


func _init(source: MapCombatEntity, p_turn_number: int) -> void:
	turn_number = p_turn_number
	if source and source.combatant:
		source_uuid = source.combatant.uuid
		source_tag = source.combatant.get_chat_tag()


func record_intent_result(
	intent: AIPlan.Intent,
	candidate: AIPlan,
	reason: String = "",
) -> void:
	var intent_name: String = AIPlan.Intent.keys()[intent]
	var has_candidate: bool = candidate != null
	var entry: Dictionary = {
		"intent": intent,
		"intent_name": intent_name,
		"has_candidate": has_candidate,
		"score": 0.0,
		"selected": false,
		"reason": reason,
		"details": {},
	}

	if has_candidate:
		entry["score"] = candidate.score
		if candidate.debug_details is Dictionary:
			entry["details"] = candidate.debug_details.duplicate(true)

	intents.append(entry)


func mark_selected(plan: AIPlan) -> void:
	if not plan:
		return

	selected_intent = plan.intent
	selected_score = plan.score

	for entry: Dictionary in intents:
		if int(entry.get("intent", -1)) != plan.intent:
			continue
		if not bool(entry.get("has_candidate", false)):
			continue
		entry["selected"] = true
		return


func format_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("TRACE source=%s turn=%d" % [source_tag, turn_number])

	for entry: Dictionary in intents:
		var intent_name: String = str(entry.get("intent_name", "UNKNOWN"))
		var has_candidate: bool = bool(entry.get("has_candidate", false))
		if has_candidate:
			var marker: String = "*" if bool(entry.get("selected", false)) else "-"
			lines.append(
				"%s %s score=%.2f"
				% [marker, intent_name, float(entry.get("score", 0.0))]
			)
		else:
			var reason: String = str(entry.get("reason", "no candidate"))
			lines.append("- %s unavailable (%s)" % [intent_name, reason])

	return lines


func format_panel_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in intents:
		var intent_name: String = str(entry.get("intent_name", "UNKNOWN"))
		var has_candidate: bool = bool(entry.get("has_candidate", false))
		if has_candidate:
			var selected_mark: String = " [selected]" if bool(entry.get("selected", false)) else ""
			lines.append(
				"%s: %.2f%s"
				% [intent_name, float(entry.get("score", 0.0)), selected_mark]
			)
		else:
			var reason: String = str(entry.get("reason", "no candidate"))
			lines.append("%s: unavailable (%s)" % [intent_name, reason])

	return lines


func get_intent_score(intent: AIPlan.Intent) -> float:
	for entry: Dictionary in intents:
		if int(entry.get("intent", -1)) == intent and bool(entry.get("has_candidate", false)):
			return float(entry.get("score", 0.0))
	return 0.0
