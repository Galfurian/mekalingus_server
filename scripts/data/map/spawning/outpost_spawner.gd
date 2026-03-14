class_name OutpostSpawner
extends RefCounted

const ZONE_IDS := ["nw", "ne", "sw", "se"]


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var outpost_type: String = str(request.get("outpost_type", "military"))
	var outpost_size: String = str(request.get("outpost_size", "small"))
	var add_defenses: bool = bool(request.get("outpost_add_defenses", true))
	var add_walls: bool = bool(request.get("outpost_add_walls", false))

	var zone_dimension: int = _get_zone_dimension(outpost_size)
	var footprint_radius: int = _get_footprint_radius(zone_dimension)

	var rng := RandomNumberGenerator.new()
	rng.seed = _build_outpost_seed(origin, outpost_type, outpost_size)

	var zone_slots: Dictionary = _build_zone_slots(origin, zone_dimension)
	var zone_specs: Dictionary = _build_zone_specs(outpost_type, add_defenses)
	var placements: Array[Dictionary] = _build_zone_placements(
		zone_slots,
		zone_specs,
		outpost_size,
		rng,
	)

	if placements.is_empty():
		push_error("Spawn failed: no outpost blueprint could be generated.")
		return

	_log_outpost_layout_preview(
		origin,
		footprint_radius,
		placements,
		add_walls,
	)

	var used_tiles: Array[Vector2i] = []
	for placement: Dictionary in placements:
		var tile: Vector2i = placement.get("tile", Vector2i(-1, -1))
		var entity_request: Dictionary = placement.get("entity", {})
		if tile == Vector2i(-1, -1) or entity_request.is_empty():
			continue
		if not _can_place_structure_tile(game_map, tile, used_tiles):
			continue

		used_tiles.append(tile)
		SingleEntitySpawner.spawn_structure(game_map, tile, entity_request, entity_owner)

	if add_walls:
		_spawn_perimeter(game_map, origin, footprint_radius, entity_owner, used_tiles)


static func _get_zone_dimension(outpost_size: String) -> int:
	match outpost_size:
		"small":
			return 2
		"medium":
			return 3
		"large":
			return 4
		_:
			return 2


static func _get_footprint_radius(zone_dimension: int) -> int:
	return zone_dimension * 2 + 1


static func _build_outpost_seed(
	origin: Vector2i,
	outpost_type: String,
	outpost_size: String,
) -> int:
	return hash("%d:%d:%s:%s" % [origin.x, origin.y, outpost_type, outpost_size])


static func _build_zone_slots(origin: Vector2i, zone_dimension: int) -> Dictionary:
	var north_axis: Array[int] = _build_axis_offsets(zone_dimension, false)
	var south_axis: Array[int] = _build_axis_offsets(zone_dimension, true)
	var west_axis: Array[int] = _build_axis_offsets(zone_dimension, false)
	var east_axis: Array[int] = _build_axis_offsets(zone_dimension, true)

	return {
		"nw": _build_zone_grid(origin, west_axis, north_axis),
		"ne": _build_zone_grid(origin, east_axis, north_axis),
		"sw": _build_zone_grid(origin, west_axis, south_axis),
		"se": _build_zone_grid(origin, east_axis, south_axis),
	}


static func _build_axis_offsets(zone_dimension: int, positive: bool) -> Array[int]:
	var offsets: Array[int] = []
	for i in range(zone_dimension):
		if positive:
			offsets.append(1 + i * 2)
		else:
			offsets.append(-1 - i * 2)
	return offsets


static func _build_zone_grid(
	origin: Vector2i,
	x_offsets: Array[int],
	y_offsets: Array[int],
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y_offset: int in y_offsets:
		for x_offset: int in x_offsets:
			tiles.append(Vector2i(origin.x + x_offset, origin.y + y_offset))
	return tiles


static func _build_zone_specs(outpost_type: String, add_defenses: bool) -> Dictionary:
	var default_specs: Dictionary = {
		"nw":
		{
			"role": "support",
			"type": "logistics",
			"subtypes": ["cache", "intel"],
			"doctrine":
			{
				"small": {"cache": 1, "intel": 1},
				"medium": {"cache": 2, "intel": 2},
				"large": {"cache": 3, "intel": 3},
			},
		},
		"ne":
		{
			"role": "production",
			"type": "production",
			"subtypes": ["fabrication", "munitions", "energy"],
			"doctrine":
			{
				"small": {"fabrication": 1, "munitions": 1},
				"medium": {"fabrication": 2, "munitions": 1, "energy": 1},
				"large": {"fabrication": 3, "munitions": 2, "energy": 1},
			},
		},
		"sw":
		{
			"role": "production",
			"type": "extraction",
			"subtypes": ["drilling", "refining", "surveying"],
			"doctrine":
			{
				"small": {"drilling": 1, "refining": 1},
				"medium": {"drilling": 2, "refining": 1, "surveying": 1},
				"large": {"drilling": 3, "refining": 2, "surveying": 2},
			},
		},
		"se":
		{
			"role": "production",
			"type": "production",
			"subtypes": ["assembly", "fabrication", "energy"],
			"doctrine":
			{
				"small": {"assembly": 1, "fabrication": 1},
				"medium": {"assembly": 2, "fabrication": 1, "energy": 1},
				"large": {"assembly": 3, "fabrication": 2, "energy": 1},
			},
		},
	}

	match outpost_type:
		"military":
			default_specs["nw"] = {
				"role": "support",
				"type": "logistics",
				"subtypes": ["cache", "intel"],
				"doctrine":
				{
					"small": {"cache": 1, "intel": 1},
					"medium": {"cache": 2, "intel": 2},
					"large": {"cache": 3, "intel": 3},
				},
			}
			default_specs["ne"] = {
				"role": "production",
				"type": "production",
				"subtypes": ["munitions", "energy", "fabrication"],
				"doctrine":
				{
					"small": {"munitions": 1, "energy": 1},
					"medium": {"munitions": 2, "energy": 1, "fabrication": 1},
					"large": {"munitions": 3, "energy": 2, "fabrication": 1},
				},
			}
			default_specs["sw"] = {
				"role": "production",
				"type": "extraction",
				"subtypes": ["refining", "drilling", "surveying"],
				"doctrine":
				{
					"small": {"drilling": 1, "refining": 1},
					"medium": {"drilling": 2, "refining": 1, "surveying": 1},
					"large": {"drilling": 3, "refining": 2, "surveying": 2},
				},
			}
			default_specs["se"] = {
				"role": "production",
				"type": "production",
				"subtypes": ["assembly", "fabrication", "munitions"],
				"doctrine":
				{
					"small": {"assembly": 1, "fabrication": 1},
					"medium": {"assembly": 2, "fabrication": 1, "munitions": 1},
					"large": {"assembly": 3, "fabrication": 2, "munitions": 1},
				},
			}
		"industrial":
			default_specs["nw"] = {
				"role": "production",
				"type": "extraction",
				"subtypes": ["drilling", "refining", "surveying"],
				"doctrine":
				{
					"small": {"drilling": 1, "surveying": 1},
					"medium": {"drilling": 2, "surveying": 1, "refining": 1},
					"large": {"drilling": 3, "surveying": 2, "refining": 2},
				},
			}
			default_specs["ne"] = {
				"role": "production",
				"type": "production",
				"subtypes": ["fabrication", "energy", "assembly"],
				"doctrine":
				{
					"small": {"fabrication": 1, "energy": 1},
					"medium": {"fabrication": 2, "energy": 1, "assembly": 1},
					"large": {"fabrication": 3, "energy": 2, "assembly": 1},
				},
			}
			default_specs["sw"] = {
				"role": "production",
				"type": "production",
				"subtypes": ["munitions", "assembly", "fabrication"],
				"doctrine":
				{
					"small": {"assembly": 1, "munitions": 1},
					"medium": {"assembly": 2, "munitions": 1, "fabrication": 1},
					"large": {"assembly": 3, "munitions": 2, "fabrication": 1},
				},
			}
			default_specs["se"] = {
				"role": "support",
				"type": "logistics",
				"subtypes": ["intel", "cache"],
				"doctrine":
				{
					"small": {"intel": 1, "cache": 1},
					"medium": {"intel": 2, "cache": 2},
					"large": {"intel": 3, "cache": 3},
				},
			}
		"salvage":
			default_specs["nw"] = {
				"role": "production",
				"type": "extraction",
				"subtypes": ["salvaging", "surveying", "drilling"],
				"doctrine":
				{
					"small": {"salvaging": 1, "surveying": 1},
					"medium": {"salvaging": 2, "surveying": 1, "drilling": 1},
					"large": {"salvaging": 3, "surveying": 2, "drilling": 2},
				},
			}
			default_specs["ne"] = {
				"role": "support",
				"type": "logistics",
				"subtypes": ["intel", "cache"],
				"doctrine":
				{
					"small": {"intel": 1, "cache": 1},
					"medium": {"intel": 2, "cache": 2},
					"large": {"intel": 3, "cache": 3},
				},
			}
			default_specs["sw"] = {
				"role": "production",
				"type": "production",
				"subtypes": ["assembly", "fabrication", "energy"],
				"doctrine":
				{
					"small": {"assembly": 1, "energy": 1},
					"medium": {"assembly": 2, "energy": 1, "fabrication": 1},
					"large": {"assembly": 3, "energy": 2, "fabrication": 1},
				},
			}
			default_specs["se"] = {
				"role": "production",
				"type": "extraction",
				"subtypes": ["salvaging", "refining"],
				"doctrine":
				{
					"small": {"salvaging": 1, "refining": 1},
					"medium": {"salvaging": 2, "refining": 1, "drilling": 1},
					"large": {"salvaging": 3, "refining": 2, "drilling": 1},
				},
			}

	if add_defenses:
		default_specs["ne"] = {
			"role": "defense",
			"type": "defense",
			"subtypes": ["tower", "turret"],
			"doctrine":
			{
				"small": {"tower": 1, "turret": 2},
				"medium": {"tower": 2, "turret": 3},
				"large": {"tower": 3, "turret": 5},
			},
		}

	return default_specs


static func _build_zone_placements(
	zone_slots: Dictionary,
	zone_specs: Dictionary,
	outpost_size: String,
	rng: RandomNumberGenerator,
) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []

	for zone_id: String in ZONE_IDS:
		var slots: Array[Vector2i] = zone_slots.get(zone_id, [])
		if slots.is_empty():
			continue

		var spec: Dictionary = zone_specs.get(zone_id, {})
		if spec.is_empty():
			continue

		var structure_type: String = str(spec.get("type", ""))
		var subtypes: Array = spec.get("subtypes", [])
		var templates_by_subtype: Dictionary = _collect_templates_by_subtype(
			structure_type,
			subtypes,
		)
		var pooled_template_ids: Array[String] = _flatten_template_map(templates_by_subtype)
		if pooled_template_ids.is_empty():
			continue

		var template_plan: Array[String] = _build_zone_template_plan(
			spec,
			outpost_size,
			slots.size(),
			templates_by_subtype,
			pooled_template_ids,
			rng,
		)
		if template_plan.is_empty():
			continue

		var selected_tiles: Array[Vector2i] = _select_zone_tiles(slots, template_plan.size(), rng)
		if selected_tiles.is_empty():
			continue

		for index in range(selected_tiles.size()):
			var template_id: String = template_plan[index % template_plan.size()]
			var entity_request: Dictionary = {
				"entity_type": "structure",
				"template_id": template_id,
				"loadout": _loadout_for_structure_type(structure_type),
			}
			placements.append({"tile": selected_tiles[index], "entity": entity_request})

	return placements


static func _collect_structure_templates(
	structure_type: String,
	structure_subtypes: Array,
) -> Array[String]:
	var ids: Array[String] = []
	for subtype_value in structure_subtypes:
		var subtype: String = str(subtype_value)
		ids += SingleEntitySpawner.get_structure_template_ids_by_type(structure_type, subtype)

	if ids.is_empty():
		ids = SingleEntitySpawner.get_structure_template_ids_by_type(structure_type)

	return _dedupe_ids(ids)


static func _collect_templates_by_subtype(
	structure_type: String,
	structure_subtypes: Array,
) -> Dictionary:
	var templates_by_subtype: Dictionary = {}
	for subtype_value in structure_subtypes:
		var subtype: String = str(subtype_value)
		var ids: Array[String] = (
			SingleEntitySpawner
			. get_structure_template_ids_by_type(
				structure_type,
				subtype,
			)
		)
		templates_by_subtype[subtype] = _dedupe_ids(ids)
	return templates_by_subtype


static func _flatten_template_map(templates_by_subtype: Dictionary) -> Array[String]:
	var pooled: Array[String] = []
	for ids in templates_by_subtype.values():
		pooled += ids
	return _dedupe_ids(pooled)


static func _build_zone_template_plan(
	spec: Dictionary,
	outpost_size: String,
	zone_capacity: int,
	templates_by_subtype: Dictionary,
	pooled_template_ids: Array[String],
	rng: RandomNumberGenerator,
) -> Array[String]:
	var plan: Array[String] = []
	var doctrine_by_size: Dictionary = spec.get("doctrine", {})
	var doctrine: Dictionary = doctrine_by_size.get(outpost_size, {})

	for subtype in doctrine.keys():
		var ids: Array[String] = []
		var raw_ids: Variant = templates_by_subtype.get(str(subtype), null)
		if raw_ids is Array:
			for entry in raw_ids:
				ids.append(str(entry))
		if ids.is_empty():
			continue

		var amount: int = int(doctrine[subtype])
		for index in range(max(0, amount)):
			plan.append(_pick_template_id(ids, index, rng))

	if plan.is_empty():
		var role: String = str(spec.get("role", "support"))
		var fallback_count: int = _zone_target_count(outpost_size, role, zone_capacity)
		for index in range(fallback_count):
			plan.append(_pick_template_id(pooled_template_ids, index, rng))

	if plan.size() > zone_capacity:
		plan.resize(zone_capacity)

	if plan.is_empty() and not pooled_template_ids.is_empty():
		plan.append(_pick_template_id(pooled_template_ids, 0, rng))

	return plan


static func _log_outpost_layout_preview(
	origin: Vector2i,
	footprint_radius: int,
	placements: Array[Dictionary],
	add_walls: bool,
) -> void:
	var occupied: Dictionary = {}
	for placement: Dictionary in placements:
		var tile: Vector2i = placement.get("tile", Vector2i(-1, -1))
		var entity_request: Dictionary = placement.get("entity", {})
		if tile == Vector2i(-1, -1) or entity_request.is_empty():
			continue
		var key := "%d:%d" % [tile.x, tile.y]
		occupied[key] = _structure_symbol_for_template(str(entity_request.get("template_id", "")))

	var lines: PackedStringArray = []
	for y in range(origin.y - footprint_radius, origin.y + footprint_radius + 1):
		var line := ""
		for x in range(origin.x - footprint_radius, origin.x + footprint_radius + 1):
			var tile := Vector2i(x, y)
			var tile_key := "%d:%d" % [tile.x, tile.y]

			if tile == origin:
				line += "+"
				continue

			if occupied.has(tile_key):
				line += str(occupied[tile_key])
				continue

			if add_walls and _is_perimeter_tile(origin, tile, footprint_radius + 1):
				line += "W"
				continue

			line += "."
		lines.append(line)

	GameServer.log_message("Outpost layout preview:\n" + "\n".join(lines))


static func _structure_symbol_for_template(template_id: String) -> String:
	var template: StructureTemplate = TemplateManager.get_structure_template(template_id)
	if not template:
		return "B"

	if template.structure_type == "defense":
		if template.structure_sub_type == "wall":
			return "W"
		if template.structure_sub_type == "gate":
			return "G"
		return "T"
	if template.structure_type == "extraction":
		return "E"
	if template.structure_type == "logistics":
		return "L"
	if template.structure_type == "production":
		return "P"
	return "B"


static func _is_perimeter_tile(origin: Vector2i, tile: Vector2i, radius: int) -> bool:
	if abs(tile.x - origin.x) == radius and abs(tile.y - origin.y) <= radius:
		return true
	if abs(tile.y - origin.y) == radius and abs(tile.x - origin.x) <= radius:
		return true
	return false


static func _dedupe_ids(ids: Array[String]) -> Array[String]:
	var unique_ids: Array[String] = []
	var seen: Dictionary = {}
	for id: String in ids:
		if seen.has(id):
			continue
		seen[id] = true
		unique_ids.append(id)
	return unique_ids


static func _zone_target_count(outpost_size: String, role: String, zone_capacity: int) -> int:
	var per_size_map: Dictionary = {
		"small":
		{
			"defense": 3,
			"production": 2,
			"support": 2,
		},
		"medium":
		{
			"defense": 5,
			"production": 4,
			"support": 4,
		},
		"large":
		{
			"defense": 8,
			"production": 7,
			"support": 6,
		},
	}
	var size_targets: Dictionary = per_size_map.get(outpost_size, per_size_map["small"])
	var raw_target: int = int(size_targets.get(role, size_targets.get("support", 2)))
	return clamp(raw_target, 1, zone_capacity)


static func _select_zone_tiles(
	slots: Array[Vector2i],
	target_count: int,
	rng: RandomNumberGenerator,
) -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	if target_count <= 0 or slots.is_empty():
		return selected

	for index in range(slots.size()):
		if selected.size() >= target_count:
			break

		var remaining_slots: int = slots.size() - index
		var remaining_needed: int = target_count - selected.size()
		if remaining_needed >= remaining_slots:
			selected.append(slots[index])
			continue

		var chance_to_place: float = float(remaining_needed) / float(remaining_slots)
		if rng.randf() <= chance_to_place:
			selected.append(slots[index])

	return selected


static func _pick_template_id(
	template_ids: Array[String],
	index: int,
	rng: RandomNumberGenerator,
) -> String:
	if template_ids.is_empty():
		return ""
	var offset: int = rng.randi_range(0, template_ids.size() - 1)
	return template_ids[(index + offset) % template_ids.size()]


static func _loadout_for_structure_type(structure_type: String) -> String:
	if structure_type == "defense":
		return "preset_defense"
	return "preset_utility"


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


static func _can_place_structure_tile(
	game_map: GameMap,
	tile: Vector2i,
	used_tiles: Array[Vector2i],
) -> bool:
	if not game_map.is_in_bounds(tile):
		return false
	if not game_map.is_walkable(tile) or game_map.is_occupied(tile):
		return false
	if tile in used_tiles:
		return false
	return true


static func _spawn_perimeter(
	game_map: GameMap,
	origin: Vector2i,
	radius: int,
	entity_owner: EntityOwner,
	used_tiles: Array[Vector2i]
) -> void:
	var wall_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type(
		"defense", "wall"
	)
	var gate_ids: Array[String] = SingleEntitySpawner.get_structure_template_ids_by_type(
		"defense", "gate"
	)
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
			game_map, tile, {"template_id": template_id, "loadout": "none"}, entity_owner
		)
