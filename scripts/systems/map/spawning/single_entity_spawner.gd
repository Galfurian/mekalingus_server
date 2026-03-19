class_name SingleEntitySpawner
extends RefCounted


static func spawn(game_map: GameMap, origin: Vector2i, request: Dictionary) -> void:
	var entity_type: String = str(request.get("entity_type", ""))
	var quantity: int = int(request.get("quantity", 1))
	var spawn_tiles: Array[Vector2i] = find_spawn_tiles(game_map, origin, quantity, entity_type)
	if spawn_tiles.is_empty():
		push_error("Spawn failed: no valid tiles available.")
		return

	for index in range(spawn_tiles.size()):
		var entity_owner: EntityOwner = build_owner_from_request(request, index)
		if not entity_owner:
			push_error("Spawn failed: invalid owner configuration.")
			return
		if entity_type == "mek":
			spawn_mek(game_map, spawn_tiles[index], request, entity_owner)
		elif entity_type == "structure":
			spawn_structure(game_map, spawn_tiles[index], request, entity_owner)


static func find_nearest_free_tile(
	game_map: GameMap, origin: Vector2i, entity_type: String, excluded: Array[Vector2i] = []
) -> Vector2i:
	if can_spawn_entity_type_at(game_map, origin, entity_type) and not origin in excluded:
		return origin

	var max_radius: int = max(game_map.map_width, game_map.map_height)
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var tile := Vector2i(x, y)
				if tile in excluded:
					continue
				if can_spawn_entity_type_at(game_map, tile, entity_type):
					return tile
	return Vector2i(-1, -1)


static func find_spawn_tiles(
	game_map: GameMap, origin: Vector2i, quantity: int, entity_type: String
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for _i in range(quantity):
		var tile: Vector2i = find_nearest_free_tile(game_map, origin, entity_type, tiles)
		if tile == Vector2i(-1, -1):
			break
		tiles.append(tile)
	return tiles


static func can_spawn_entity_type_at(
	game_map: GameMap, position: Vector2i, entity_type: String
) -> bool:
	if not game_map.is_in_bounds(position):
		return false
	if entity_type == "mek":
		return game_map.can_move_to(position)
	if entity_type == "structure":
		return game_map.is_walkable(position) and not game_map.is_occupied(position)
	return false


static func build_owner_from_request(request: Dictionary, index: int) -> EntityOwner:
	var clan_id: String = str(request.get("clan_id", ""))
	var clan: Clan = DataManager.clans.get(clan_id, null)
	if not clan:
		return null

	var owner_type: String = str(request.get("owner_type", "npc"))
	if owner_type == "player":
		var player_uuid: String = str(request.get("player_uuid", ""))
		var player: Player = DataManager.find_player_by_uuid(player_uuid)
		if not player:
			return null
		return PlayerOwned.new(player, clan)

	var base_name: String = str(request.get("npc_name", "")).strip_edges()
	if base_name.is_empty():
		base_name = NameGenerator.random_full_name()
	var npc_mode: String = str(request.get("npc_mode", "new"))
	if npc_mode != "existing" and index > 0:
		base_name += " %d" % (index + 1)
	var npc_owner: NPCOwned = NPCOwned.new(base_name, clan)
	npc_owner.ai_profile_path = str(request.get("ai_profile_path", "")).strip_edges()
	return npc_owner


static func spawn_mek(
	game_map: GameMap,
	position: Vector2i,
	request: Dictionary,
	entity_owner: EntityOwner,
) -> void:
	var template_id: String = str(request.get("template_id", ""))
	var template: MekTemplate = TemplateManager.get_mek_template(template_id)
	if not template:
		push_error("Spawn failed: unknown Mek template '%s'." % template_id)
		return
	# Generate a UUID.
	var uuid: String = GameServer.generate_uuid()
	# Create the Mek.
	var mek: Mek = Mek.new(uuid, template_id, template)
	# Load the template data into the Mek instance.
	apply_random_loadout(mek, request.get("loadout", "none"))
	# Add the Mek to the map.
	var map_mek: MapMek = MapMek.new(position, entity_owner, mek)
	if entity_owner.is_player():
		game_map.player_units[mek.uuid] = map_mek
	else:
		game_map.npc_units[mek.uuid] = map_mek


static func spawn_structure(
	game_map: GameMap,
	position: Vector2i,
	request: Dictionary,
	entity_owner: EntityOwner,
) -> void:
	var template_id: String = str(request.get("template_id", ""))
	var template: StructureTemplate = TemplateManager.get_structure_template(template_id)
	if not template:
		push_error("Spawn failed: unknown Structure template '%s'." % template_id)
		return
	# Generate a UUID.
	var uuid: String = GameServer.generate_uuid()
	# Create the Structure.
	var structure: Structure = Structure.new(uuid, template_id, template)
	# Load the template data into the Structure instance.
	apply_random_loadout(structure, request.get("loadout", "none"))
	# Determine if the structure should be passable based on the template and any overrides in the
	# request.
	game_map.structures[structure.uuid] = MapStructure.new(position, entity_owner, structure)


static func apply_random_loadout(actor: CombatEntity, loadout: String = "preset_balanced") -> void:
	var preset: String = loadout
	if preset == "random":
		preset = "preset_balanced"

	var slot_priority: Array = [
		Enums.SlotType.LARGE,
		Enums.SlotType.MEDIUM,
		Enums.SlotType.SMALL,
		Enums.SlotType.UTILITY,
	]
	for slot_type: int in slot_priority:
		var slots_available: int = actor.slots[slot_type] if actor.slots.size() > slot_type else 0
		if slots_available <= 0:
			continue
		var weighted: Array[Dictionary] = []
		for tmpl: ItemTemplate in TemplateManager.item_templates.values():
			if tmpl.slot == slot_type:
				var weight: int = _preset_weight_for_item(tmpl, preset)
				weighted.append({"template": tmpl, "weight": weight + randi() % 3})
		weighted.sort_custom(
			func(a: Dictionary, b: Dictionary): return int(a["weight"]) > int(b["weight"])
		)
		var fill: int = mini(slots_available, weighted.size())
		for index in range(fill):
			actor.items.append(weighted[index]["template"].build_item())
	actor.rebuild_combat_state()


static func get_structure_template_ids_by_type(
	structure_type: String,
	structure_subtype: String = "",
) -> Array[String]:
	var ids: Array[String] = []
	for template_id: String in TemplateManager.structure_templates.keys():
		var template: StructureTemplate = TemplateManager.structure_templates[template_id]
		if template and template.structure_type == structure_type:
			if structure_subtype == "" or template.structure_sub_type == structure_subtype:
				ids.append(template_id)
	return ids


static func pick_random_id(ids: Array[String]) -> String:
	if ids.is_empty():
		return ""
	return ids[randi() % ids.size()]


static func _preset_weight_for_item(item_template: ItemTemplate, preset: String) -> int:
	if preset == "preset_balanced":
		return 10

	var offense: int = 0
	var defense: int = 0
	var utility: int = 0

	for module: ItemModule in item_template.modules:
		for effect: BaseEffect in module.effects:
			if effect.is_offensive():
				offense += 4
			elif effect.is_defensive():
				defense += 4
			elif effect.is_utility():
				utility += 4

	match preset:
		"preset_offense":
			return 1 + offense * 4 + defense + utility
		"preset_defense":
			return 1 + defense * 4 + offense + utility
		"preset_utility":
			return 1 + utility * 4 + offense + defense
		_:
			return 10
