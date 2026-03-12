extends VBoxContainer

signal turn_controls_changed(game_map: GameMap)

@onready var status_label: Label = $Section/Inner/StatusRow/StatusValue
@onready var turn_label: Label = $Section/Inner/TurnRow/TurnValue
@onready var countdown_label: Label = $Section/Inner/CountdownRow/CountdownValue
@onready var start_stop_button: Button = $Section/Inner/ActionRow/StartStop
@onready var step_button: Button = $Section/Inner/ActionRow/Step
@onready var interval_spin: SpinBox = $Section/Inner/IntervalRow/IntervalSpin
@onready var daytime_spin: SpinBox = $Section/Inner/DaytimeRow/DaytimeSpin
@onready var apply_daytime_button: Button = $Section/Inner/DaytimeRow/ApplyDaytime
@onready var weather_value: Label = $Future/FutureInner/WeatherRow/WeatherValue
@onready var temperature_value: Label = $Future/FutureInner/TemperatureRow/TemperatureValue

var game_map: GameMap = null


func _ready() -> void:
	start_stop_button.pressed.connect(_on_start_stop_pressed)
	step_button.pressed.connect(_on_step_pressed)
	interval_spin.value_changed.connect(_on_interval_changed)
	apply_daytime_button.pressed.connect(_on_apply_daytime_pressed)
	clear()


func _process(_delta: float) -> void:
	_refresh_dynamic_values()


func setup(p_game_map: GameMap) -> void:
	_disconnect_current_map_signals()
	game_map = p_game_map
	_connect_current_map_signals()
	_sync_controls_from_map()
	refresh_state()


func clear() -> void:
	_disconnect_current_map_signals()
	game_map = null
	status_label.text = "No map selected"
	turn_label.text = "-"
	countdown_label.text = "-"
	start_stop_button.text = "Start"
	start_stop_button.disabled = true
	step_button.disabled = true
	interval_spin.editable = false
	apply_daytime_button.disabled = true
	daytime_spin.editable = false
	weather_value.text = "Reserved"
	temperature_value.text = "Reserved"


func refresh_state() -> void:
	if not game_map:
		clear()
		return

	var turn_manager: TurnManager = game_map.turn_manager
	var has_combat: bool = game_map.has_hostile_pairs()
	var is_active: bool = turn_manager.is_active()

	status_label.text = "Running" if is_active else "Paused"
	turn_label.text = str(turn_manager.get_current_turn())
	start_stop_button.text = "Stop" if is_active else "Start"
	start_stop_button.disabled = not has_combat
	step_button.disabled = not has_combat
	interval_spin.editable = true
	apply_daytime_button.disabled = false
	daytime_spin.editable = true


func _refresh_dynamic_values() -> void:
	if not game_map:
		return

	var turn_manager: TurnManager = game_map.turn_manager

	if turn_manager.is_active():
		countdown_label.text = "%.2fs" % turn_manager.get_time_until_next_turn()
	else:
		countdown_label.text = "-"

	turn_label.text = str(turn_manager.get_current_turn())


func _sync_controls_from_map() -> void:
	if not game_map:
		return

	var turn_manager: TurnManager = game_map.turn_manager
	interval_spin.set_value_no_signal(turn_manager.get_turn_interval())
	daytime_spin.set_value_no_signal(turn_manager.get_time_of_day() * 24.0)


func _connect_current_map_signals() -> void:
	if not game_map or not game_map.turn_manager:
		return

	var turn_manager: TurnManager = game_map.turn_manager
	if not turn_manager.on_turn_started.is_connected(_on_turn_started):
		turn_manager.on_turn_started.connect(_on_turn_started)
	if not turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		turn_manager.on_turn_ended.connect(_on_turn_ended)


func _disconnect_current_map_signals() -> void:
	if not game_map or not game_map.turn_manager:
		return

	var turn_manager: TurnManager = game_map.turn_manager
	if turn_manager.on_turn_started.is_connected(_on_turn_started):
		turn_manager.on_turn_started.disconnect(_on_turn_started)
	if turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		turn_manager.on_turn_ended.disconnect(_on_turn_ended)


func _on_turn_started(_turn_number: int) -> void:
	refresh_state()
	turn_controls_changed.emit(game_map)


func _on_turn_ended(_turn_number: int) -> void:
	refresh_state()
	turn_controls_changed.emit(game_map)


func _on_start_stop_pressed() -> void:
	if not game_map:
		return
	if not game_map.has_hostile_pairs():
		refresh_state()
		return

	var turn_manager: TurnManager = game_map.turn_manager
	if turn_manager.is_active():
		turn_manager.stop()
	else:
		turn_manager.start()

	refresh_state()
	turn_controls_changed.emit(game_map)


func _on_step_pressed() -> void:
	if not game_map:
		return
	if not game_map.has_hostile_pairs():
		refresh_state()
		return

	game_map.turn_manager.step_once()
	refresh_state()
	turn_controls_changed.emit(game_map)


func _on_interval_changed(value: float) -> void:
	if not game_map:
		return

	game_map.turn_manager.set_turn_interval(value)
	refresh_state()
	turn_controls_changed.emit(game_map)


func _on_apply_daytime_pressed() -> void:
	if not game_map:
		return

	game_map.turn_manager.set_time_of_day_hours(daytime_spin.value)
	refresh_state()
	turn_controls_changed.emit(game_map)
