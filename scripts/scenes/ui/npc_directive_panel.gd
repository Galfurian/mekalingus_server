extends VBoxContainer

signal directives_changed(game_map: GameMap)
signal ai_overlay_toggled(enabled: bool)
signal anchor_pick_mode_changed(enabled: bool)

const DEFAULT_AI_OVERLAY_ENABLED: bool = false

@onready var owner_option: OptionButton = $TabContainer/Directive/Section/Inner/OwnerRow/OwnerOption
@onready var directive_option: OptionButton = $TabContainer/Directive/Section/Inner/DirectiveRow/DirectiveOption
@onready var patrol_type_option: OptionButton = $TabContainer/Directive/Section/Inner/PatrolTypeRow/PatrolTypeOption
@onready var compact_spin: SpinBox = $TabContainer/Directive/Section/Inner/CompactRow/CompactSpin
@onready var leash_spin: SpinBox = $TabContainer/Directive/Section/Inner/LeashRow/LeashSpin
@onready var anchor_value: Label = $TabContainer/Directive/Section/Inner/AnchorRow/AnchorValue
@onready var patrol_value: Label = $TabContainer/Directive/Section/Inner/PatrolRow/PatrolValue
@onready var apply_button: Button = $TabContainer/Directive/Section/Inner/ButtonsRow/ApplyButton
@onready var reset_anchor_button: Button = $TabContainer/Directive/Section/Inner/ButtonsRow/ResetAnchorButton
@onready var reset_all_button: Button = $TabContainer/Directive/Section/Inner/ButtonsRow/ResetAllButton
@onready var overlay_toggle: CheckButton = $OverlayToggle

@onready var squad_tree: Tree = $TabContainer/Squads/SquadTree
@onready var quick_hold_button: Button = $TabContainer/Squads/QuickButtons/QuickHold
@onready var quick_patrol_button: Button = $TabContainer/Squads/QuickButtons/QuickPatrol
@onready var set_anchor_here_button: Button = $TabContainer/Squads/AnchorButtons/SetAnchorHere
@onready var auto_patrol_ring_button: Button = $TabContainer/Squads/AnchorButtons/AutoPatrolRing

var game_map: GameMap = null
var _anchor_pick_mode: bool = false
var _anchor_pick_owner_key: String = ""


func _ready() -> void:
	owner_option.item_selected.connect(_on_owner_selected)
	apply_button.pressed.connect(_on_apply_pressed)
	reset_anchor_button.pressed.connect(_on_set_anchor_pressed)
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	overlay_toggle.toggled.connect(_on_overlay_toggled)
	squad_tree.item_selected.connect(_on_squad_tree_item_selected)
	squad_tree.set_column_title(0, "Squad")
	squad_tree.set_column_title(1, "Units")
	squad_tree.set_column_title(2, "Directive")
	squad_tree.set_column_title(3, "Center")
	quick_hold_button.pressed.connect(func(): _apply_quick_directive(NpcDirectiveState.Directive.HOLD_PERIMETER))
	quick_patrol_button.pressed.connect(func(): _apply_quick_directive(NpcDirectiveState.Directive.PATROL))
	set_anchor_here_button.pressed.connect(_on_set_anchor_here_pressed)
	auto_patrol_ring_button.pressed.connect(_on_auto_patrol_ring_pressed)
	_populate_directive_options()
	_populate_patrol_type_options()
	_set_anchor_pick_mode(false)
	overlay_toggle.button_pressed = DEFAULT_AI_OVERLAY_ENABLED
	ai_overlay_toggled.emit(overlay_toggle.button_pressed)
	clear()


func setup(p_game_map: GameMap) -> void:
	game_map = p_game_map
	_refresh_owner_options()
	_refresh_selected_state()
	_refresh_squad_tree()


func clear() -> void:
	game_map = null
	owner_option.clear()
	patrol_type_option.disabled = true
	directive_option.disabled = true
	compact_spin.editable = false
	leash_spin.editable = false
	apply_button.disabled = true
	reset_anchor_button.disabled = true
	anchor_value.text = "-"
	patrol_value.text = "-"
	reset_all_button.disabled = true
	if squad_tree:
		squad_tree.clear()
	_toggle_quick_buttons(false)
	_set_anchor_pick_mode(false)


func refresh_state() -> void:
	if not game_map:
		clear()
		return
	_refresh_owner_options()
	_refresh_selected_state()
	_refresh_squad_tree()


func _populate_directive_options() -> void:
	directive_option.clear()
	directive_option.add_item("Hold")
	directive_option.add_item("Patrol")


func _populate_patrol_type_options() -> void:
	patrol_type_option.clear()
	patrol_type_option.add_item("Circle")
	patrol_type_option.add_item("Map Border")


func _refresh_owner_options() -> void:
	var selected_owner_key: String = _get_selected_owner_key_from_owner_option()
	owner_option.clear()
	if not game_map:
		return

	var owner_keys: Array[String] = game_map.get_owner_keys(false)
	owner_keys.sort_custom(func(a: String, b: String):
		return game_map.get_owner_label_by_key(a).to_lower() < game_map.get_owner_label_by_key(b).to_lower()
	)

	for owner_key in owner_keys:
		var index: int = owner_option.item_count
		owner_option.add_item(game_map.get_owner_label_by_key(owner_key))
		owner_option.set_item_metadata(index, owner_key)
		if owner_key == selected_owner_key:
			owner_option.select(index)

	if owner_option.item_count > 0 and owner_option.get_selected() < 0:
		owner_option.select(0)


func _refresh_selected_state() -> void:
	if not game_map or owner_option.item_count <= 0:
		patrol_type_option.disabled = true
		directive_option.disabled = true
		compact_spin.editable = false
		leash_spin.editable = false
		apply_button.disabled = true
		reset_anchor_button.disabled = true
		reset_all_button.disabled = true
		anchor_value.text = "-"
		patrol_value.text = "-"
		return

	var owner_key: String = str(owner_option.get_item_metadata(owner_option.get_selected()))
	var state: RefCounted = game_map.get_owner_directive_by_key(owner_key)
	if not state:
		return

	directive_option.disabled = false
	compact_spin.editable = true
	leash_spin.editable = true
	apply_button.disabled = false
	reset_anchor_button.disabled = false
	reset_all_button.disabled = false

	directive_option.select(int(state.directive))
	patrol_type_option.disabled = false
	patrol_type_option.select(int(state.patrol_type))
	compact_spin.set_value_no_signal(state.compact_radius)
	leash_spin.set_value_no_signal(state.leash_radius)
	anchor_value.text = "(%d, %d)" % [state.anchor_position.x, state.anchor_position.y]

	var patrol_target: Vector2i = state.get_patrol_target()
	patrol_value.text = "(%d, %d)" % [patrol_target.x, patrol_target.y]


func _on_owner_selected(_index: int) -> void:
	_refresh_selected_state()


func _on_apply_pressed() -> void:
	if not game_map or owner_option.item_count <= 0:
		return

	var owner_key: String = str(owner_option.get_item_metadata(owner_option.get_selected()))
	var state: RefCounted = game_map.get_owner_directive_by_key(owner_key)
	if not state:
		return

	state.directive = directive_option.get_selected()
	state.patrol_type = patrol_type_option.get_selected()
	state.compact_radius = maxi(1, int(compact_spin.value))
	state.leash_radius = maxi(1, int(leash_spin.value))
	game_map.owner_directives[owner_key] = state
	game_map.refresh_owner_patrol_waypoints(owner_key)
	_reissue_ai_orders()

	_refresh_selected_state()
	directives_changed.emit(game_map)
	_refresh_squad_tree()


func _on_set_anchor_pressed() -> void:
	if not game_map or owner_option.item_count <= 0:
		return

	var owner_key: String = str(owner_option.get_item_metadata(owner_option.get_selected()))
	if owner_key.is_empty():
		return

	if _anchor_pick_mode and _anchor_pick_owner_key == owner_key:
		_set_anchor_pick_mode(false)
		return

	_set_anchor_pick_mode(true, owner_key)


func _on_reset_all_pressed() -> void:
	if not game_map:
		return

	game_map.clear_all_owner_directives()
	_set_anchor_pick_mode(false)
	_reissue_ai_orders()
	_refresh_owner_options()
	_refresh_selected_state()
	_refresh_squad_tree()
	directives_changed.emit(game_map)


func _refresh_squad_tree() -> void:
	var selected_owner_key: String = _get_selected_owner_key_from_squad_tree()
	squad_tree.clear()
	var root: TreeItem = squad_tree.create_item()
	if not game_map:
		_toggle_quick_buttons(false)
		return

	var owner_keys: Array[String] = game_map.get_owner_keys(false)
	owner_keys.sort_custom(func(a: String, b: String):
		return game_map.get_owner_label_by_key(a).to_lower() < game_map.get_owner_label_by_key(b).to_lower()
	)

	for owner_key in owner_keys:
		var entities: Array[MapCombatEntity] = game_map.get_owned_combat_entities_by_key(owner_key)
		if entities.is_empty():
			continue

		var state: RefCounted = game_map.get_owner_directive_by_key(owner_key)
		var centroid: Vector2i = _compute_centroid(entities)
		var row: TreeItem = squad_tree.create_item(root)
		row.set_text(0, game_map.get_owner_label_by_key(owner_key))
		row.set_text(1, str(entities.size()))
		row.set_text(2, _directive_label(int(state.directive)))
		row.set_text(3, "(%d, %d)" % [centroid.x, centroid.y])
		row.set_metadata(0, owner_key)
		if owner_key == selected_owner_key:
			row.select(0)

	var first_child: TreeItem = squad_tree.get_root().get_first_child()
	if first_child and not squad_tree.get_selected():
		first_child.select(0)
	_toggle_quick_buttons(squad_tree.get_selected() != null)


func _toggle_quick_buttons(enabled: bool) -> void:
	quick_hold_button.disabled = not enabled
	quick_patrol_button.disabled = not enabled
	set_anchor_here_button.disabled = not enabled
	auto_patrol_ring_button.disabled = not enabled


func _on_squad_tree_item_selected() -> void:
	if not game_map:
		return

	var selected_item: TreeItem = squad_tree.get_selected()
	if not selected_item:
		return

	var owner_key: String = str(selected_item.get_metadata(0))
	if owner_key.is_empty():
		return

	for index in range(owner_option.item_count):
		if str(owner_option.get_item_metadata(index)) == owner_key:
			owner_option.select(index)
			break

	_refresh_selected_state()


func _apply_quick_directive(directive: int) -> void:
	if not game_map:
		return

	var selected_item: TreeItem = squad_tree.get_selected()
	if not selected_item:
		return

	var owner_key: String = str(selected_item.get_metadata(0))
	if owner_key.is_empty():
		return

	game_map.set_owner_directive_by_key(owner_key, directive)
	_reissue_ai_orders()
	_refresh_selected_state()
	_refresh_squad_tree()
	directives_changed.emit(game_map)


func _on_set_anchor_here_pressed() -> void:
	var owner_key: String = _get_selected_owner_key_from_squad_tree()
	if owner_key.is_empty() or not game_map:
		return

	if _anchor_pick_mode and _anchor_pick_owner_key == owner_key:
		_set_anchor_pick_mode(false)
		return

	_set_anchor_pick_mode(true, owner_key)


func _on_auto_patrol_ring_pressed() -> void:
	var owner_key: String = _get_selected_owner_key_from_squad_tree()
	if owner_key.is_empty() or not game_map:
		return

	game_map.auto_generate_owner_patrol_ring_from_centroid(owner_key)
	_reissue_ai_orders()
	_refresh_selected_state()
	_refresh_squad_tree()
	directives_changed.emit(game_map)


func _on_overlay_toggled(enabled: bool) -> void:
	ai_overlay_toggled.emit(enabled)


func is_ai_overlay_enabled() -> bool:
	return overlay_toggle and overlay_toggle.button_pressed


func apply_anchor_from_map(cell_position: Vector2i) -> bool:
	if not game_map or not _anchor_pick_mode:
		return false
	if _anchor_pick_owner_key.is_empty() or not game_map.is_in_bounds(cell_position):
		_set_anchor_pick_mode(false)
		return false

	game_map.set_owner_anchor(_anchor_pick_owner_key, cell_position, true)
	_set_anchor_pick_mode(false)
	_reissue_ai_orders()
	_refresh_selected_state()
	_refresh_squad_tree()
	directives_changed.emit(game_map)
	return true


func is_anchor_pick_mode_enabled() -> bool:
	return _anchor_pick_mode


func _reissue_ai_orders() -> void:
	if not game_map or not game_map.ai_controller:
		return
	game_map.ai_controller.clear()
	game_map.ai_controller.generate_ai_orders()


func _set_anchor_pick_mode(enabled: bool, owner_key: String = "") -> void:
	_anchor_pick_mode = enabled and not owner_key.is_empty()
	_anchor_pick_owner_key = owner_key if _anchor_pick_mode else ""

	if reset_anchor_button:
		reset_anchor_button.text = "Cancel Anchor Pick" if _anchor_pick_mode else "Set Anchor"
	if set_anchor_here_button:
		set_anchor_here_button.text = "Cancel Anchor Pick" if _anchor_pick_mode else "Set Anchor"

	anchor_pick_mode_changed.emit(_anchor_pick_mode)


func _get_selected_owner_key_from_owner_option() -> String:
	if owner_option.item_count <= 0 or owner_option.get_selected() < 0:
		return ""
	return str(owner_option.get_item_metadata(owner_option.get_selected()))


func _get_selected_owner_key_from_squad_tree() -> String:
	var selected_item: TreeItem = squad_tree.get_selected()
	if not selected_item:
		return ""
	return str(selected_item.get_metadata(0))


func _directive_label(directive: int) -> String:
	match directive:
		NpcDirectiveState.Directive.HOLD_PERIMETER:
			return "Hold"
		NpcDirectiveState.Directive.PATROL:
			return "Patrol"
		_:
			return "Unknown"


func _compute_centroid(entities: Array[MapCombatEntity]) -> Vector2i:
	if entities.is_empty():
		return Vector2i.ZERO

	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y

	return Vector2i(
		int(round(float(sum_x) / entities.size())),
		int(round(float(sum_y) / entities.size())),
	)
