class_name SquadSpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_owner: EntityOwner = SingleEntitySpawner.build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var units: Array = request.get("units", [])
	var used_tiles: Array[Vector2i] = []
	for unit: Dictionary in units:
		var entity_type: String = str(unit.get("entity_type", "mek"))
		var tile: Vector2i = SingleEntitySpawner.find_nearest_free_tile(
			game_map,
			origin,
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
