extends Node

# The size of sectors.
const SECTOR_SIZE: int = 10
const LEFT_PANEL_RATIO: float = 0.2
const MENU_DELETE_ENTITY: int = 1
const MENU_SPAWN_NPC_MEK: int = 2
const MENU_SPAWN_STRUCTURE_BASE: int = 1000

# The current game map.
var game_map: GameMap
# The current grid size (in pixels).
var grid_size: int
# The currently selected entity.
var selected_entity: MapEntity
var _context_cell: Vector2i = Vector2i(-1, -1)
var _structure_spawn_actions: Dictionary[int, String] = {}

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
	_structure_spawn_actions.clear()

	action_menu.clear()
	if entity_at_cell:
		action_menu.add_item("Delete Entity", MENU_DELETE_ENTITY)
	else:
		action_menu.add_item("Spawn NPC Mek", MENU_SPAWN_NPC_MEK)
		_add_structure_spawn_items()

	action_menu.position = Vector2i(mouse_position)
	action_menu.reset_size()
	action_menu.popup()


func _on_action_menu_id_pressed(action_id: int) -> void:
	if not game_map or _context_cell.x < 0 or _context_cell.y < 0:
		return

	match action_id:
		MENU_DELETE_ENTITY:
			_delete_entity_at_context_cell()
		MENU_SPAWN_NPC_MEK:
			_spawn_npc_mek_at_context_cell()
		_:
			if _structure_spawn_actions.has(action_id):
				_spawn_structure_at_context_cell(_structure_spawn_actions[action_id])

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


func _spawn_npc_mek_at_context_cell() -> void:
	if not game_map.can_move_to(_context_cell):
		return

	var clans: Array = DataManager.clans.values()
	if clans.is_empty():
		push_error("Cannot spawn NPC Mek: no clans loaded.")
		return

	var clan: Clan = clans.pick_random()
	var preferred_roles: Array = clan.preferred_roles if clan and clan.preferred_roles else []
	var role: Enums.MekRole = Enums.MekRole.BRAWLER
	if not preferred_roles.is_empty():
		role = preferred_roles.pick_random()

	var mek: Mek = LoadoutGenerator.generate_mek(game_map.map_difficulty, role)
	if not mek:
		push_error("Cannot spawn NPC Mek: loadout generation failed.")
		return

	var npc_owner: NPCOwned = NPCOwned.new(NameGenerator.random_full_name(), clan)
	var map_mek: MapMek = MapMek.new(_context_cell, npc_owner, mek)
	game_map.npc_units[mek.uuid] = map_mek

	_refresh_entity_views()


func _spawn_structure_at_context_cell(template_id: String) -> void:
	if game_map.is_occupied(_context_cell):
		return

	var clans: Array = DataManager.clans.values()
	if clans.is_empty():
		push_error("Cannot spawn turret: no clans loaded.")
		return

	var clan: Clan = clans.pick_random()
	var template: StructureTemplate = TemplateManager.get_structure_template(template_id)
	if not template:
		push_error("Cannot spawn structure: missing structure template '%s'." % template_id)
		return

	var structure: Structure = template.build_structure()
	if not structure:
		push_error("Cannot spawn structure: failed to build structure actor.")
		return

	if template.slots.size() > 0 and template.slots[Enums.SlotType.SMALL] > 0:
		var item_template: ItemTemplate = TemplateManager.get_item_template("swpn001")
		if item_template:
			structure.items.append(item_template.build_item())
			structure.rebuild_combat_state()

	var npc_owner: NPCOwned = NPCOwned.new(template.structure_name, clan)
	var map_structure: MapStructure = MapStructure.new(_context_cell, npc_owner, structure, true)
	game_map.structures[structure.uuid] = map_structure

	_refresh_entity_views()


func _add_structure_spawn_items() -> void:
	var template_ids: Array[String] = []
	for template_id: String in TemplateManager.structure_templates.keys():
		template_ids.append(template_id)
	template_ids.sort()

	if template_ids.is_empty():
		action_menu.add_separator()
		action_menu.add_item("No Structures Available", MENU_SPAWN_STRUCTURE_BASE)
		action_menu.set_item_disabled(action_menu.item_count - 1, true)
		return

	action_menu.add_separator()
	for index in range(template_ids.size()):
		var template_id: String = template_ids[index]
		var template: StructureTemplate = TemplateManager.get_structure_template(template_id)
		if not template:
			continue
		var action_id: int = MENU_SPAWN_STRUCTURE_BASE + index
		_structure_spawn_actions[action_id] = template_id
		action_menu.add_item("Spawn Structure: %s" % template.structure_name, action_id)


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
