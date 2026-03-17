class_name DirectivePlanner
extends RefCounted


var game_map: GameMap


func _init(p_game_map: GameMap) -> void:
	game_map = p_game_map


func get_owner_directive_by_key(
	owner_key: String,
	fallback_anchor: Vector2i = Vector2i(-1, -1)
) -> RefCounted:
	if owner_key.is_empty():
		return null

	if game_map.owner_directives.has(owner_key):
		return game_map.owner_directives[owner_key]

	var state: RefCounted = NpcDirectiveState.new()
	state.directive = NpcDirectiveState.Directive.HOLD_PERIMETER
	state.anchor_position = _compute_owner_anchor(owner_key)
	if state.anchor_position == Vector2i.ZERO and fallback_anchor != Vector2i(-1, -1):
		state.anchor_position = fallback_anchor
	state.patrol_waypoints = _build_patrol_waypoints(
		state.anchor_position,
		state.leash_radius,
		state.patrol_type
	)
	game_map.owner_directives[owner_key] = state
	return state


func set_owner_directive_by_key(owner_key: String, directive: int) -> void:
	if owner_key.is_empty():
		return
	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return
	state.directive = directive
	game_map.owner_directives[owner_key] = state


func reset_owner_anchor(owner_key: String) -> void:
	if owner_key.is_empty():
		return

	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return

	var new_anchor: Vector2i = _compute_owner_anchor(owner_key)
	if new_anchor == Vector2i.ZERO:
		return

	state.anchor_position = new_anchor
	state.patrol_waypoints = _build_patrol_waypoints(
		new_anchor,
		state.leash_radius,
		state.patrol_type
	)
	state.patrol_index = 0
	game_map.owner_directives[owner_key] = state


func refresh_owner_patrol_waypoints(owner_key: String) -> void:
	if owner_key.is_empty():
		return

	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return

	state.patrol_waypoints = _build_patrol_waypoints(
		state.anchor_position,
		state.leash_radius,
		state.patrol_type
	)
	state.patrol_index = 0
	game_map.owner_directives[owner_key] = state


func set_owner_anchor(owner_key: String, anchor: Vector2i, rebuild_patrol: bool = true) -> void:
	if owner_key.is_empty() or not game_map.is_in_bounds(anchor):
		return

	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return

	state.anchor_position = anchor
	if rebuild_patrol:
		state.patrol_waypoints = _build_patrol_waypoints(
			anchor,
			state.leash_radius,
			state.patrol_type
		)
		state.patrol_index = 0
	game_map.owner_directives[owner_key] = state


func set_owner_anchor_from_centroid(owner_key: String) -> void:
	if owner_key.is_empty():
		return

	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return

	var centroid: Vector2i = _compute_owner_anchor(owner_key)
	if centroid == Vector2i.ZERO:
		return

	state.anchor_position = centroid
	game_map.owner_directives[owner_key] = state


func auto_generate_owner_patrol_ring_from_centroid(owner_key: String) -> void:
	if owner_key.is_empty():
		return

	var state: RefCounted = get_owner_directive_by_key(owner_key)
	if not state:
		return

	var centroid: Vector2i = _compute_owner_anchor(owner_key)
	if centroid == Vector2i.ZERO:
		return

	state.anchor_position = centroid
	state.patrol_type = NpcDirectiveState.PatrolType.CIRCLE
	state.patrol_waypoints = _build_patrol_waypoints(
		centroid,
		state.leash_radius,
		state.patrol_type
	)
	state.patrol_index = 0
	game_map.owner_directives[owner_key] = state


func clear_all_owner_directives() -> void:
	game_map.owner_directives.clear()


func advance_patrol_directives() -> void:
	for owner_key in game_map.get_owner_keys(true):
		var state: RefCounted = get_owner_directive_by_key(owner_key)
		if not state or state.directive != NpcDirectiveState.Directive.PATROL:
			continue

		var entities: Array[MapCombatEntity] = game_map.get_owned_combat_entities_by_key(owner_key)
		if entities.is_empty():
			continue

		var center: Vector2i = _compute_owner_anchor(owner_key)
		var patrol_target: Vector2i = state.get_patrol_target()
		if center.distance_to(patrol_target) <= 2.0:
			state.advance_patrol()
			game_map.owner_directives[owner_key] = state


func _compute_owner_anchor(owner_key: String) -> Vector2i:
	var entities: Array[MapCombatEntity] = game_map.get_owned_combat_entities_by_key(owner_key)
	if entities.is_empty():
		return Vector2i.ZERO

	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y

	return Vector2i(
		int(round(float(sum_x) / entities.size())),
		int(round(float(sum_y) / entities.size())),
	)


func _build_patrol_waypoints(
	anchor: Vector2i,
	leash_radius: int,
	patrol_type: int
) -> Array[Vector2i]:
	match patrol_type:
		NpcDirectiveState.PatrolType.SQUARE:
			return _build_square_patrol_waypoints(anchor, leash_radius)
		NpcDirectiveState.PatrolType.MAP_BORDER:
			return _build_border_patrol_waypoints(anchor, leash_radius)
		_:
			return _build_circle_patrol_waypoints(anchor, leash_radius)


func _build_circle_patrol_waypoints(anchor: Vector2i, leash_radius: int) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if anchor == Vector2i.ZERO:
		return waypoints

	var patrol_radius_x: int = maxi(1, leash_radius)
	var patrol_radius_y: int = maxi(1, leash_radius)
	var diagonal_x: int = maxi(1, int(round(patrol_radius_x * 0.7)))
	var diagonal_y: int = maxi(1, int(round(patrol_radius_y * 0.7)))
	var candidates: Array[Vector2i] = [
		anchor + Vector2i(0, -patrol_radius_y),
		anchor + Vector2i(diagonal_x, -diagonal_y),
		anchor + Vector2i(patrol_radius_x, 0),
		anchor + Vector2i(diagonal_x, diagonal_y),
		anchor + Vector2i(0, patrol_radius_y),
		anchor + Vector2i(-diagonal_x, diagonal_y),
		anchor + Vector2i(-patrol_radius_x, 0),
		anchor + Vector2i(-diagonal_x, -diagonal_y),
	]

	for point in candidates:
		if game_map.is_in_bounds(point):
			waypoints.append(point)

	if waypoints.is_empty():
		waypoints.append(anchor)

	return waypoints


func _build_square_patrol_waypoints(anchor: Vector2i, half_side: int) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if anchor == Vector2i.ZERO:
		return waypoints

	var r: int = maxi(1, half_side)
	var candidates: Array[Vector2i] = [
		anchor + Vector2i(0, -r),
		anchor + Vector2i(r, -r),
		anchor + Vector2i(r, 0),
		anchor + Vector2i(r, r),
		anchor + Vector2i(0, r),
		anchor + Vector2i(-r, r),
		anchor + Vector2i(-r, 0),
		anchor + Vector2i(-r, -r),
	]

	for point in candidates:
		if game_map.is_in_bounds(point):
			waypoints.append(point)

	if waypoints.is_empty():
		waypoints.append(anchor)

	return waypoints


func _build_border_patrol_waypoints(anchor: Vector2i, padding: int = 0) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if game_map.map_width <= 0 or game_map.map_height <= 0:
		return waypoints

	var max_padding: int = maxi(
		0,
		int(mini(game_map.map_width, game_map.map_height) * 0.5) - 1
	)
	var pad: int = clampi(padding, 0, max_padding)
	var corners: Array[Vector2i] = [
		Vector2i(pad, pad),
		Vector2i(game_map.map_width - 1 - pad, pad),
		Vector2i(game_map.map_width - 1 - pad, game_map.map_height - 1 - pad),
		Vector2i(pad, game_map.map_height - 1 - pad),
	]

	var start_index: int = 0
	var best_distance: float = INF
	for i in range(corners.size()):
		var distance: float = corners[i].distance_to(anchor)
		if distance < best_distance:
			best_distance = distance
			start_index = i

	for i in range(corners.size()):
		var waypoint: Vector2i = corners[(start_index + i) % corners.size()]
		if not waypoints.has(waypoint):
			waypoints.append(waypoint)

	if waypoints.is_empty():
		waypoints.append(anchor)

	return waypoints
