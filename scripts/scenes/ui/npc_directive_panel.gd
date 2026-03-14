extends VBoxContainer

signal directives_changed(game_map: GameMap)
signal ai_overlay_toggled(enabled: bool)
signal anchor_pick_mode_changed(enabled: bool)

enum PendingAction {
	NONE,
	MOVE_COMPACT,
	MOVE_NOW,
	PATROL,
}

const DEFAULT_AI_OVERLAY_ENABLED: bool = false
const DEFAULT_SPREAD: int = 6
const MOVE_NOW_COMPACT_RADIUS: int = 30

var game_map: GameMap = null
var _anchor_pick_mode: bool = false
var _anchor_pick_owner_key: String = ""
var _pending_action: int = PendingAction.NONE

@onready var squad_option: OptionButton = $SquadRow/SquadOption
@onready var squad_tree: Tree = $SquadTree
@onready var spread_spin: SpinBox = $SpreadRow/SpreadSpin
@onready var move_compact_button: Button = $MoveButtons/MoveCompactButton
@onready var move_now_button: Button = $MoveButtons/MoveNowButton
@onready var circle_button: Button = $PatrolTypeRow/CircleButton
@onready var square_button: Button = $PatrolTypeRow/SquareButton
@onready var border_button: Button = $PatrolTypeRow/BorderButton
@onready var patrol_button: Button = $PatrolButton
@onready var cancel_button: Button = $CancelButton
@onready var overlay_toggle: CheckButton = $OverlayToggle


func _ready() -> void:
	squad_option.item_selected.connect(_on_squad_selected)
	squad_tree.item_selected.connect(_on_squad_tree_item_selected)
	squad_tree.set_column_title(0, "Squad")
	squad_tree.set_column_title(1, "Units")
	squad_tree.set_column_title(2, "Directive")
	squad_tree.set_column_title(3, "Center")
	move_compact_button.pressed.connect(_on_move_compact_pressed)
	move_now_button.pressed.connect(_on_move_now_pressed)
	patrol_button.pressed.connect(_on_patrol_pressed)
	cancel_button.pressed.connect(_on_cancel_all_pressed)
	overlay_toggle.toggled.connect(_on_overlay_toggled)
	_set_anchor_pick_mode(false)
	overlay_toggle.button_pressed = DEFAULT_AI_OVERLAY_ENABLED
	ai_overlay_toggled.emit(overlay_toggle.button_pressed)
	clear()


func setup(p_game_map: GameMap) -> void:
	game_map = p_game_map
	_refresh_squad_option()
	_refresh_squad_tree()
	_refresh_spread_from_selection()


func clear() -> void:
	game_map = null
	squad_option.clear()
	if squad_tree:
		squad_tree.clear()
	_set_controls_enabled(false)
	_set_anchor_pick_mode(false)
	spread_spin.set_value_no_signal(DEFAULT_SPREAD)


func refresh_state() -> void:
	if not game_map:
		clear()
		return
	_refresh_squad_option()
	_refresh_squad_tree()
	_refresh_spread_from_selection()


func set_selected_entity(entity: MapEntity) -> void:
	if not game_map or not entity or not entity.owner:
		return
	var owner_key: String = game_map.get_owner_key(entity.owner)
	if owner_key.is_empty():
		return
	for index in range(squad_option.item_count):
		if str(squad_option.get_item_metadata(index)) == owner_key:
			squad_option.select(index)
			break
	_sync_tree_to_option()
	_refresh_spread_from_selection()


func apply_anchor_from_map(cell_position: Vector2i) -> bool:
	if not game_map or not _anchor_pick_mode:
		return false
	if _anchor_pick_owner_key.is_empty() or not game_map.is_in_bounds(cell_position):
		_set_anchor_pick_mode(false)
		return false

	var state := (
		game_map.get_owner_directive_by_key(_anchor_pick_owner_key) as NpcDirectiveState
	)
	if not state:
		_set_anchor_pick_mode(false)
		return false

	var spread: int = maxi(1, int(spread_spin.value))
	match _pending_action:
		PendingAction.MOVE_COMPACT:
			state.directive = NpcDirectiveState.Directive.HOLD_PERIMETER
			state.anchor_position = cell_position
			state.compact_radius = spread
			state.leash_radius = spread
			state.patrol_index = 0
			game_map.owner_directives[_anchor_pick_owner_key] = state
		PendingAction.MOVE_NOW:
			state.directive = NpcDirectiveState.Directive.HOLD_PERIMETER
			state.anchor_position = cell_position
			state.compact_radius = MOVE_NOW_COMPACT_RADIUS
			state.leash_radius = MOVE_NOW_COMPACT_RADIUS
			state.patrol_index = 0
			game_map.owner_directives[_anchor_pick_owner_key] = state
		PendingAction.PATROL:
			state.directive = NpcDirectiveState.Directive.PATROL
			state.anchor_position = cell_position
			state.compact_radius = spread
			state.leash_radius = spread
			state.patrol_type = _get_selected_patrol_type()
			game_map.owner_directives[_anchor_pick_owner_key] = state
			game_map.refresh_owner_patrol_waypoints(_anchor_pick_owner_key)
		_:
			_set_anchor_pick_mode(false)
			return false

	_set_anchor_pick_mode(false)
	_reissue_ai_orders()
	_refresh_squad_tree()
	directives_changed.emit(game_map)
	return true


func is_anchor_pick_mode_enabled() -> bool:
	return _anchor_pick_mode


func is_ai_overlay_enabled() -> bool:
	return overlay_toggle and overlay_toggle.button_pressed


func _on_squad_selected(_index: int) -> void:
	_sync_tree_to_option()
	_refresh_spread_from_selection()


func _on_squad_tree_item_selected() -> void:
	if not game_map:
		return
	var selected_item: TreeItem = squad_tree.get_selected()
	if not selected_item:
		return
	var owner_key: String = str(selected_item.get_metadata(0))
	if owner_key.is_empty():
		return
	for index in range(squad_option.item_count):
		if str(squad_option.get_item_metadata(index)) == owner_key:
			squad_option.select(index)
			break
	_refresh_spread_from_selection()


func _on_move_compact_pressed() -> void:
	var owner_key: String = _get_selected_owner_key()
	if owner_key.is_empty() or not game_map:
		return
	if (
		_anchor_pick_mode
		and _anchor_pick_owner_key == owner_key
		and _pending_action == PendingAction.MOVE_COMPACT
	):
		_set_anchor_pick_mode(false)
		return
	_pending_action = PendingAction.MOVE_COMPACT
	_set_anchor_pick_mode(true, owner_key)


func _on_move_now_pressed() -> void:
	var owner_key: String = _get_selected_owner_key()
	if owner_key.is_empty() or not game_map:
		return
	if (
		_anchor_pick_mode
		and _anchor_pick_owner_key == owner_key
		and _pending_action == PendingAction.MOVE_NOW
	):
		_set_anchor_pick_mode(false)
		return
	_pending_action = PendingAction.MOVE_NOW
	_set_anchor_pick_mode(true, owner_key)


func _on_patrol_pressed() -> void:
	var owner_key: String = _get_selected_owner_key()
	if owner_key.is_empty() or not game_map:
		return
	if (
		_anchor_pick_mode
		and _anchor_pick_owner_key == owner_key
		and _pending_action == PendingAction.PATROL
	):
		_set_anchor_pick_mode(false)
		return

	# MAP_BORDER patrol applies immediately — no anchor click needed
	if border_button.button_pressed:
		var state := (
			game_map.get_owner_directive_by_key(owner_key) as NpcDirectiveState
		)
		if state:
			var spread: int = maxi(1, int(spread_spin.value))
			state.directive = NpcDirectiveState.Directive.PATROL
			state.patrol_type = NpcDirectiveState.PatrolType.MAP_BORDER
			state.leash_radius = spread
			state.compact_radius = spread
			game_map.owner_directives[owner_key] = state
			game_map.refresh_owner_patrol_waypoints(owner_key)
			_reissue_ai_orders()
			_refresh_squad_tree()
			directives_changed.emit(game_map)
		return

	_pending_action = PendingAction.PATROL
	_set_anchor_pick_mode(true, owner_key)


func _on_cancel_all_pressed() -> void:
	if not game_map:
		return
	game_map.clear_all_owner_directives()
	for owner_key: String in game_map.get_owner_keys(false):
		game_map.set_owner_directive_by_key(
			owner_key, NpcDirectiveState.Directive.HOLD_PERIMETER
		)
	_set_anchor_pick_mode(false)
	_reissue_ai_orders()
	_refresh_squad_option()
	_refresh_squad_tree()
	directives_changed.emit(game_map)


func _on_overlay_toggled(enabled: bool) -> void:
	ai_overlay_toggled.emit(enabled)


func _refresh_squad_option() -> void:
	var selected_owner_key: String = _get_selected_owner_key()
	squad_option.clear()
	if not game_map:
		_set_controls_enabled(false)
		return

	var owner_keys: Array[String] = game_map.get_owner_keys(false)
	owner_keys.sort_custom(func(a: String, b: String):
		return (
			game_map.get_owner_label_by_key(a).to_lower()
			< game_map.get_owner_label_by_key(b).to_lower()
		)
	)

	for owner_key in owner_keys:
		var index: int = squad_option.item_count
		squad_option.add_item(game_map.get_owner_label_by_key(owner_key))
		squad_option.set_item_metadata(index, owner_key)
		if owner_key == selected_owner_key:
			squad_option.select(index)

	if squad_option.item_count > 0 and squad_option.get_selected() < 0:
		squad_option.select(0)

	_set_controls_enabled(squad_option.item_count > 0)


func _refresh_squad_tree() -> void:
	var selected_owner_key: String = _get_selected_owner_key_from_squad_tree()
	squad_tree.clear()
	var root: TreeItem = squad_tree.create_item()
	if not game_map:
		return

	var owner_keys: Array[String] = game_map.get_owner_keys(false)
	owner_keys.sort_custom(func(a: String, b: String):
		return (
			game_map.get_owner_label_by_key(a).to_lower()
			< game_map.get_owner_label_by_key(b).to_lower()
		)
	)

	for owner_key in owner_keys:
		var entities: Array[MapCombatEntity] = (
			game_map.get_owned_combat_entities_by_key(owner_key)
		)
		if entities.is_empty():
			continue
		var state := (
			game_map.get_owner_directive_by_key(owner_key) as NpcDirectiveState
		)
		var centroid: Vector2i = _compute_centroid(entities)
		var row: TreeItem = squad_tree.create_item(root)
		row.set_text(0, game_map.get_owner_label_by_key(owner_key))
		row.set_text(1, str(entities.size()))
		row.set_text(2, _directive_label(state))
		row.set_text(3, "(%d, %d)" % [centroid.x, centroid.y])
		row.set_metadata(0, owner_key)
		if owner_key == selected_owner_key:
			row.select(0)

	var first_child: TreeItem = squad_tree.get_root().get_first_child()
	if first_child and not squad_tree.get_selected():
		first_child.select(0)


func _refresh_spread_from_selection() -> void:
	var owner_key: String = _get_selected_owner_key()
	if owner_key.is_empty() or not game_map:
		spread_spin.set_value_no_signal(DEFAULT_SPREAD)
		return
	var state := (
		game_map.get_owner_directive_by_key(owner_key) as NpcDirectiveState
	)
	if not state:
		spread_spin.set_value_no_signal(DEFAULT_SPREAD)
		return
	spread_spin.set_value_no_signal(state.leash_radius)
	_sync_patrol_type_buttons(state.patrol_type)


func _sync_patrol_type_buttons(patrol_type: int) -> void:
	match patrol_type:
		NpcDirectiveState.PatrolType.SQUARE:
			square_button.button_pressed = true
		NpcDirectiveState.PatrolType.MAP_BORDER:
			border_button.button_pressed = true
		_:
			circle_button.button_pressed = true


func _sync_tree_to_option() -> void:
	var owner_key: String = _get_selected_owner_key()
	if owner_key.is_empty() or not squad_tree.get_root():
		return
	var item: TreeItem = squad_tree.get_root().get_first_child()
	while item:
		if str(item.get_metadata(0)) == owner_key:
			item.select(0)
			break
		item = item.get_next()


func _set_controls_enabled(enabled: bool) -> void:
	move_compact_button.disabled = not enabled
	move_now_button.disabled = not enabled
	patrol_button.disabled = not enabled
	cancel_button.disabled = not enabled
	spread_spin.editable = enabled


func _set_anchor_pick_mode(enabled: bool, owner_key: String = "") -> void:
	_anchor_pick_mode = enabled and not owner_key.is_empty()
	_anchor_pick_owner_key = owner_key if _anchor_pick_mode else ""
	if not _anchor_pick_mode:
		_pending_action = PendingAction.NONE
	_update_action_button_labels()
	anchor_pick_mode_changed.emit(_anchor_pick_mode)


func _update_action_button_labels() -> void:
	move_compact_button.text = (
		"Cancel"
		if (_anchor_pick_mode and _pending_action == PendingAction.MOVE_COMPACT)
		else "Move Compact"
	)
	move_now_button.text = (
		"Cancel"
		if (_anchor_pick_mode and _pending_action == PendingAction.MOVE_NOW)
		else "Move Now"
	)
	patrol_button.text = (
		"Cancel"
		if (_anchor_pick_mode and _pending_action == PendingAction.PATROL)
		else "Patrol"
	)


func _reissue_ai_orders() -> void:
	if not game_map or not game_map.ai_controller:
		return
	game_map.ai_controller.clear()
	game_map.ai_controller.generate_ai_orders()


func _get_selected_owner_key() -> String:
	if squad_option.item_count <= 0 or squad_option.get_selected() < 0:
		return ""
	return str(squad_option.get_item_metadata(squad_option.get_selected()))


func _get_selected_owner_key_from_squad_tree() -> String:
	var selected_item: TreeItem = squad_tree.get_selected()
	if not selected_item:
		return ""
	return str(selected_item.get_metadata(0))


func _get_selected_patrol_type() -> int:
	if square_button.button_pressed:
		return NpcDirectiveState.PatrolType.SQUARE
	if border_button.button_pressed:
		return NpcDirectiveState.PatrolType.MAP_BORDER
	return NpcDirectiveState.PatrolType.CIRCLE


func _directive_label(state: NpcDirectiveState) -> String:
	if not state or state.directive != NpcDirectiveState.Directive.PATROL:
		return "Move"
	match state.patrol_type:
		NpcDirectiveState.PatrolType.SQUARE:
			return "Patrol (Square)"
		NpcDirectiveState.PatrolType.MAP_BORDER:
			return "Patrol (Border)"
		_:
			return "Patrol (Circle)"


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
