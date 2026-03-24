class_name AIBaselineCapture
extends RefCounted


static func capture(game_map: GameMap) -> Dictionary:
	if not game_map or not game_map.ai_controller:
		return {
			"error": "missing game_map or ai_controller",
		}

	var snapshot: Dictionary = game_map.ai_controller.export_ai_baseline_snapshot()
	snapshot["captured_at"] = Time.get_datetime_string_from_system()
	return snapshot
