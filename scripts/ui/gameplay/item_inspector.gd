extends VSplitContainer


signal loadout_changed


const DAMAGE_TYPE_DESCRIPTIONS = {
	Enums.DamageType.KINETIC: "Shield  -, Armor  +, Health  =",
	Enums.DamageType.ENERGY: "Shield ++, Armor  -, Health  =",
	Enums.DamageType.EXPLOSIVE: "Shield  -, Armor ++, Health ++",
	Enums.DamageType.PLASMA: "Shield  +, Armor  +, Health  -",
	Enums.DamageType.CORROSIVE: "Shield --, Armor ++, Health  +"
}


var _game_map: GameMap = null
var _entity: MapCombatEntity = null
var _last_selected_tab: int = 0


@onready var tabs: TabContainer = $Tabs
@onready var equipment_panel = $Tabs/Equipment
@onready var plan_panel = $Tabs/Plan
@onready var mind_log: RichTextLabel = $Tabs/Mind/ScrollContainer/MindLog
@onready var item_info: RichTextLabel = $ScrollContainer/ItemInfo
@onready var plan_info: RichTextLabel = plan_panel.plan_info

var _mind_log_combatant: CombatEntity = null


func _ready() -> void:
	if not tabs.tab_changed.is_connected(_on_tab_changed):
		tabs.tab_changed.connect(_on_tab_changed)
	if not equipment_panel.item_selected.is_connected(_on_equipment_item_selected):
		equipment_panel.item_selected.connect(_on_equipment_item_selected)
	if not equipment_panel.loadout_changed.is_connected(_on_equipment_loadout_changed):
		equipment_panel.loadout_changed.connect(_on_equipment_loadout_changed)


func clear() -> void:
	_game_map = null
	_entity = null
	equipment_panel.clear()
	plan_panel.clear()
	_set_mind_log_combatant(null)
	item_info.clear()
	visible = false


func display_combat_entity(game_map: GameMap, map_entity: MapCombatEntity) -> void:
	_game_map = game_map
	_entity = map_entity
	visible = true
	item_info.clear()
	_set_mind_log_combatant(map_entity.combatant)
	equipment_panel.display_combatant(map_entity.combatant)
	plan_panel.display_plan(game_map, map_entity)
	tabs.current_tab = _last_selected_tab


func select_item_by_uuid(uuid: String) -> void:
	if not is_instance_valid(_entity):
		return

	for item: Item in _entity.combatant.items:
		if item and item.uuid == uuid:
			_show_item_details(item)
			return


func _on_tab_changed(tab_index: int) -> void:
	_last_selected_tab = tab_index


func _on_equipment_item_selected(item: Item) -> void:
	_show_item_details(item)


func _on_equipment_loadout_changed(selected_item: Item) -> void:
	if _game_map and is_instance_valid(_entity):
		plan_panel.display_plan(_game_map, _entity)
	_show_item_details(selected_item)
	loadout_changed.emit()


func _set_mind_log_combatant(combatant: CombatEntity) -> void:
	# Disconnect previous combatant signal (if any).
	if _mind_log_combatant and _mind_log_combatant.ai_thought_logged.is_connected(_on_ai_thought_logged):
		_mind_log_combatant.ai_thought_logged.disconnect(_on_ai_thought_logged)

	_mind_log_combatant = combatant
	mind_log.clear()

	if not is_instance_valid(_mind_log_combatant):
		mind_log.append_text("Select a Mek/Structure to inspect AI thoughts.\n")
		return

	# Populate the mind log with existing thoughts.
	for entry: String in _mind_log_combatant.get_ai_thoughts():
		mind_log.append_text(entry + "\n")

	# Subscribe to future thoughts.
	if not _mind_log_combatant.ai_thought_logged.is_connected(_on_ai_thought_logged):
		_mind_log_combatant.ai_thought_logged.connect(_on_ai_thought_logged)


func _on_ai_thought_logged(entry: String) -> void:
	mind_log.append_text(entry + "\n")


func _show_item_details(item: Item) -> void:
	if not is_instance_valid(item):
		item_info.clear()
		return

	var text: String = ""
	text += "[center][b]" + item.template.item_name + "[/b][/center]\n"
	text += "Combat Power : " + str(item.evaluate_item_power()) + "\n"
	text += "Slot         : "
	text += UIColor.apply("slot", Enums.SlotType.keys()[item.template.slot]) + "\n"
	text += "Power Usage  : " + UIColor.apply("power", item.template.base_power_usage) + "\n"
	if item.template.modules.is_empty():
		item_info.clear()
		item_info.append_text(text)
		return

	text += "\n[center][b]Modules[/b][/center]\n"
	text += "[indent]"
	for module in item.template.modules:
		var remaining_cooldown := _get_remaining_module_cooldown(item, module)
		var is_on_cooldown := remaining_cooldown > 0
		var module_line: String = "|"
		if is_on_cooldown:
			module_line += "[color=#cf7a7a][b][s]" + module.module_name + "[/s][/b][/color] "
			module_line += "[color=#cf7a7a](CD " + str(remaining_cooldown) + "t)[/color] "
		else:
			module_line += "[b]" + module.module_name + "[/b] "
		module_line += "("
		module_line += UIColor.apply("module_type", "Passive" if module.passive else "Active")
		module_line += ")"
		text += module_line + "\n"

		if not module.passive:
			var active_line: String = "|"
			if module.power_on_use > 0:
				active_line += "Power on Use: "
				active_line += UIColor.apply("power_on_use", str(module.power_on_use))
			if module.cooldown > 0:
				active_line += " | Cooldown: "
				active_line += UIColor.apply("cooldown", str(module.cooldown))
				if is_on_cooldown:
					active_line += " | [color=#cf7a7a]Cooling Down[/color]"
				else:
					active_line += " | [color=#9fb3c8]Ready[/color]"
			if module.module_range > 0:
				active_line += " | Range: "
				active_line += UIColor.apply("module_range", str(module.module_range))
			text += active_line + "\n"

		for effect in module.effects:
			var effect_line: String = "|"
			effect_line += "["
			effect_line += UIColor.apply("effect_type", effect.get_effect_type_label())
			effect_line += "] -> "
			effect_line += UIColor.apply(
				"effect_target_type",
				Enums.TargetType.keys()[effect.target]
			)
			effect_line += " | " + UIColor.apply("effect_amount", str(effect.amount))

			if (
				effect.is_damage()
				or effect.is_dot()
			):
				var damage_type_name: String = Enums.DamageType.keys()[effect.damage_type]
				var damage_description: String = DAMAGE_TYPE_DESCRIPTIONS.get(
					effect.damage_type,
					"No description available."
				)
				effect_line += " [hint={" + damage_description + "}]"
				effect_line += UIColor.apply("effect_damage_type", damage_type_name)
				effect_line += "[/hint]"

			if effect.duration > 0:
				effect_line += ", "
				effect_line += UIColor.apply(
					"effect_duration",
					str(effect.duration) + " rounds"
				)
			if effect.chance < 100:
				effect_line += ", "
				effect_line += UIColor.apply("effect_chance", str(effect.chance) + "%")
			if effect.target == Enums.TargetType.AREA:
				effect_line += ", "
				effect_line += UIColor.apply("effect_radius", str(effect.radius))
				effect_line += ", "
				effect_line += UIColor.apply(
					"effect_center_on_target",
					"Center on Target" if effect.center_on_target else "Center on Self"
				)

			text += effect_line + "\n"
		text += "\n"

	text += "[/indent]"
	item_info.clear()
	item_info.append_text(text)


func _get_remaining_module_cooldown(item: Item, module: ItemModule) -> int:
	if not is_instance_valid(_entity):
		return 0
	if not is_instance_valid(_entity.combatant):
		return 0
	if not _entity.combatant.cooldown_manager:
		return 0
	return _entity.combatant.cooldown_manager.get_remaining_cooldown(item, module)