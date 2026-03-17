extends PanelContainer

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var selected_combatant: CombatActor = null

# =============================================================================
# COMPONENT REFERENCES
# =============================================================================

@onready var combat_log = $TabContainer/CombatLog/ScrollContainer/CombatLog
@onready var mind_log = $TabContainer/Mind/ScrollContainer/MindLog
@onready var chat_log = $TabContainer/Chat/ScrollContainer/ChatLog
@onready var chat_input = $TabContainer/Chat/ChatInput
@onready var info_message = $TabContainer/Chat/ChatInput/InfoMessageBox/InfoMessage
@onready var info_message_box = $TabContainer/Chat/ChatInput/InfoMessageBox

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func _ready():
	chat_input.text_submitted.connect(_on_chat_input_submitted)


# =============================================================================
# PUBLIC METHODS
# =============================================================================


func setup(p_game_map: GameMap):
	clear()
	# Set the game_map reference.
	game_map = p_game_map
	# Connect signals to log messages.
	if game_map and not game_map.chat_logger.on_log_added.is_connected(_on_log_added_chat):
		game_map.chat_logger.on_log_added.connect(_on_log_added_chat)
	if game_map and not game_map.combat_logger.on_log_added.is_connected(_on_log_added_combat):
		game_map.combat_logger.on_log_added.connect(_on_log_added_combat)
	# Load existing logs.
	for log_entry in game_map.combat_logger.get_logs():
		add_log_entry_combat(log_entry)
	for log_entry in game_map.chat_logger.get_logs():
		add_log_entry_chat(log_entry)
	set_selected_entity(null)


func clear():
	# Disconnect signals to avoid memory leaks.
	if game_map and game_map.chat_logger.on_log_added.is_connected(_on_log_added_chat):
		game_map.chat_logger.on_log_added.disconnect(_on_log_added_chat)
	if game_map and game_map.combat_logger.on_log_added.is_connected(_on_log_added_combat):
		game_map.combat_logger.on_log_added.disconnect(_on_log_added_combat)
	if (
		selected_combatant
		and selected_combatant.ai_thought_logged.is_connected(_on_ai_thought_logged)
	):
		selected_combatant.ai_thought_logged.disconnect(_on_ai_thought_logged)
	selected_combatant = null
	# Unset the game_map reference.
	game_map = null
	# Clear the logs.
	combat_log.clear()
	mind_log.clear()
	chat_log.clear()


func add_log_entry_combat(entry: LogEntry):
	combat_log.append_text("[" + entry.timestamp + "] " + entry.message + "\n")


func add_log_message(entry: String):
	var timestamp = Time.get_time_string_from_system()
	combat_log.append_text("[" + timestamp + "] " + entry + "\n")


func add_log_entry_chat(entry: LogEntry):
	chat_log.append_text("[" + entry.timestamp + "] " + entry.sender + ": " + entry.message + "\n")


func add_chat_message(message: String):
	var timestamp = Time.get_time_string_from_system()
	chat_log.append_text("[" + timestamp + "] " + message + "\n")


func set_selected_entity(entity: MapEntity) -> void:
	if selected_combatant and selected_combatant.ai_thought_logged.is_connected(_on_ai_thought_logged):
		selected_combatant.ai_thought_logged.disconnect(_on_ai_thought_logged)

	selected_combatant = null
	mind_log.clear()

	if entity and is_instance_of(entity, MapCombatEntity):
		selected_combatant = (entity as MapCombatEntity).combatant

	if not selected_combatant:
		mind_log.append_text("Select a Mek/Structure to inspect AI thoughts.\n")
		return

	if not selected_combatant.ai_thought_logged.is_connected(_on_ai_thought_logged):
		selected_combatant.ai_thought_logged.connect(_on_ai_thought_logged)

	for entry: String in selected_combatant.get_ai_thoughts():
		mind_log.append_text(entry + "\n")


# =============================================================================
# PRIVATE METHODS
# =============================================================================


func _on_log_added_combat(entry: LogEntry):
	add_log_entry_combat(entry)


func _on_log_added_chat(entry: LogEntry):
	add_log_entry_chat(entry)


func _on_ai_thought_logged(entry: String) -> void:
	mind_log.append_text(entry + "\n")


func _on_chat_input_submitted(message: String):
	if message.strip_edges().length() > 120:
		_show_info_error("Message too long! Max 120 characters.")
		return
	if not message.strip_edges().is_empty():
		if game_map:
			game_map.chat_logger.add_log(Enums.LogType.CHAT, message, "System")
		chat_input.clear()


func _show_info_error(message: String):
	_show_info_message("[color=red]" + message + "[/color]")


func _show_info_message(message: String):
	# Position the label to the right of ChatInput
	var input_position = chat_input.global_position
	var input_size = chat_input.size
	info_message.clear()
	info_message.append_text(message)
	info_message_box.visible = true
	info_message_box.global_position = Vector2(
		input_position.x + input_size.x - info_message.size.x - 5, input_position.y - 40
	)
	# Hide after 2 seconds
	await get_tree().create_timer(2.0).timeout
	info_message_box.visible = false
