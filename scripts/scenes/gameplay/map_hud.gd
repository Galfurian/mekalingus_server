extends Node

# The size of sectors.
const SECTOR_SIZE: int = 10
const LEFT_PANEL_RATIO: float = 0.2
const MENU_DELETE_ENTITY: int = 1
const MENU_OPEN_SPAWN_PANEL: int = 2

# The current game map.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The currently selected entity.
var selected_entity: MapEntity
var _context_cell: Vector2i = Vector2i(-1, -1)

@onready var action_menu = $ActionMenu
@onready var main_split = $RootSplit/MainSplit
@onready var scroll_view = $RootSplit/MainSplit/GridMap/ScrollView
@onready var grid_container = $RootSplit/MainSplit/GridMap/ScrollView/GridContainer
@onready var grid_drawer = $RootSplit/MainSplit/GridMap/ScrollView/GridContainer/GridDrawer
@onready var icon_drawer = $RootSplit/MainSplit/GridMap/ScrollView/GridContainer/IconDrawer
@onready var time_of_day_overlay = $RootSplit/MainSplit/GridMap/ScrollView/GridContainer/TimeOfDayOverlay
@onready var combat_log = $RootSplit/LogPanel/TabContainer/CombatLog/ScrollContainer/CombatLog
@onready var info_panel = $RootSplit/MainSplit/LeftSidePanel/InfoPanel
@onready var entity_list_panel = $RootSplit/MainSplit/LeftSidePanel/EntityListPanel
@onready var log_panel = $RootSplit/LogPanel
@onready var time_label = $RootSplit/MainSplit/GridMap/TimeLabel
@onready var spawn_panel = $SpawnPanel

func _ready():
	"""Initializes the map HUD."""
	grid_container.on_cell_selected.connect(_on_cell_selected)
	grid_container.on_cell_context_requested.connect(_on_cell_context_requested)
	combat_log.meta_clicked.connect(_on_log_meta_clicked)
	scroll_view.scrolled.connect(_on_map_scrolled)
	if not entity_list_panel.entity_selected.is_connected(_on_entity_list_entity_selected):
		entity_list_panel.entity_selected.connect(_on_entity_list_entity_selected)
	if not action_menu.id_pressed.is_connected(_on_action_menu_id_pressed):
		action_menu.id_pressed.connect(_on_action_menu_id_pressed)
	if not spawn_panel.spawn_requested.is_connected(_on_spawn_panel_spawn_requested):
		spawn_panel.spawn_requested.connect(_on_spawn_panel_spawn_requested)


func setup(p_game_map: GameMap, p_grid_size: int = 50):
	"""Sets up the map HUD with the given game map and grid size."""
	clear()
	# Set the variables.
	game_map = p_game_map
	grid_size = p_grid_size
	# Initialize all components with the chosen grid size
	time_of_day_overlay.setup(p_game_map, grid_size, SECTOR_SIZE)
	grid_container.setup(p_game_map, grid_size, SECTOR_SIZE)
	grid_drawer.setup(p_game_map, grid_size, SECTOR_SIZE)
	icon_drawer.setup(p_game_map, grid_size, SECTOR_SIZE)
	info_panel.setup(p_game_map)
	entity_list_panel.setup(p_game_map)
	log_panel.setup(p_game_map)
	# Connect signals once.
	if game_map and not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	# Update the time of day based on the current turn.
	_update_time_of_day()
	# Center the view on the map.
	zoom_out()


func clear():
	"""Clears the map HUD."""
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)
	game_map = null
	selected_entity = null
	# Clear the sub-components.
	time_of_day_overlay.clear()
	grid_container.clear()
	grid_drawer.clear()
	icon_drawer.clear()
	info_panel.clear()
	entity_list_panel.clear()
	log_panel.clear()


func redraw(p_grid_size: int):
	"""Redraws the map HUD with a new grid size."""
	if not game_map:
		return
	# Update the grid size.
	grid_size = p_grid_size
	# Re-setup all components with the new grid size.
	time_of_day_overlay.setup(game_map, grid_size, SECTOR_SIZE)
	grid_container.setup(game_map, grid_size, SECTOR_SIZE)
	grid_drawer.setup(game_map, grid_size, SECTOR_SIZE)
	icon_drawer.setup(game_map, grid_size, SECTOR_SIZE)


func center_on(position: Vector2i) -> void:
	"""Centers the scroll view on the given tile position."""
	if not game_map:
		return
	# Convert tile coordinates to pixel coordinates.
	var tile_pixel_pos = (position + Vector2i(SECTOR_SIZE, SECTOR_SIZE)) * grid_size
	# Get the size of the scroll viewport (i.e., the visible area).
	var visible_size = scroll_view.get_size()
	# Center position = move the scroll so the position is in the center of the screen.
	var scroll_x = tile_pixel_pos.x - (visible_size.x / 2.) + (grid_size / 2.)
	var scroll_y = tile_pixel_pos.y - (visible_size.y / 2.) + (grid_size / 2.)
	# Compute the maximum scroll limits to prevent scrolling out of bounds.
	var max_scroll_x = (game_map.map_width + SECTOR_SIZE * 2) * grid_size - visible_size.x
	var max_scroll_y = (game_map.map_height + SECTOR_SIZE * 2) * grid_size - visible_size.y
	# Apply clamped scrolling.
	scroll_view.scroll_horizontal = clamp(scroll_x, 0, max_scroll_x)
	scroll_view.scroll_vertical = clamp(scroll_y, 0, max_scroll_y)


func zoom_out():
	"""Zooms out the map view."""
	if not game_map:
		return

	# Get the visible scroll area size.
	var visible_size = scroll_view.get_size()

	# Compute minimum grid size needed to fit the full map (including padding).
	var total_tiles_x = game_map.map_width + SECTOR_SIZE
	var total_tiles_y = game_map.map_height + SECTOR_SIZE
	var min_grid_size_x = visible_size.x / total_tiles_x
	var min_grid_size_y = visible_size.y / total_tiles_y

	# Take the smaller of the two to ensure full fit.
	var min_grid_size = min(min_grid_size_x, min_grid_size_y)
	grid_size = max(1, floor(min_grid_size))

	# Center the scroll view on the map.
	scroll_view.scroll_horizontal = (SECTOR_SIZE * grid_size) / 2.0
	scroll_view.scroll_vertical = (SECTOR_SIZE * grid_size) / 2.0
	
	# Redraw with the new grid size.
	redraw(grid_size)


func _on_turn_ended(_turn_number: int):
	# Called when the turn ends
	if selected_entity:
		center_on(selected_entity.position)
	entity_list_panel.refresh()
	# Update the time of day based on the current turn.
	_update_time_of_day()


func _update_time_of_day() -> void:
	if not game_map:
		return
	# Get the current time of day from the game map.
	var time_of_day = game_map.turn_manager.get_time_of_day()
	# Convert to HH:MM style time (e.g., 0.25 = 06:00)
	var hours = int(time_of_day * 24.0)
	var minutes = int(int(time_of_day * 1440) % 60)
	# Update the label
	time_label.text = "%02d:%02d" % [hours, minutes]


func _on_log_meta_clicked(meta: String) -> void:
	"""Handles meta clicks in the combat log."""
	# Handle item link: item:<mek_uuid>:<item_uuid>
	if meta.begins_with("item:"):
		var parts = meta.substr(5).split(":")
		if parts.size() != 2:
			printerr("Invalid item meta format: ", meta)
			return
		var mek_uuid = parts[0]
		var item_uuid = parts[1]
		var entity = game_map.get_entity(mek_uuid)
		if entity and is_instance_of(entity, MapMek):
			selected_entity = entity
			center_on(entity.position)
			info_panel.set_entity(entity)
			entity_list_panel.select_entity(entity)
			info_panel.select_item_by_uuid(item_uuid)
			grid_drawer.set_selected_entity(entity)
		else:
			printerr("Could not find valid Mek entity for item link: ", meta)
	# Handle Mek link: mek:<mek_uuid>
	elif meta.begins_with("mek:"):
		var mek_uuid = meta.substr(4)
		var entity = game_map.get_entity(mek_uuid)
		if entity and is_instance_of(entity, MapMek):
			selected_entity = entity
			center_on(entity.position)
			info_panel.set_entity(entity)
			entity_list_panel.select_entity(entity)
			grid_drawer.set_selected_entity(entity)
		else:
			printerr("Could not find valid Mek entity for mek link: ", meta)
	elif meta.begins_with("pos:"):
		var coord_text = meta.substr(4)
		var coords = coord_text.split(",")
		if coords.size() != 2:
			printerr("Invalid position meta format: ", meta)
			return
		var x = int(coords[0])
		var y = int(coords[1])
		var target_pos = Vector2i(x, y)
		if game_map.is_in_bounds(target_pos):
			center_on(target_pos)
		else:
			printerr("Position out of bounds: ", target_pos)
	else:
		printerr("Unknown meta clicked: ", meta)


func _on_cell_selected(cell_position: Vector2i):
	"""Handles cell selection and updates the UnitInfoPanel."""
	# Get the entity at the given position.
	var entity = game_map.get_entity_at(cell_position)
	if entity:
		selected_entity = entity
		center_on(entity.position)
		info_panel.set_entity(entity)
		entity_list_panel.select_entity(entity)
		grid_drawer.set_selected_entity(entity)


func _on_entity_list_entity_selected(entity: MapEntity) -> void:
	if not is_instance_valid(entity):
		return
	selected_entity = entity
	center_on(entity.position)
	info_panel.set_entity(entity)
	grid_drawer.set_selected_entity(entity)


func _on_cell_context_requested(cell_position: Vector2i, mouse_position: Vector2) -> void:
	if not game_map:
		return

	_context_cell = cell_position
	var entity_at_cell: MapEntity = game_map.get_entity_at(cell_position)

	action_menu.clear()
	if entity_at_cell:
		action_menu.add_item("Delete Entity", MENU_DELETE_ENTITY)
	else:
		action_menu.add_item("Spawn...", MENU_OPEN_SPAWN_PANEL)

	action_menu.position = Vector2i(mouse_position)
	action_menu.reset_size()
	action_menu.popup()


func _on_action_menu_id_pressed(action_id: int) -> void:
	if not game_map or _context_cell.x < 0 or _context_cell.y < 0:
		return

	match action_id:
		MENU_DELETE_ENTITY:
			_delete_entity_at_context_cell()
		MENU_OPEN_SPAWN_PANEL:
			_open_spawn_panel_for_context_cell()

	_context_cell = Vector2i(-1, -1)


func _delete_entity_at_context_cell() -> void:
	var entity: MapEntity = game_map.get_entity_at(_context_cell)
	if not entity:
		return

	game_map.remove_map_entity(entity)
	if selected_entity == entity:
		selected_entity = null
		info_panel.clear()
		grid_drawer.deselect_entity()

	_refresh_entity_views()


func _open_spawn_panel_for_context_cell() -> void:
	if not game_map:
		return

	var default_clan_id: String = ""
	var default_owner: EntityOwner = null
	if selected_entity and selected_entity.owner and selected_entity.owner.clan:
		default_clan_id = selected_entity.owner.clan.id
		default_owner = selected_entity.owner

	spawn_panel.open_for_cell(_context_cell, game_map, default_clan_id, default_owner)


func _on_spawn_panel_spawn_requested(request: Dictionary) -> void:
	if not game_map:
		return

	var origin: Vector2i = request.get("position", _context_cell)
	var spawn_mode: String = str(request.get("spawn_mode", "single"))
	match spawn_mode:
		"single":
			_spawn_single(request, origin)
		"squad", "outpost":
			_spawn_multi(request, origin)

	_refresh_entity_views()


func _spawn_single(request: Dictionary, origin: Vector2i) -> void:
	var entity_type: String = str(request.get("entity_type", ""))
	var quantity: int = int(request.get("quantity", 1))
	var spawn_tiles: Array[Vector2i] = _find_spawn_tiles(origin, quantity, entity_type)
	if spawn_tiles.is_empty():
		push_error("Spawn failed: no valid tiles available.")
		return

	for i in range(spawn_tiles.size()):
		var entity_owner: EntityOwner = _build_owner_from_request(request, i)
		if not entity_owner:
			push_error("Spawn failed: invalid owner configuration.")
			return
		if entity_type == "mek":
			_spawn_mek(spawn_tiles[i], request, entity_owner)
		elif entity_type == "structure":
			_spawn_structure(spawn_tiles[i], request, entity_owner)


func _spawn_multi(request: Dictionary, origin: Vector2i) -> void:
	# All units in a squad / outpost share the same commander.
	var entity_owner: EntityOwner = _build_owner_from_request(request, 0)
	if not entity_owner:
		push_error("Spawn failed: invalid owner configuration.")
		return

	var units: Array = request.get("units", [])
	var used_tiles: Array[Vector2i] = []
	for unit: Dictionary in units:
		var entity_type: String = str(unit.get("entity_type", "mek"))
		var tile: Vector2i = _find_nearest_free_tile(origin, entity_type, used_tiles)
		if tile == Vector2i(-1, -1):
			push_warning("Spawn skipped: no available tile for a unit.")
			continue
		used_tiles.append(tile)
		var unit_request: Dictionary = {
			"template_id": str(unit.get("template_id", "")),
			"loadout": str(unit.get("loadout", "none")),
		}
		if entity_type == "mek":
			_spawn_mek(tile, unit_request, entity_owner)
		elif entity_type == "structure":
			_spawn_structure(tile, unit_request, entity_owner)


## Returns single closest free tile from origin (excluding already-claimed tiles).
func _find_nearest_free_tile(
	origin: Vector2i,
	entity_type: String,
	excluded: Array[Vector2i] = []
) -> Vector2i:
	if _can_spawn_entity_type_at(origin, entity_type) and not origin in excluded:
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
				if _can_spawn_entity_type_at(tile, entity_type):
					return tile
	return Vector2i(-1, -1)


## Returns up to `quantity` spawn tiles for a single entity type, avoiding duplicates.
func _find_spawn_tiles(origin: Vector2i, quantity: int, entity_type: String) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for _i in range(quantity):
		var tile: Vector2i = _find_nearest_free_tile(origin, entity_type, tiles)
		if tile == Vector2i(-1, -1):
			break
		tiles.append(tile)
	return tiles


func _can_spawn_entity_type_at(position: Vector2i, entity_type: String) -> bool:
	if not game_map.is_in_bounds(position):
		return false
	if entity_type == "mek":
		return game_map.can_move_to(position)
	if entity_type == "structure":
		return game_map.is_walkable(position) and not game_map.is_occupied(position)
	return false


func _build_owner_from_request(request: Dictionary, index: int) -> EntityOwner:
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
	return NPCOwned.new(base_name, clan)


func _spawn_mek(position: Vector2i, request: Dictionary, entity_owner: EntityOwner) -> void:
	var template_id: String = str(request.get("template_id", ""))
	var template: MekTemplate = TemplateManager.get_mek_template(template_id)
	if not template:
		push_error("Spawn failed: unknown Mek template '%s'." % template_id)
		return

	var mek: Mek = template.build_mek()
	if str(request.get("loadout", "")) == "random":
		_apply_random_loadout(mek)
	var map_mek: MapMek = MapMek.new(position, entity_owner, mek)
	if entity_owner.is_player():
		game_map.player_units[mek.uuid] = map_mek
	else:
		game_map.npc_units[mek.uuid] = map_mek


func _spawn_structure(position: Vector2i, request: Dictionary, entity_owner: EntityOwner) -> void:
	var template_id: String = str(request.get("template_id", ""))
	var template: StructureTemplate = TemplateManager.get_structure_template(template_id)
	if not template:
		push_error("Spawn failed: unknown Structure template '%s'." % template_id)
		return

	var structure: Structure = template.build_structure()
	if str(request.get("loadout", "")) == "random":
		_apply_random_loadout(structure)
	var map_structure: MapStructure = MapStructure.new(position, entity_owner, structure, true)
	game_map.structures[structure.uuid] = map_structure


func _apply_random_loadout(actor: CombatActor) -> void:
	# Fill available slots with shuffled random items; largest slots first so
	# high-power items get a chance before the power budget shrinks.
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
		var candidates: Array[ItemTemplate] = []
		for tmpl: ItemTemplate in TemplateManager.item_templates.values():
			if tmpl.slot == slot_type:
				candidates.append(tmpl)
		candidates.shuffle()
		var fill: int = mini(slots_available, candidates.size())
		for i in range(fill):
			actor.items.append(candidates[i].build_item())
	actor.rebuild_combat_state()


func _refresh_entity_views() -> void:
	icon_drawer.update_icons()
	grid_drawer.queue_redraw()
	entity_list_panel.refresh()


func _on_map_scrolled(scroll_up: bool):
	"""Handles map scrolling and zooming."""
	if not game_map:
		return
	# Store previous grid size before updating.
	var old_grid_size = grid_size
	# Get the size of the scroll viewport (i.e., visible area)
	var visible_size = scroll_view.get_size()
	# Full number of tiles that need to be visible, including sector borders
	var total_tiles_x = game_map.map_width + SECTOR_SIZE * 2
	var total_tiles_y = game_map.map_height + SECTOR_SIZE * 2
	# Compute the minimum grid size that would fit the entire map (including sectors)
	var min_grid_size_x = visible_size.x / total_tiles_x
	var min_grid_size_y = visible_size.y / total_tiles_y
	# Prevent grid from being too small.
	var min_grid_size = max(4, min(min_grid_size_x, min_grid_size_y))
	# Compute the maximum grid size for deep zoom in
	var max_grid_size_x = visible_size.x / 5 # e.g., show only ~5 tiles max when zoomed in
	var max_grid_size_y = visible_size.y / 5
	var max_grid_size = min(max_grid_size_x, max_grid_size_y)
	# Adjust the grid size within allowed range
	if scroll_up and grid_size < max_grid_size:
		grid_size += 2
	elif not scroll_up and grid_size > min_grid_size:
		grid_size -= 2
	else:
		return # No change needed
	# Get mouse position inside the ScrollContainer.
	var mouse_pos = scroll_view.get_local_mouse_position()
	# Store previous scroll positions.
	var old_scroll_h = scroll_view.scroll_horizontal
	var old_scroll_v = scroll_view.scroll_vertical
	# Apply the new zoom level to the map.
	redraw(grid_size)
	# Adjust scrolling to keep the zoom centered on the mouse position.
	var scale_factor = float(grid_size) / float(old_grid_size)
	scroll_view.scroll_horizontal = int(
		old_scroll_h * scale_factor + mouse_pos.x * (scale_factor - 1)
	)
	scroll_view.scroll_vertical = int(
		old_scroll_v * scale_factor + mouse_pos.y * (scale_factor - 1)
	)
