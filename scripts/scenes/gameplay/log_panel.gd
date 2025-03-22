extends PanelContainer

@onready var combat_log   = $TabContainer/CombatLog/ScrollContainer/CombatLog
@onready var chat_log     = $TabContainer/Chat/ScrollContainer/ChatLog
@onready var chat_input   = $TabContainer/Chat/ChatInput

@onready var info_message     = $TabContainer/Chat/ChatInput/InfoMessageBox/InfoMessage
@onready var info_message_box = $TabContainer/Chat/ChatInput/InfoMessageBox

var game_map: GameMap

func _ready():
	add_chat_message("========================================")
	add_chat_message("Booting chat operating system v0.7.6...")
	add_chat_message("Initializing chat system...")
	add_chat_message("========================================")
	add_log_message("========================================")
	add_log_message("Booting log operating system v0.4.3...")
	add_log_message("Initializing log system...")
	add_log_message("========================================")
	
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	
func setup(p_game_map: GameMap):
	game_map = p_game_map
	if not game_map.on_log_added.is_connected(_on_log_added):
		game_map.on_log_added.connect(_on_log_added)

func clear():
	game_map.on_log_added.disconnect(_on_log_added)
	game_map = null

func add_log_message(entry: String):
	var timestamp = Time.get_time_string_from_system()
	combat_log.append_text("[" + timestamp + "] " + entry + "\n")

func add_chat_message(message: String):
	var timestamp = Time.get_time_string_from_system()
	chat_log.append_text("[" + timestamp + "] " + message + "\n")

func send_chat_message(source: String, message: String):
	add_chat_message(source + ": " + message)

func _on_log_added(log_entry: LogEntry):
	if log_entry.log_type == Enums.LogType.CHAT:
		chat_log.append_text(log_entry.to_simple_log() + "\n")
	else:
		combat_log.append_text(log_entry.to_simple_log() + "\n")

func _on_chat_input_submitted(message: String):
	if message.strip_edges().length() > 120:
		_show_info_error("Message too long! Max 120 characters.")
		return
	if not message.strip_edges().is_empty():
		send_chat_message("You", message)
		chat_input.clear()

func _show_info_error(message: String):
	_show_info_message("[color=red]" + message +"[/color]")

func _show_info_message(message: String):
	# Position the label to the right of ChatInput
	var input_position = chat_input.global_position
	var input_size     = chat_input.size
	info_message.clear()
	info_message.append_text(message)
	info_message_box.visible = true
	info_message_box.global_position = Vector2(
		input_position.x + input_size.x - info_message.size.x - 5,
		input_position.y - 40
	)
	# Hide after 2 seconds
	await get_tree().create_timer(2.0).timeout
	info_message_box.visible = false
