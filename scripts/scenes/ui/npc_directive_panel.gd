extends VBoxContainer

signal directives_changed(game_map: GameMap)

const NPC_DIRECTIVE_STATE = preload("res://scripts/data/map/controllers/strategy/npc_directive_state.gd")

@onready var owner_option: OptionButton = $Section/Inner/OwnerRow/OwnerOption
@onready var directive_option: OptionButton = $Section/Inner/DirectiveRow/DirectiveOption
@onready var compact_spin: SpinBox = $Section/Inner/CompactRow/CompactSpin
@onready var leash_spin: SpinBox = $Section/Inner/LeashRow/LeashSpin
@onready var anchor_value: Label = $Section/Inner/AnchorRow/AnchorValue
@onready var patrol_value: Label = $Section/Inner/PatrolRow/PatrolValue
@onready var apply_button: Button = $Section/Inner/ButtonsRow/ApplyButton
@onready var reset_anchor_button: Button = $Section/Inner/ButtonsRow/ResetAnchorButton

var game_map: GameMap = null


func _ready() -> void:
	owner_option.item_selected.connect(_on_owner_selected)
	apply_button.pressed.connect(_on_apply_pressed)
	reset_anchor_button.pressed.connect(_on_reset_anchor_pressed)
	_populate_directive_options()
	clear()


func setup(p_game_map: GameMap) -> void:
	game_map = p_game_map
	_refresh_owner_options()
	_refresh_selected_state()


func clear() -> void:
	game_map = null
	owner_option.clear()
	directive_option.disabled = true
	compact_spin.editable = false
	leash_spin.editable = false
	apply_button.disabled = true
	reset_anchor_button.disabled = true
	anchor_value.text = "-"
	patrol_value.text = "-"


func refresh_state() -> void:
	if not game_map:
		clear()
		return
	_refresh_owner_options()
	_refresh_selected_state()


func _populate_directive_options() -> void:
	directive_option.clear()
	directive_option.add_item("Hold Perimeter")
	directive_option.add_item("Patrol")
	directive_option.add_item("Seek And Destroy")
	directive_option.add_item("Defend Point")
	directive_option.add_item("Retreat To Safe Zone")


func _refresh_owner_options() -> void:
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

	if owner_option.item_count > 0:
		owner_option.select(0)


func _refresh_selected_state() -> void:
	if not game_map or owner_option.item_count <= 0:
		directive_option.disabled = true
		compact_spin.editable = false
		leash_spin.editable = false
		apply_button.disabled = true
		reset_anchor_button.disabled = true
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

	directive_option.select(int(state.directive))
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
	state.compact_radius = maxi(1, int(compact_spin.value))
	state.leash_radius = maxi(1, int(leash_spin.value))
	if state.patrol_waypoints.is_empty():
		game_map.refresh_owner_patrol_waypoints(owner_key)
	else:
		game_map.owner_directives[owner_key] = state

	_refresh_selected_state()
	directives_changed.emit(game_map)


func _on_reset_anchor_pressed() -> void:
	if not game_map or owner_option.item_count <= 0:
		return

	var owner_key: String = str(owner_option.get_item_metadata(owner_option.get_selected()))
	game_map.reset_owner_anchor(owner_key)
	_refresh_selected_state()
	directives_changed.emit(game_map)
