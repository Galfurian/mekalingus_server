extends Node

signal entity_selected(entity: MapEntity)

var game_map: GameMap

@onready var all_tree: Tree = $TabContainer/All/AllTree
@onready var mek_tree: Tree = $TabContainer/Meks/MekTree
@onready var structure_tree: Tree = $TabContainer/Structures/StructureTree
@onready var loot_tree: Tree = $TabContainer/Loot/LootTree


func setup(p_game_map: GameMap) -> void:
	clear()
	game_map = p_game_map
	if game_map and not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	_connect_tree_signals()
	refresh()


func clear() -> void:
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	game_map = null
	if all_tree:
		all_tree.clear()
	if mek_tree:
		mek_tree.clear()
	if structure_tree:
		structure_tree.clear()
	if loot_tree:
		loot_tree.clear()


func refresh() -> void:
	if not game_map:
		return
	_populate_all_trees()


func select_entity(entity: MapEntity) -> void:
	if not entity:
		return

	for tree: Tree in _all_trees():
		tree.deselect_all()
		var root: TreeItem = tree.get_root()
		if not root:
			continue
		var target: TreeItem = _find_item_by_entity(root, entity)
		if target:
			target.select(0)
			tree.scroll_to_item(target)


func _on_turn_ended(_turn_number: int) -> void:
	refresh()


func _all_trees() -> Array[Tree]:
	return [all_tree, mek_tree, structure_tree, loot_tree]


func _connect_tree_signals() -> void:
	if not all_tree.item_selected.is_connected(_on_all_tree_item_selected):
		all_tree.item_selected.connect(_on_all_tree_item_selected)
	if not mek_tree.item_selected.is_connected(_on_mek_tree_item_selected):
		mek_tree.item_selected.connect(_on_mek_tree_item_selected)
	if not structure_tree.item_selected.is_connected(_on_structure_tree_item_selected):
		structure_tree.item_selected.connect(_on_structure_tree_item_selected)
	if not loot_tree.item_selected.is_connected(_on_loot_tree_item_selected):
		loot_tree.item_selected.connect(_on_loot_tree_item_selected)


func _populate_all_trees() -> void:
	var all_entities: Array[MapEntity] = []
	var mek_entities: Array[MapEntity] = []
	var structure_entities: Array[MapEntity] = []
	var loot_entities: Array[MapEntity] = []

	for entity: MapCombatEntity in game_map.player_units.values():
		if entity and entity.active:
			all_entities.append(entity)
			if is_instance_of(entity, MapMek):
				mek_entities.append(entity)

	for entity: MapCombatEntity in game_map.npc_units.values():
		if entity and entity.active:
			all_entities.append(entity)
			if is_instance_of(entity, MapMek):
				mek_entities.append(entity)

	for entity: MapStructure in game_map.structures.values():
		if entity and entity.active:
			all_entities.append(entity)
			structure_entities.append(entity)

	for entity: MapPickup in game_map.pickups.values():
		if entity and entity.active:
			all_entities.append(entity)
			loot_entities.append(entity)

	_populate_tree(all_tree, all_entities)
	_populate_tree(mek_tree, mek_entities)
	_populate_tree(structure_tree, structure_entities)
	_populate_tree(loot_tree, loot_entities)


func _populate_tree(tree: Tree, entities: Array[MapEntity]) -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	if entities.is_empty():
		return

	var grouped_entities: Dictionary[String, Array] = {}
	var group_labels: Dictionary[String, String] = {}

	for entity: MapEntity in entities:
		var owner_key: String = _owner_group_key(entity)
		if not grouped_entities.has(owner_key):
			grouped_entities[owner_key] = []
			group_labels[owner_key] = _owner_label(entity)
		grouped_entities[owner_key].append(entity)

	var owner_keys: Array[String] = grouped_entities.keys()
	owner_keys.sort_custom(func(a: String, b: String):
		return group_labels[a].to_lower() < group_labels[b].to_lower()
	)

	for owner_key in owner_keys:
		var group_item: TreeItem = tree.create_item(root)
		group_item.set_text(0, group_labels[owner_key])
		group_item.set_custom_color(0, _owner_color(grouped_entities[owner_key][0]))

		var group_entities: Array[MapEntity] = grouped_entities[owner_key]
		group_entities.sort_custom(func(a: MapEntity, b: MapEntity):
			return _entity_sort_label(a) < _entity_sort_label(b)
		)

		for entity: MapEntity in group_entities:
			var item: TreeItem = tree.create_item(group_item)
			item.set_text(0, _entity_child_label(entity))
			item.set_metadata(0, entity)
			item.set_custom_color(0, _owner_color(entity))


func _owner_group_key(entity: MapEntity) -> String:
	if not entity or not entity.owner:
		return "none"
	if game_map:
		var owner_key: String = game_map.get_owner_key(entity.owner)
		if not owner_key.is_empty():
			return owner_key
	return _owner_label(entity)


func _entity_child_label(entity: MapEntity) -> String:
	var name_label: String = _entity_name(entity)
	return "%s  [%s]" % [name_label, str(entity.position)]


func _owner_color(entity: MapEntity) -> Color:
	if entity and entity.owner and entity.owner.clan:
		return entity.owner.clan.color
	return Color.WHITE


func _entity_sort_label(entity: MapEntity) -> String:
	var owner_label: String = _owner_label(entity)
	var name_label: String = _entity_name(entity)
	return "%s  [%s, %s]" % [name_label, owner_label, str(entity.position)]


func _owner_label(entity: MapEntity) -> String:
	if is_instance_of(entity.owner, PlayerOwned):
		return "Player: " + entity.owner.player.player_name
	if is_instance_of(entity.owner, NPCOwned):
		return "NPC: " + entity.owner.npc_name
	return "No Owner"


func _entity_name(entity: MapEntity) -> String:
	if is_instance_of(entity, MapPickup):
		if entity.item_data.has("item_id"):
			return "Loot: " + str(entity.item_data["item_id"])
		return "Loot"

	if is_instance_of(entity, MapCombatEntity):
		return _combatant_display_name(entity.combatant)

	return "Entity"


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


func _on_all_tree_item_selected() -> void:
	_emit_selected_from_tree(all_tree)


func _on_mek_tree_item_selected() -> void:
	_emit_selected_from_tree(mek_tree)


func _on_structure_tree_item_selected() -> void:
	_emit_selected_from_tree(structure_tree)


func _on_loot_tree_item_selected() -> void:
	_emit_selected_from_tree(loot_tree)


func _emit_selected_from_tree(tree: Tree) -> void:
	if not game_map:
		return
	var selected_item: TreeItem = tree.get_selected()
	if not selected_item:
		return
	var metadata: Variant = selected_item.get_metadata(0)
	if not is_instance_of(metadata, MapEntity):
		return
	entity_selected.emit(metadata)


func _find_item_by_entity(parent: TreeItem, entity: MapEntity) -> TreeItem:
	var child: TreeItem = parent.get_first_child()
	while child:
		var metadata: Variant = child.get_metadata(0)
		if is_instance_of(metadata, MapEntity) and metadata == entity:
			return child
		var nested: TreeItem = _find_item_by_entity(child, entity)
		if nested:
			return nested
		child = child.get_next()
	return null
