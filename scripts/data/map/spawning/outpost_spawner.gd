class_name OutpostSpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var outpost_type: String = str(request.get("outpost_type", "military"))
	var outpost_size: String = str(request.get("outpost_size", "small"))
	var spread: int = max(1, int(request.get("outpost_spread", 2)))
	var add_defenses: bool = bool(request.get("outpost_add_defenses", true))
	var add_walls: bool = bool(request.get("outpost_add_walls", false))
	var require_clearance: bool = bool(request.get("outpost_require_clearance", false))
	if outpost_type == "military":
		require_clearance = false

	var blueprint: Dictionary = _build_outpost_blueprint(outpost_type, outpost_size, add_defenses)
	var core_units: Array[Dictionary] = blueprint.get("core_units", [])
	var defense_units: Array[Dictionary] = blueprint.get("defense_units", [])
	if core_units.is_empty() and defense_units.is_empty():
		push_error("Spawn failed: no outpost blueprint could be generated.")
		return

	var footprint_radius: int = _get_footprint_radius(outpost_size, spread)
	var used_tiles: Array[Vector2i] = []

	var core_targets: Array[Vector2i] = _build_core_targets(origin, core_units.size(), footprint_radius)
	for index in range(core_units.size()):
		var tile: Vector2i = _find_structure_tile_near_target(
			game_map,
			core_targets[index],
			used_tiles,
			1 if require_clearance else 0,
			footprint_radius + 2
		)
		if tile == Vector2i(-1, -1):
			continue
		used_tiles.append(tile)
		SingleEntitySpawner.spawn_structure(game_map, tile, core_units[index], entity_owner)

	if not defense_units.is_empty():
		var defense_targets: Array[Vector2i] = _build_defense_targets(
			origin,
			defense_units.size(),
			footprint_radius
		)
		for index in range(defense_units.size()):
			var tile: Vector2i = _find_structure_tile_near_target(
				game_map,
				defense_targets[index],
				used_tiles,
				0,
				2
			)
			if tile == Vector2i(-1, -1):
				continue
			used_tiles.append(tile)
			SingleEntitySpawner.spawn_structure(game_map, tile, defense_units[index], entity_owner)

	if add_walls:
		_spawn_perimeter(game_map, origin, footprint_radius + 1, entity_owner, used_tiles)


static func _build_outpost_blueprint(
	outpost_type: String,
	outpost_size: String,
	add_defenses: bool
) -> Dictionary:
	var core_count_map: Dictionary = {
		"small": 2,
		"medium": 4,
		"large": 6,
	}
	var defense_count_map: Dictionary = {
		"small": 2,
		"medium": 4,
		"large": 6,
	}
	var core_count: int = int(core_count_map.get(outpost_size, 2))
	var defense_count: int = int(defense_count_map.get(outpost_size, 2))

	var primary_structure_type: String = "combat"
	match outpost_type:
		"industrial":
			primary_structure_type = "extraction"
		"salvage":
			primary_structure_type = "loot"
		"hunting":
			primary_structure_type = "hunting"
		_:
			primary_structure_type = "combat"

	var primary_templates: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type(
		primary_structure_type
	)
	if primary_templates.is_empty():
		primary_templates = SingleEntitySpawner.get_structure_template_ids_by_type("extraction")
	if primary_templates.is_empty():
		primary_templates = SingleEntitySpawner.get_structure_template_ids_by_type("combat")

	var core_units: Array[Dictionary] = []
	for _i in range(core_count):
		var template_id: String = SingleEntitySpawner.pick_random_id(primary_templates)
		if template_id.is_empty():
			continue
		core_units.append({
			"entity_type": "structure",
			"template_id": template_id,
			"loadout": "preset_utility",
		})

	var defense_units: Array[Dictionary] = []
	if add_defenses:
		var defense_templates: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type(
			"defense"
		)
		if defense_templates.is_empty():
			defense_templates = SingleEntitySpawner.get_structure_template_ids_by_type("combat")
		for _j in range(defense_count):
			var defense_id: String = SingleEntitySpawner.pick_random_id(defense_templates)
			if defense_id.is_empty():
				continue
			defense_units.append({
				"entity_type": "structure",
				"template_id": defense_id,
				"loadout": "preset_offense",
			})

	return {
		"core_units": core_units,
		"defense_units": defense_units,
	}


static func _get_footprint_radius(outpost_size: String, spread: int) -> int:
	var base_radius_map: Dictionary = {
		"small": 2,
		"medium": 3,
		"large": 4,
	}
	return int(base_radius_map.get(outpost_size, 2)) + max(0, spread - 2)


static func _build_core_targets(
	origin: Vector2i,
	count: int,
	footprint_radius: int
) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if count <= 0:
		return targets

	var candidates: Array[Vector2i] = [origin]
	for radius in range(1, max(1, footprint_radius - 1) + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				candidates.append(Vector2i(x, y))

	while targets.size() < count and not candidates.is_empty():
		var remaining_targets: int = maxi(1, count - targets.size())
		var step: int = maxi(1, int(ceil(float(candidates.size()) / remaining_targets)))
		var index: int = mini(candidates.size() - 1, targets.size() * step)
		targets.append(candidates[index])
		candidates.remove_at(index)

	return targets


static func _build_defense_targets(
	origin: Vector2i,
	count: int,
	footprint_radius: int
) -> Array[Vector2i]:
	var perimeter: Array[Vector2i] = _build_perimeter_ring(origin, footprint_radius)
	var targets: Array[Vector2i] = []
	if count <= 0 or perimeter.is_empty():
		return targets

	for index in range(count):
		var perimeter_index: int = int(round(float(index) * perimeter.size() / count))
		perimeter_index %= perimeter.size()
		targets.append(perimeter[perimeter_index])
	return targets


static func _build_perimeter_ring(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for x in range(origin.x - radius, origin.x + radius + 1):
		ring.append(Vector2i(x, origin.y - radius))
	for y in range(origin.y - radius + 1, origin.y + radius + 1):
		ring.append(Vector2i(origin.x + radius, y))
	for x in range(origin.x + radius - 1, origin.x - radius - 1, -1):
		ring.append(Vector2i(x, origin.y + radius))
	for y in range(origin.y + radius - 1, origin.y - radius, -1):
		ring.append(Vector2i(origin.x - radius, y))
	return ring


static func _find_structure_tile_near_target(
	game_map: GameMap,
	target: Vector2i,
	used_tiles: Array[Vector2i],
	clearance_radius: int,
	search_radius: int
) -> Vector2i:
	for radius in range(0, search_radius + 1):
		for x in range(target.x - radius, target.x + radius + 1):
			for y in range(target.y - radius, target.y + radius + 1):
				if radius > 0 and abs(x - target.x) != radius and abs(y - target.y) != radius:
					continue
				var tile := Vector2i(x, y)
				if _can_place_structure_tile(game_map, tile, used_tiles, clearance_radius):
					return tile
	return Vector2i(-1, -1)


static func _can_place_structure_tile(
	game_map: GameMap,
	tile: Vector2i,
	used_tiles: Array[Vector2i],
	clearance_radius: int
) -> bool:
	if not game_map.is_in_bounds(tile):
		return false
	if not game_map.is_walkable(tile) or game_map.is_occupied(tile):
		return false
	if tile in used_tiles:
		return false

	if clearance_radius <= 0:
		return true

	for x in range(tile.x - clearance_radius, tile.x + clearance_radius + 1):
		for y in range(tile.y - clearance_radius, tile.y + clearance_radius + 1):
			var neighbor := Vector2i(x, y)
			if neighbor == tile:
				continue
			if not game_map.is_in_bounds(neighbor):
				continue
			if neighbor in used_tiles or game_map.is_occupied(neighbor):
				return false
	return true


static func _spawn_perimeter(
	game_map: GameMap,
	origin: Vector2i,
	radius: int,
	entity_owner: EntityOwner,
	used_tiles: Array[Vector2i]
) -> void:
	var wall_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type("wall")
	var gate_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type("gate")
	if wall_ids.is_empty() and gate_ids.is_empty():
		return

	var perimeter: Array[Vector2i] = _build_perimeter_ring(origin, radius)
	var gate_candidates: Array[Vector2i] = [
		Vector2i(origin.x, origin.y - radius),
		Vector2i(origin.x + radius, origin.y),
		Vector2i(origin.x, origin.y + radius),
		Vector2i(origin.x - radius, origin.y),
	]

	for tile: Vector2i in perimeter:
		if tile in used_tiles:
			continue
		if not game_map.is_in_bounds(tile) or game_map.is_occupied(tile):
			continue
		var use_gate: bool = tile in gate_candidates and not gate_ids.is_empty()
		var source_ids: Array[String] = gate_ids if use_gate else wall_ids
		var template_id: String = SingleEntitySpawner.pick_random_id(source_ids)
		if template_id.is_empty():
			continue
		used_tiles.append(tile)
		SingleEntitySpawner.spawn_structure(
			game_map,
			tile,
			{ "template_id": template_id, "loadout": "none" },
			entity_owner
		)
