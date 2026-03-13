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
	text += "[center][b]Damage Reduction[/b][/center]\n"
	text += _build_damage_reduction_line(actor)
	entity_info.clear()
	entity_info.append_text(text)


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
