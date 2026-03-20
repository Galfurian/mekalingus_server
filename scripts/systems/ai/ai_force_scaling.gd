class_name AIForceScaling
extends RefCounted

const SIZE_SCALE_FACTORS: Dictionary = {
	Enums.EntitySize.LIGHT: 0.4,
	Enums.EntitySize.MEDIUM: 0.6,
	Enums.EntitySize.HEAVY: 0.8,
	Enums.EntitySize.COLOSSAL: 1.0,
}

static func get_entity_size_scale(entity: CombatEntity) -> float:
	if entity is Mek:
		var mek: Mek = entity as Mek
		return SIZE_SCALE_FACTORS.get(mek.template.size, 0.6)
	if entity is Structure:
		var structure: Structure = entity as Structure
		return SIZE_SCALE_FACTORS.get(structure.template.size, 0.6)
	# Fallback for unknown entity types.
	return 0.6

static func get_scaled_combat_power(entity: CombatEntity) -> float:
	if not entity:
		return 0.0
	var scale: float = get_entity_size_scale(entity)
	return CombatPowerEvaluator.evaluate(entity) * scale
