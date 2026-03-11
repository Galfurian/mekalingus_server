class_name OutpostSpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var outpost_type: String = str(request.get("outpost_type", "military"))
	var outpost_size: String = str(request.get("outpost_size", "small"))
	var add_defenses: bool = bool(request.get("outpost_add_defenses", true))
	var add_walls: bool = bool(request.get("outpost_add_walls", false))

	var blueprint: Array[Dictionary] = _build_outpost_blueprint(outpost_type, outpost_size, add_defenses)
	if blueprint.is_empty():
		push_error("Spawn failed: no outpost blueprint could be generated.")
		return

	var used_tiles: Array[Vector2i] = []
	for unit: Dictionary in blueprint:
		var entity_type: String = str(unit.get("entity_type", "structure"))
		var tile: Vector2i = SingleEntitySpawner.find_nearest_free_tile(
			game_map,
			origin,
			entity_type,
			used_tiles
		)
		if tile == Vector2i(-1, -1):
			continue
		used_tiles.append(tile)
		if entity_type == "mek":
			SingleEntitySpawner.spawn_mek(game_map, tile, unit, entity_owner)
		elif entity_type == "structure":
			SingleEntitySpawner.spawn_structure(game_map, tile, unit, entity_owner)

	if add_walls:
		_spawn_perimeter(game_map, origin, outpost_size, entity_owner, used_tiles)


static func _build_outpost_blueprint(
	outpost_type: String,
	outpost_size: String,
	add_defenses: bool
) -> Array[Dictionary]:
	var core_count_map: Dictionary = {
		"small": 2,
		"medium": 4,
		"large": 6,
	}
	var defense_count_map: Dictionary = {
		"small": 1,
		"medium": 2,
		"large": 3,
	}
	var core_count: int = int(core_count_map.get(outpost_size, 2))
	var defense_count: int = int(defense_count_map.get(outpost_size, 1))

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

	var primary_templates: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type(primary_structure_type)
	if primary_templates.is_empty():
		primary_templates = SingleEntitySpawner.get_structure_template_ids_by_type("extraction")
	if primary_templates.is_empty():
		primary_templates = SingleEntitySpawner.get_structure_template_ids_by_type("combat")

	var blueprint: Array[Dictionary] = []
	for _i in range(core_count):
		var template_id: String = SingleEntitySpawner.pick_random_id(primary_templates)
		if template_id.is_empty():
			continue
		blueprint.append({
			"entity_type": "structure",
			"template_id": template_id,
			"loadout": "preset_utility",
		})

	if add_defenses:
		var defense_templates: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type("defense")
		if defense_templates.is_empty():
			defense_templates = SingleEntitySpawner.get_structure_template_ids_by_type("combat")
		for _j in range(defense_count):
			var defense_id: String = SingleEntitySpawner.pick_random_id(defense_templates)
			if defense_id.is_empty():
				continue
			blueprint.append({
				"entity_type": "structure",
				"template_id": defense_id,
				"loadout": "preset_offense",
			})

	return blueprint


static func _spawn_perimeter(
	game_map: GameMap,
	origin: Vector2i,
	outpost_size: String,
	entity_owner: EntityOwner,
	used_tiles: Array[Vector2i]
) -> void:
	var radius_map: Dictionary = {
		"small": 2,
		"medium": 3,
		"large": 4,
	}
	var radius: int = int(radius_map.get(outpost_size, 2))

	var wall_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type("wall")
	var gate_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type("gate")
	if wall_ids.is_empty() and gate_ids.is_empty():
		return

	var perimeter: Array[Vector2i] = []
	for x in range(origin.x - radius, origin.x + radius + 1):
		perimeter.append(Vector2i(x, origin.y - radius))
		perimeter.append(Vector2i(x, origin.y + radius))
	for y in range(origin.y - radius + 1, origin.y + radius):
		perimeter.append(Vector2i(origin.x - radius, y))
		perimeter.append(Vector2i(origin.x + radius, y))

	var gate_candidates: Array[Vector2i] = [
		Vector2i(origin.x, origin.y - radius),
		Vector2i(origin.x, origin.y + radius),
	]

	for tile: Vector2i in perimeter:
		if tile in used_tiles:
			continue
		if not game_map.is_in_bounds(tile):
			continue
		if game_map.is_occupied(tile):
			continue

		var use_gate: bool = tile in gate_candidates and not gate_ids.is_empty()
		var template_id: String = SingleEntitySpawner.pick_random_id(gate_ids if use_gate else wall_ids)
		if template_id.is_empty():
			continue

		used_tiles.append(tile)
		SingleEntitySpawner.spawn_structure(
			game_map,
			tile,
			{ "template_id": template_id, "loadout": "none" },
			entity_owner
		)
