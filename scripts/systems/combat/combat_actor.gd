class_name CombatActor
extends Node

signal ai_thought_logged(entry: String)

const AI_THOUGHT_LOG_LIMIT: int = 5_000

# =============================================================================
# IDENTITY / EQUIPMENT
# =============================================================================

var uuid: String
var alias: String
var items: Array[Item]
var slots: Array[int]
var ai_thought_log: Array[String] = []

# =============================================================================
# MANAGERS
# =============================================================================

# Wiring to concrete managers is intentionally deferred to migration steps.
var active_effect_manager: ActiveEffectManager = null
var cooldown_manager: CooldownManager = null

# =============================================================================
# COMBAT STATS
# =============================================================================

var base_stats: Dictionary = {}
var modifiers: Dictionary = {}

var health: int:
	get:
		return get_health()
	set(value):
		set_base_stat(Enums.StatType.HEALTH, value)

var armor: int:
	get:
		return get_armor()
	set(value):
		set_base_stat(Enums.StatType.ARMOR, value)

var shield: int:
	get:
		return get_shield()
	set(value):
		set_base_stat(Enums.StatType.SHIELD, value)

var power: int:
	get:
		return get_power()
	set(value):
		set_base_stat(Enums.StatType.POWER, value)

var max_health: int:
	get:
		return get_max_health()
	set(value):
		set_base_stat(Enums.StatType.MAX_HEALTH, value)

var max_armor: int:
	get:
		return get_max_armor()
	set(value):
		set_base_stat(Enums.StatType.MAX_ARMOR, value)

var max_shield: int:
	get:
		return get_max_shield()
	set(value):
		set_base_stat(Enums.StatType.MAX_SHIELD, value)

var max_power: int:
	get:
		return get_max_power()
	set(value):
		set_base_stat(Enums.StatType.MAX_POWER, value)

var health_generation: int:
	get:
		return get_health_generation()
	set(value):
		set_base_stat(Enums.StatType.HEALTH_REGEN, value)

var armor_generation: int:
	get:
		return get_armor_generation()
	set(value):
		set_base_stat(Enums.StatType.ARMOR_REGEN, value)

var shield_generation: int:
	get:
		return get_shield_generation()
	set(value):
		set_base_stat(Enums.StatType.SHIELD_REGEN, value)

var power_generation: int:
	get:
		return get_power_generation()
	set(value):
		set_base_stat(Enums.StatType.POWER_REGEN, value)

var speed: int:
	get:
		return get_speed()
	set(value):
		set_base_stat(Enums.StatType.SPEED, value)

var damage_reduction_all: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_ALL)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_ALL, value)

var damage_reduction_kinetic: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_KINETIC)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_KINETIC, value)

var damage_reduction_energy: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_ENERGY)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_ENERGY, value)

var damage_reduction_explosive: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_EXPLOSIVE, value)

var damage_reduction_plasma: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_PLASMA)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_PLASMA, value)

var damage_reduction_corrosive: int:
	get:
		return get_stat(Enums.StatType.DAMAGE_REDUCTION_CORROSIVE)
	set(value):
		set_base_stat(Enums.StatType.DAMAGE_REDUCTION_CORROSIVE, value)

var accuracy_modifier: int:
	get:
		return get_accuracy_modifier()
	set(value):
		set_base_stat(Enums.StatType.ACCURACY_MODIFIER, value)

var range_modifier: int:
	get:
		return get_range_modifier()
	set(value):
		set_base_stat(Enums.StatType.RANGE_MODIFIER, value)

var cooldown_modifier: int:
	get:
		return get_cooldown_modifier()
	set(value):
		set_base_stat(Enums.StatType.COOLDOWN_MODIFIER, value)

var tiles_moved_last_turn: int = 0

# =============================================================================
# SHARED COMBAT API
# =============================================================================


func is_dead() -> bool:
	return health <= 0


func is_alive() -> bool:
	return health > 0


func get_icon_path() -> String:
	return ""


func add_ai_thought(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	var entry: String = "[%s] %s" % [Time.get_time_string_from_system(), message]
	ai_thought_log.append(entry)
	if ai_thought_log.size() > AI_THOUGHT_LOG_LIMIT:
		ai_thought_log = (
			ai_thought_log
			. slice(
				ai_thought_log.size() - AI_THOUGHT_LOG_LIMIT,
				ai_thought_log.size(),
			)
		)
	ai_thought_logged.emit(entry)


func get_ai_thoughts() -> Array[String]:
	return ai_thought_log.duplicate()


func clear_ai_thoughts() -> void:
	ai_thought_log.clear()


func get_stat(stat: int) -> int:
	return _get_raw_stat(base_stats, stat) + _get_raw_stat(modifiers, stat)


func set_base_stat(stat: int, value: int) -> void:
	if Enums.is_modifier_stat(stat):
		_set_raw_stat(modifiers, stat, value)
		return
	_set_raw_stat(base_stats, stat, value)
	_clamp_after_stat_write(stat)


func modify_stat(stat: int, delta: int) -> void:
	set_base_stat(stat, get_stat(stat) + delta)


func adjust_current_stat(stat: int, amount: int) -> int:
	var before: int = get_stat(stat)
	set_base_stat(stat, before + amount)
	return get_stat(stat) - before


func adjust_health(amount: int) -> int:
	return adjust_current_stat(Enums.StatType.HEALTH, amount)


func adjust_shield(amount: int) -> int:
	return adjust_current_stat(Enums.StatType.SHIELD, amount)


func adjust_armor(amount: int) -> int:
	return adjust_current_stat(Enums.StatType.ARMOR, amount)


func adjust_power(amount: int) -> int:
	return adjust_current_stat(Enums.StatType.POWER, amount)


func regenerate() -> void:
	adjust_health(health_generation)
	adjust_armor(armor_generation)
	adjust_shield(shield_generation)
	adjust_power(power_generation)


func reset_combat_state(stats_payload: Dictionary, p_slots: Array[int] = []) -> void:
	base_stats.clear()
	modifiers.clear()

	for stat: int in Enums.get_stat_types():
		var stat_key: String = Enums.get_stat_key(stat)
		if stats_payload.has(stat_key):
			if Enums.is_modifier_stat(stat):
				_set_raw_stat(modifiers, stat, int(stats_payload.get(stat_key, 0)))
			else:
				_set_raw_stat(base_stats, stat, int(stats_payload.get(stat_key, 0)))

	_ensure_max_defaults()
	_clamp_all_current_stats()
	slots = p_slots.duplicate()


func from_dict(data: Dictionary = {}) -> bool:
	uuid = str(data.get("uuid", uuid))
	alias = str(data.get("alias", alias))
	slots = Utils.to_array_int(data.get("slots", slots))
	_apply_stats_from_payload(data)
	return true


func to_dict() -> Dictionary:
	var data: Dictionary = {
		"uuid": uuid,
		"alias": alias,
		"slots": slots,
		"items": Utils.convert_objects_to_dict(items),
	}
	data.merge(_serialize_stats_payload())
	return data


func to_client_dict() -> Dictionary:
	var data: Dictionary = {
		"uuid": uuid,
		"alias": alias,
		"slots": slots,
		"items": Utils.convert_objects_to_client_dict(items),
	}
	data.merge(_serialize_stats_payload())
	return data


func rebuild_combat_state() -> void:
	pass


func rebuild_combat_state_with_items(stats_payload: Dictionary, p_slots: Array[int] = []) -> void:
	reset_combat_state(stats_payload, p_slots)

	for item in items:
		_enable_item_passive_modifiers(item)

	if slots.is_empty():
		return

	for item in items:
		if item.template.slot >= 0 and item.template.slot < slots.size():
			slots[item.template.slot] -= 1


func initialize_runtime_managers() -> void:
	active_effect_manager = ActiveEffectManager.new(self)
	cooldown_manager = CooldownManager.new(self)


func evaluate_combat_power() -> float:
	return CombatPowerEvaluator.evaluate(self)


func add_effect(module: ItemModule, effect: BaseEffect, source) -> void:
	if not active_effect_manager:
		return
	var active: ActiveEffect = ActiveEffect.new(module, effect, source, effect.duration)
	active_effect_manager.add_active_effect(active)


func clear_active_effects() -> void:
	if not active_effect_manager:
		return
	active_effect_manager.clear()


func _toggle_module_passive_effect_modifiers(module: ItemModule, enable: bool) -> void:
	if module.passive:
		for effect in module.effects:
			if enable:
				effect.apply(self)
			else:
				effect.remove(self)


func _toggle_item_passive_effect_modifiers(item: Item, enable: bool) -> void:
	for module in item.template.modules:
		_toggle_module_passive_effect_modifiers(module, enable)


func _enable_item_passive_modifiers(item: Item) -> void:
	_toggle_item_passive_effect_modifiers(item, true)
	modify_stat(Enums.StatType.POWER, -item.template.base_power_usage)
	modify_stat(Enums.StatType.MAX_POWER, -item.template.base_power_usage)


func _disable_item_passive_modifiers(item: Item) -> void:
	_toggle_item_passive_effect_modifiers(item, false)
	modify_stat(Enums.StatType.POWER, item.template.base_power_usage)
	modify_stat(Enums.StatType.MAX_POWER, item.template.base_power_usage)


func take_damage_from_effect(effect: BaseEffect) -> Dictionary:
	return CombatDamageCalculator.take_damage_from_effect(self, effect)


func take_dot_damage() -> Dictionary:
	return CombatDamageCalculator.take_dot_damage(self)


func repair_from_effect(effect: BaseEffect) -> Dictionary:
	var restored := BaseEffect.adjust_actor_current_stat(self, effect.stat, effect.amount)
	return {"stat": BaseEffect.get_stat_key(effect.stat), "amount": restored}


func apply_regen_effects() -> void:
	if not active_effect_manager:
		return
	for effect in active_effect_manager.get_regen_effects():
		(
			BaseEffect
			. adjust_actor_current_stat(
				self,
				BaseEffect.get_regen_target_stat(effect.effect.stat),
				effect.effect.amount,
			)
		)


# =============================================================================
# EQUIPMENT MANAGEMENT
# =============================================================================


func can_equip_item(item: Item) -> bool:
	"""Checks if the item can be equipped.

	This checks slot availability and whether the combat actor has enough power
	available to power the item.
	"""
	if not item or not item.template:
		return false
	if item.template.slot < 0 or item.template.slot >= slots.size():
		return false
	if slots[item.template.slot] <= 0:
		return false

	var used_power: int = 0
	for equipped_item in items:
		if equipped_item and equipped_item.template:
			used_power += int(equipped_item.template.base_power_usage)

	var available_power: int = max_power - used_power
	return available_power >= int(item.template.base_power_usage)


func add_item(item: Item) -> bool:
	"""Attempts to equip an item if a slot is available."""
	if can_equip_item(item):
		items.append(item)
		items.sort_custom(Item.compare_items)
		slots[item.template.slot] -= 1
		_enable_item_passive_modifiers(item)
		return true
	return false


func remove_item(item: Item) -> bool:
	"""Removes an equipped item, freeing up the slot."""
	if item in items:
		items.erase(item)
		items.sort_custom(Item.compare_items)
		slots[item.template.slot] += 1
		_disable_item_passive_modifiers(item)
		return true
	return false


func get_item(item_uuid: String) -> Variant:
	"""Retrieves an equipped item by UUID."""
	for entry in items:
		if entry.uuid == item_uuid:
			return entry
	return null


func clear_items() -> void:
	"""Safely removes and frees all items currently equipped."""
	for item in items:
		GameServer.free_uuid(item.uuid)
	items.clear()


# =============================================================================
# COMPATIBILITY FACADE GETTERS
# =============================================================================


func get_health() -> int:
	return get_stat(Enums.StatType.HEALTH)


func get_armor() -> int:
	return get_stat(Enums.StatType.ARMOR)


func get_shield() -> int:
	return get_stat(Enums.StatType.SHIELD)


func get_power() -> int:
	return get_stat(Enums.StatType.POWER)


func get_max_health() -> int:
	return get_stat(Enums.StatType.MAX_HEALTH)


func get_max_armor() -> int:
	return get_stat(Enums.StatType.MAX_ARMOR)


func get_max_shield() -> int:
	return get_stat(Enums.StatType.MAX_SHIELD)


func get_max_power() -> int:
	return get_stat(Enums.StatType.MAX_POWER)


func get_health_generation() -> int:
	return get_stat(Enums.StatType.HEALTH_REGEN)


func get_armor_generation() -> int:
	return get_stat(Enums.StatType.ARMOR_REGEN)


func get_shield_generation() -> int:
	return get_stat(Enums.StatType.SHIELD_REGEN)


func get_power_generation() -> int:
	return get_stat(Enums.StatType.POWER_REGEN)


func get_speed() -> int:
	return get_stat(Enums.StatType.SPEED)


func get_accuracy_modifier() -> int:
	return get_stat(Enums.StatType.ACCURACY_MODIFIER)


func get_range_modifier() -> int:
	return get_stat(Enums.StatType.RANGE_MODIFIER)


func get_cooldown_modifier() -> int:
	return get_stat(Enums.StatType.COOLDOWN_MODIFIER)


# =============================================================================
# INTERNAL STAT HELPERS
# =============================================================================


func _serialize_stats_payload() -> Dictionary:
	var payload: Dictionary = {}
	for stat: int in Enums.get_stat_types():
		payload[Enums.get_stat_key(stat)] = get_stat(stat)
	return payload


func _apply_stats_from_payload(payload: Dictionary) -> void:
	for stat: int in Enums.get_stat_types():
		var stat_key: String = Enums.get_stat_key(stat)
		if payload.has(stat_key):
			set_base_stat(stat, int(payload.get(stat_key, 0)))
	_ensure_max_defaults()
	_clamp_all_current_stats()


func _ensure_max_defaults() -> void:
	if not base_stats.has(Enums.StatType.MAX_HEALTH):
		_set_raw_stat(
			base_stats, Enums.StatType.MAX_HEALTH, _get_raw_stat(base_stats, Enums.StatType.HEALTH)
		)
	if not base_stats.has(Enums.StatType.MAX_ARMOR):
		_set_raw_stat(
			base_stats, Enums.StatType.MAX_ARMOR, _get_raw_stat(base_stats, Enums.StatType.ARMOR)
		)
	if not base_stats.has(Enums.StatType.MAX_SHIELD):
		_set_raw_stat(
			base_stats, Enums.StatType.MAX_SHIELD, _get_raw_stat(base_stats, Enums.StatType.SHIELD)
		)
	if not base_stats.has(Enums.StatType.MAX_POWER):
		_set_raw_stat(
			base_stats, Enums.StatType.MAX_POWER, _get_raw_stat(base_stats, Enums.StatType.POWER)
		)


func _clamp_all_current_stats() -> void:
	_clamp_current_stat_to_max(Enums.StatType.HEALTH, Enums.StatType.MAX_HEALTH)
	_clamp_current_stat_to_max(Enums.StatType.ARMOR, Enums.StatType.MAX_ARMOR)
	_clamp_current_stat_to_max(Enums.StatType.SHIELD, Enums.StatType.MAX_SHIELD)
	_clamp_current_stat_to_max(Enums.StatType.POWER, Enums.StatType.MAX_POWER)


func _clamp_after_stat_write(stat: int) -> void:
	match stat:
		Enums.StatType.HEALTH:
			_clamp_current_stat_to_max(Enums.StatType.HEALTH, Enums.StatType.MAX_HEALTH)
		Enums.StatType.ARMOR:
			_clamp_current_stat_to_max(Enums.StatType.ARMOR, Enums.StatType.MAX_ARMOR)
		Enums.StatType.SHIELD:
			_clamp_current_stat_to_max(Enums.StatType.SHIELD, Enums.StatType.MAX_SHIELD)
		Enums.StatType.POWER:
			_clamp_current_stat_to_max(Enums.StatType.POWER, Enums.StatType.MAX_POWER)
		Enums.StatType.MAX_HEALTH:
			_clamp_current_stat_to_max(Enums.StatType.HEALTH, Enums.StatType.MAX_HEALTH)
		Enums.StatType.MAX_ARMOR:
			_clamp_current_stat_to_max(Enums.StatType.ARMOR, Enums.StatType.MAX_ARMOR)
		Enums.StatType.MAX_SHIELD:
			_clamp_current_stat_to_max(Enums.StatType.SHIELD, Enums.StatType.MAX_SHIELD)
		Enums.StatType.MAX_POWER:
			_clamp_current_stat_to_max(Enums.StatType.POWER, Enums.StatType.MAX_POWER)
		_:
			pass


func _clamp_current_stat_to_max(current_stat: int, max_stat: int) -> void:
	var max_value: int = maxi(0, get_stat(max_stat))
	var current_value: int = get_stat(current_stat)
	_set_raw_stat(base_stats, current_stat, clampi(current_value, 0, max_value))


func _set_raw_stat(storage: Dictionary, stat: int, value: int) -> void:
	storage[stat] = int(value)


func _get_raw_stat(storage: Dictionary, stat: int) -> int:
	return int(storage.get(stat, 0))
