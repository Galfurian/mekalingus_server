extends ScrollContainer

@onready var entity_info: RichTextLabel = $EntityInfo


func clear() -> void:
	entity_info.clear()


func display_combat_entity(map_entity: MapCombatEntity) -> void:
	if not is_instance_valid(map_entity):
		clear()
		return

	var actor: CombatActor = map_entity.combatant
	var text: String = "[center][b]" + _combatant_name(actor) + "[/b][/center]\n"

	if is_instance_of(map_entity.owner, PlayerOwned):
		text += "Player       : " + map_entity.owner.player.player_name + "\n"
	elif is_instance_of(map_entity.owner, NPCOwned):
		text += "NPC          : " + map_entity.owner.npc_name + "\n"

	text += "Clan         : " + map_entity.owner.clan.clan_name + "\n"
	text += "Combat Power : " + str(actor.evaluate_combat_power()) + "\n"
	text += "Size         : "
	text += Utils.enum_to_string(Enums.EntitySize, actor.template.size) + "\n"

	text += "Health       : " + UIColor.apply("health", "%3d" % actor.health) + " / "
	text += UIColor.apply("health", "%3d" % actor.max_health)
	if actor.health_generation > 0:
		text += " [" + UIColor.apply("health", "%3d" % actor.health_generation) + "]"
	text += "\n"

	text += "Armor        : " + UIColor.apply("armor", "%3d" % actor.armor) + " / "
	text += UIColor.apply("armor", "%3d" % actor.max_armor)
	if actor.armor_generation > 0:
		text += " ["
		text += UIColor.apply("armor_generation", "%3d" % actor.armor_generation)
		text += "]"
	text += "\n"

	text += "Shield       : " + UIColor.apply("shield", "%3d" % actor.shield) + " / "
	text += UIColor.apply("shield", "%3d" % actor.max_shield)
	if actor.shield_generation > 0:
		text += " ["
		text += UIColor.apply("shield_generation", "%3d" % actor.shield_generation)
		text += "]"
	text += "\n"

	text += "Power        : " + UIColor.apply("power", "%3d" % actor.power) + " / "
	text += UIColor.apply("power", "%3d" % actor.max_power)
	if actor.power_generation > 0:
		text += " ["
		text += UIColor.apply("power_generation", "%3d" % actor.power_generation)
		text += "]"
	text += "\n"

	text += "Speed        : " + UIColor.apply("speed", "%3d" % actor.speed) + "\n"
	text += _build_active_effects_section(actor)
	text += "[center][b]Damage Reduction[/b][/center]\n"
	text += _build_damage_reduction_line(actor)
	entity_info.clear()
	entity_info.append_text(text)


func _build_active_effects_section(actor: CombatActor) -> String:
	var section := "[center][b]Active Effects[/b][/center]\n"
	if not actor.active_effect_manager or actor.active_effect_manager.active_effects.is_empty():
		return section + "[center][i]None[/i][/center]\n"

	for active: ActiveEffect in actor.active_effect_manager.active_effects:
		section += _build_active_effect_line(active) + "\n"

	return section


func _build_active_effect_line(active: ActiveEffect) -> String:
	var effect_label: String = active.effect.get_effect_type_label()
	var amount_text: String = "%+d" % active.effect.amount
	var line := "- "
	line += UIColor.apply("effect_type", effect_label)
	line += " " + UIColor.apply("effect_amount", amount_text)

	if active.effect.is_damage() or active.effect.is_dot():
		var damage_type_name: String = Utils.enum_to_string(
			Enums.DamageType,
			active.effect.damage_type
		)
		line += " " + UIColor.apply("damage_type", "[" + damage_type_name + "]")

	if active.remaining_duration > 0:
		line += " (" + str(active.remaining_duration) + "t)"

	if active.effect.chance < 100:
		line += " @" + str(active.effect.chance) + "%"

	return line


func _build_damage_reduction_line(actor: CombatActor) -> String:
	var icon_map := {
		"KINETIC": "res://assets/tileset/ui/damage/damage_kinetic.png",
		"ENERGY": "res://assets/tileset/ui/damage/damage_energy.png",
		"EXPLOSIVE": "res://assets/tileset/ui/damage/damage_explosive.png",
		"PLASMA": "res://assets/tileset/ui/damage/damage_plasma.png",
		"CORROSIVE": "res://assets/tileset/ui/damage/damage_corrosive.png",
		"ALL": "res://assets/tileset/ui/damage/damage_all.png",
	}
	var values := {
		"ALL": actor.damage_reduction_all,
		"KINETIC": actor.damage_reduction_kinetic,
		"ENERGY": actor.damage_reduction_energy,
		"EXPLOSIVE": actor.damage_reduction_explosive,
		"PLASMA": actor.damage_reduction_plasma,
		"CORROSIVE": actor.damage_reduction_corrosive,
	}
	var hint_map := {
		"ALL": "All types of damage reduction.",
		"KINETIC": "Kinetic damage reduction.",
		"ENERGY": "Energy damage reduction.",
		"EXPLOSIVE": "Explosive damage reduction.",
		"PLASMA": "Plasma damage reduction.",
		"CORROSIVE": "Corrosive damage reduction.",
	}

	var line := "[center]"
	for key in ["ALL", "KINETIC", "ENERGY", "EXPLOSIVE", "PLASMA", "CORROSIVE"]:
		line += "[hint=" + hint_map[key] + "]"
		line += "[img={16}x{16}]" + icon_map[key] + "[/img] "
		var value: int = int(values[key])
		line += UIColor.apply("damage_reduction", "%+d" % value) + "[/hint]  "
	return line.strip_edges() + "[/center]\n"


func _combatant_name(actor: CombatActor) -> String:
	if not actor:
		return "Unknown"
	if actor.has_method("get_mek_name"):
		return str(actor.call("get_mek_name"))
	if actor.has_method("get_structure_name"):
		return str(actor.call("get_structure_name"))
	if not actor.alias.is_empty():
		return actor.alias
	return actor.uuid
