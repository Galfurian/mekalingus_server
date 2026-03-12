class_name NpcDirectiveState
extends RefCounted


enum Directive {
	HOLD_PERIMETER,
	PATROL,
	SEEK_AND_DESTROY,
	DEFEND_POINT,
	RETREAT_TO_SAFE_ZONE,
}


var directive: int = Directive.HOLD_PERIMETER
var anchor_position: Vector2i = Vector2i.ZERO
var defend_position: Vector2i = Vector2i.ZERO
var patrol_waypoints: Array[Vector2i] = []
var patrol_index: int = 0
var compact_radius: int = 4
var leash_radius: int = 6
var aggressiveness_override: float = -1.0


func _init() -> void:
	patrol_waypoints = []


static func from_dict(data: Dictionary) -> NpcDirectiveState:
	var state := NpcDirectiveState.new()
	state.directive = int(data.get("directive", Directive.HOLD_PERIMETER))
	state.anchor_position = Utils.deserialize_position(data.get("anchor_position", { "x": 0, "y": 0 }))
	state.defend_position = Utils.deserialize_position(data.get("defend_position", { "x": 0, "y": 0 }))
	state.patrol_index = max(0, int(data.get("patrol_index", 0)))
	state.compact_radius = maxi(1, int(data.get("compact_radius", 4)))
	state.leash_radius = maxi(1, int(data.get("leash_radius", 6)))
	state.aggressiveness_override = float(data.get("aggressiveness_override", -1.0))

	state.patrol_waypoints.clear()
	for point_data in data.get("patrol_waypoints", []):
		state.patrol_waypoints.append(Utils.deserialize_position(point_data))

	if not state.patrol_waypoints.is_empty():
		state.patrol_index = posmod(state.patrol_index, state.patrol_waypoints.size())
	else:
		state.patrol_index = 0

	return state


func to_dict() -> Dictionary:
	var serialized_waypoints: Array[Dictionary] = []
	for point in patrol_waypoints:
		serialized_waypoints.append(Utils.serialize_position(point))

	return {
		"directive": directive,
		"anchor_position": Utils.serialize_position(anchor_position),
		"defend_position": Utils.serialize_position(defend_position),
		"patrol_waypoints": serialized_waypoints,
		"patrol_index": patrol_index,
		"compact_radius": compact_radius,
		"leash_radius": leash_radius,
		"aggressiveness_override": aggressiveness_override,
	}


func get_patrol_target() -> Vector2i:
	if patrol_waypoints.is_empty():
		return anchor_position
	return patrol_waypoints[patrol_index]


func advance_patrol() -> void:
	if patrol_waypoints.is_empty():
		return
	patrol_index = posmod(patrol_index + 1, patrol_waypoints.size())
