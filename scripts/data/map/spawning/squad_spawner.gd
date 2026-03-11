class_name SquadSpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var units: Array = request.get("units", [])
	var spread: int = max(1, int(request.get("squad_spread", 2)))
	var targets: Array[Vector2i] = _build_formation_targets(origin, units.size(), spread)
	var used_tiles: Array[Vector2i] = []
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		var entity_type: String = str(unit.get("entity_type", "mek"))
		var tile: Vector2i = SingleEntitySpawner.find_nearest_free_tile(
			game_map,
			targets[index],
			entity_type,
			used_tiles
		)
		if tile == Vector2i(-1, -1):
			push_warning("Spawn skipped: no available tile for a unit.")
			continue
		used_tiles.append(tile)
		var unit_request: Dictionary = {
			"template_id": str(unit.get("template_id", "")),
			"loadout": str(unit.get("loadout", "none")),
		}
		if entity_type == "mek":
			SingleEntitySpawner.spawn_mek(game_map, tile, unit_request, entity_owner)
		elif entity_type == "structure":
			SingleEntitySpawner.spawn_structure(game_map, tile, unit_request, entity_owner)


static func _build_formation_targets(
	origin: Vector2i,
	count: int,
	spread: int
) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if count <= 0:
		return targets

	var ring_radius: int = max(1, spread)
	while targets.size() < count:
		var ring: Array[Vector2i] = []
		for x in range(origin.x - ring_radius, origin.x + ring_radius + 1):
			for y in range(origin.y - ring_radius, origin.y + ring_radius + 1):
				if abs(x - origin.x) != ring_radius and abs(y - origin.y) != ring_radius:
					continue
				ring.append(Vector2i(x, y))

		ring.sort_custom(func(a: Vector2i, b: Vector2i):
			var angle_a: float = atan2(float(a.y - origin.y), float(a.x - origin.x))
			var angle_b: float = atan2(float(b.y - origin.y), float(b.x - origin.x))
			return angle_a < angle_b
		)

		for tile: Vector2i in ring:
			targets.append(tile)
			if targets.size() >= count:
				break

		ring_radius += 1

	return targets
