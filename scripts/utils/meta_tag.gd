class_name MetaTag
extends Node


static func tag(meta: String, label: String) -> String:
	return "[url=%s]%s[/url]" % [meta, label]


static func entity_meta(entity_uuid: String) -> String:
	return "entity:%s" % entity_uuid


static func mek_meta(mek_uuid: String) -> String:
	return "mek:%s" % mek_uuid


static func structure_meta(structure_uuid: String) -> String:
	return "structure:%s" % structure_uuid


static func item_meta(item_uuid: String, entity_uuid: String = "") -> String:
	if entity_uuid.is_empty():
		return "item:%s" % item_uuid
	return "item:%s:%s" % [entity_uuid, item_uuid]


static func pos_meta(pos: Vector2i) -> String:
	return "pos:%d,%d" % [pos.x, pos.y]


static func entity_tag(entity_uuid: String, label: String) -> String:
	return tag(entity_meta(entity_uuid), label)


static func mek_tag(mek_uuid: String, label: String) -> String:
	return tag(mek_meta(mek_uuid), label)


static func structure_tag(structure_uuid: String, label: String) -> String:
	return tag(structure_meta(structure_uuid), label)


static func item_tag(item_uuid: String, label: String, entity_uuid: String = "") -> String:
	return tag(item_meta(item_uuid, entity_uuid), label)


static func pos_tag(pos: Vector2i, label: String = "") -> String:
	var text: String = label
	if text.is_empty():
		text = "(%d,%d)" % [pos.x, pos.y]
	return tag(pos_meta(pos), text)


static func parse(meta: String) -> Dictionary:
	if meta.begins_with("item:"):
		var payload: String = meta.substr(5)
		var parts: PackedStringArray = payload.split(":")
		if parts.size() == 1 and not parts[0].is_empty():
			return {
				"type": "item",
				"item_uuid": parts[0],
			}
		if parts.size() == 2 and not parts[0].is_empty() and not parts[1].is_empty():
			return {
				"type": "item",
				"entity_uuid": parts[0],
				"item_uuid": parts[1],
			}
		return {}

	if meta.begins_with("entity:"):
		var entity_uuid: String = meta.substr(7)
		if entity_uuid.is_empty():
			return {}
		return {
			"type": "entity",
			"entity_uuid": entity_uuid,
		}

	if meta.begins_with("mek:"):
		var mek_uuid: String = meta.substr(4)
		if mek_uuid.is_empty():
			return {}
		return {
			"type": "entity",
			"entity_uuid": mek_uuid,
		}

	if meta.begins_with("structure:"):
		var structure_uuid: String = meta.substr(10)
		if structure_uuid.is_empty():
			return {}
		return {
			"type": "entity",
			"entity_uuid": structure_uuid,
		}

	if meta.begins_with("pos:"):
		var coord_text: String = meta.substr(4)
		var coords: PackedStringArray = coord_text.split(",")
		if coords.size() != 2:
			return {}
		if not coords[0].is_valid_int() or not coords[1].is_valid_int():
			return {}
		return {
			"type": "pos",
			"position": Vector2i(int(coords[0]), int(coords[1])),
		}

	return {}
