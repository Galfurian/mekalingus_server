extends Node

signal entity_selected(entity: MapEntity)

var game_map: GameMap

@onready var mek_tree = $TabContainer/Meks/MekTree


func setup(p_game_map: GameMap) -> void:
	clear()
	game_map = p_game_map
	if game_map and not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	if not mek_tree.item_selected.is_connected(_on_mek_tree_item_selected):
		mek_tree.item_selected.connect(_on_mek_tree_item_selected)
	refresh()


func clear() -> void:
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	game_map = null
	if mek_tree:
		mek_tree.clear()


func refresh() -> void:
	if not game_map:
		return
	_populate_meks_tree()


func select_entity(entity: MapEntity) -> void:
	if not mek_tree:
		return
	mek_tree.deselect_all()
	if not is_instance_of(entity, MapCombatEntity):
		return
	var root = mek_tree.get_root()
	if not root:
		return
	var target = _find_item_by_uuid(root, entity.combatant.uuid)
	if target:
		target.select(0)
		mek_tree.scroll_to_item(target)


func _on_turn_ended(_turn_number: int) -> void:
	refresh()


func _populate_meks_tree() -> void:
	mek_tree.clear()
	var root = mek_tree.create_item()

	var clans: Dictionary = {}
	for map_mek in game_map.player_units.values():
		_add_mek_to_clan_bucket(clans, map_mek)
	for map_mek in game_map.npc_units.values():
		_add_mek_to_clan_bucket(clans, map_mek)

	var clan_names = clans.keys()
	clan_names.sort()

	for clan_name in clan_names:
		var clan_data: Dictionary = clans[clan_name]
		var clan_item = mek_tree.create_item(root)
		clan_item.set_text(0, clan_name)
		clan_item.set_selectable(0, false)
		clan_item.set_custom_color(0, clan_data["color"])

		var meks: Array = clan_data["entities"]
		meks.sort_custom(func(a: MapCombatEntity, b: MapCombatEntity): return _combatant_display_name(a.combatant) < _combatant_display_name(b.combatant))
		for map_mek: MapCombatEntity in meks:
			var mek_item = mek_tree.create_item(clan_item)
			mek_item.set_text(0, _format_mek_label(map_mek))
			mek_item.set_metadata(0, map_mek.combatant.uuid)
			mek_item.set_custom_color(0, clan_data["color"])


func _add_mek_to_clan_bucket(clans: Dictionary, map_mek: MapCombatEntity) -> void:
	if not is_instance_valid(map_mek) or not map_mek.owner:
		return
	var clan_name = "No Clan"
	var clan_color = Color.WHITE
	if map_mek.owner.clan:
		clan_name = map_mek.owner.clan.clan_name
		clan_color = map_mek.owner.clan.color
	if not clans.has(clan_name):
		clans[clan_name] = {
			"color": clan_color,
			"entities": []
		}
	clans[clan_name]["entities"].append(map_mek)


func _format_mek_label(map_mek: MapCombatEntity) -> String:
	var owner_label = ""
	if is_instance_of(map_mek.owner, PlayerOwned):
		owner_label = "Player: " + map_mek.owner.player.player_name
	elif is_instance_of(map_mek.owner, NPCOwned):
		owner_label = "NPC: " + map_mek.owner.npc_name
	else:
		owner_label = "Unknown Owner"
	return "%s  [%s, %s]" % [_combatant_display_name(map_mek.combatant), owner_label, str(map_mek.position)]


func _combatant_display_name(combatant: CombatActor) -> String:
	if combatant == null:
		return "Unknown"
	if combatant.has_method("get_mek_name"):
		return str(combatant.call("get_mek_name"))
	if combatant.has_method("get_structure_name"):
		return str(combatant.call("get_structure_name"))
	if not combatant.alias.is_empty():
		return combatant.alias
	return combatant.uuid


func _on_mek_tree_item_selected() -> void:
	if not game_map:
		return
	var selected_item = mek_tree.get_selected()
	if not selected_item:
		return
	var metadata = selected_item.get_metadata(0)
	if not (metadata is String):
		return
	var entity = game_map.get_entity(metadata)
	if entity:
		entity_selected.emit(entity)


func _find_item_by_uuid(parent: TreeItem, uuid: String) -> TreeItem:
	var child = parent.get_first_child()
	while child:
		var metadata = child.get_metadata(0)
		if metadata is String and metadata == uuid:
			return child
		var nested = _find_item_by_uuid(child, uuid)
		if nested:
			return nested
		child = child.get_next()
	return null
