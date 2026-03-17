class_name SquadSpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var squad_mode: String = str(request.get("squad_mode", "manual"))
	var units: Array = request.get("units", [])
	if squad_mode == "budget":
		units = _build_budget_squad(request)
		if units.is_empty():
			push_error("Spawn failed: unable to build a squad for the selected budget.")
			return

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

		var remaining: int = count - targets.size()
		var take_count: int = mini(remaining, ring.size())
		for index in range(take_count):
			var ring_index: int = int(floor(float(index) * ring.size() / take_count))
			targets.append(ring[ring_index])
			if targets.size() >= count:
				break

		ring_radius += 1

	return targets


static func _build_budget_squad(request: Dictionary) -> Array[Dictionary]:
	var requested_count: int = max(1, int(request.get("squad_count", 4)))
	var remaining_budget: float = max(1.0, float(request.get("squad_power_budget", 900)))
	var loadout: String = str(request.get("squad_loadout", "preset_balanced"))
	var allowed_sizes_raw: Array = request.get("squad_allowed_sizes", [])
	var allowed_sizes: Array[int] = []
	for size_name in allowed_sizes_raw:
		var enum_value: Variant = Utils.string_to_enum(Enums.EntitySize, str(size_name))
		if enum_value != null:
			allowed_sizes.append(int(enum_value))

	var candidates: Array[Dictionary] = []
	for template_id: String in TemplateManager.mek_templates.keys():
		var template: MekTemplate = TemplateManager.mek_templates[template_id]
		if not template:
			continue
		if not allowed_sizes.is_empty() and not template.size in allowed_sizes:
			continue
		candidates.append({
			"template_id": template_id,
			"power": template.evaluate_mek_template_power(),
			"size": template.size,
		})

	if candidates.is_empty():
		return []

	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		return float(a["power"]) < float(b["power"])
	)

	var units: Array[Dictionary] = []
	for index in range(requested_count):
		var slots_left: int = requested_count - index
		var target_power: float = remaining_budget / slots_left
		var selected: Dictionary = _pick_budget_candidate(candidates, target_power, remaining_budget)
		if selected.is_empty():
			break
		units.append({
			"entity_type": "mek",
			"template_id": str(selected["template_id"]),
			"loadout": loadout,
		})
		remaining_budget = max(0.0, remaining_budget - float(selected["power"]))

	return units


static func _pick_budget_candidate(
	candidates: Array[Dictionary],
	target_power: float,
	remaining_budget: float
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	for candidate: Dictionary in candidates:
		var power: float = float(candidate["power"])
		var overshoot_penalty: float = max(0.0, power - remaining_budget) * 4.0
		var distance_penalty: float = abs(power - target_power)
		var randomness: float = randf() * 8.0
		var score: float = overshoot_penalty + distance_penalty + randomness
		if score < best_score:
			best = candidate
			best_score = score
	return best
