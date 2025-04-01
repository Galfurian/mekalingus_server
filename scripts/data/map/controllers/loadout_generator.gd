# =============================================================================
# ENEMY LOADOUT GENERATION STRATEGY
# =============================================================================
#
# This system generates randomized loadouts for enemy Meks based on the current
# game difficulty, while optionally supporting predefined combat roles.
#
# Combat roles define tactical behavior archetypes (e.g., Sniper, Brawler,
# Artillery, Support), allowing the generator to build themed and strategically
# coherent loadouts. This enhances both gameplay depth and encounter diversity.
#
# ---------------------------------------------------------------------------
# AVAILABLE ROLES (PLANNED):
#
# - SNIPER:
#   Focuses on long-range, single-target precision attacks. Modules typically
#   have high range and target individual enemies without area effects.
#
# - ARTILLERY:
#   Specializes in long-range area suppression. Uses modules with large area
#   of effect (AoE), typically explosive or plasma damage types.
#
# - BRAWLER:
#   Built for close-quarters combat. Relies on short-range kinetic damage,
#   durability, and aggressive damage-reduction or regen modules.
#
# - SUPPORT:
#   Aids allies or self. Provides healing, buffs (e.g., speed, accuracy),
#   shield regeneration, or power bonuses.
#
# - DISRUPTOR:
#   Focuses on weakening enemies via debuffs â€” reducing power, movement,
#   damage output, or cooldown efficiency.
#
# - TANK:
#   Prioritizes defense and durability over offense. May include shield/armor
#   modifiers, damage reduction, and high base stats.
#
# ---------------------------------------------------------------------------
# HOW IT WORKS:
#
# 1. A Mek is selected based on difficulty tier (Light â†’ Colossal).
# 2. Items are filtered based on the Mekâ€™s available slots.
# 3. Optionally, a role is assigned. Items are filtered or scored to favor
#    those matching the role's intended behavior.
# 4. Items are ranked and added until all slots are filled.
#
# Future versions may introduce role-weighted squad composition, synergy checks,
# or role-based tactical AI behavior.
#
# =============================================================================

extends Node

const DIFFICULTY_MIN_POWER = {
	Enums.MapDifficulty.NOVICE:      250,
	Enums.MapDifficulty.CADET:       500,
	Enums.MapDifficulty.CHALLENGING: 750,
	Enums.MapDifficulty.VETERAN:     1000,
	Enums.MapDifficulty.ELITE:       1250,
	Enums.MapDifficulty.LEGENDARY:   1500,
}

const DIFFICULTY_MAX_MEK_SIZE = {
	Enums.MapDifficulty.NOVICE:      Enums.MekSize.LIGHT,
	Enums.MapDifficulty.CADET:       Enums.MekSize.MEDIUM,
	Enums.MapDifficulty.CHALLENGING: Enums.MekSize.MEDIUM,
	Enums.MapDifficulty.VETERAN:     Enums.MekSize.HEAVY,
	Enums.MapDifficulty.ELITE:       Enums.MekSize.HEAVY,
	Enums.MapDifficulty.LEGENDARY:   Enums.MekSize.COLOSSAL,
}


func generate_mek(difficulty: Enums.MapDifficulty, role: Enums.MekRole) -> Mek:
	"""
	Generates an NPC Mek with a loadout tailored to the specified role and difficulty.
	Enforces a minimum power threshold and a maximum Mek size.
	"""
	var min_power = DIFFICULTY_MIN_POWER[difficulty]
	var max_size = DIFFICULTY_MAX_MEK_SIZE[difficulty]
	# Filter Mek templates by size and estimated power potential.
	var available_meks: Array = []
	for template in TemplateManager.mek_templates.values():
		if template.size <= max_size:
			if template.evaluate_mek_template_power() >= min_power:
				available_meks.append(template)
	if available_meks.is_empty():
		push_error("No Mek templates found for difficulty: " + str(difficulty))
		return null
	# Randomly select one and build it.
	var mek_template = available_meks.pick_random()
	var mek: Mek = mek_template.build_mek()
	# Assign a role-based loadout, using the *min power as a target*, but no hard limit.
	_assign_role_based_loadout(mek, role, min_power)
	# Label the Mek.
	mek.alias = "%s (%s)" % [mek.template.mek_name, str(role)]
	return mek


func _assign_role_based_loadout(mek: Mek, role: Enums.MekRole, _min_power: int) -> void:
	"""
	Assigns a loadout by filling all Mek slots using the highest-scoring items.
	Loops through candidates until all slots are filled.
	Tracks total power and warns if the minimum power is not reached.
	"""
	mek.clear_items()
	var mek_total_power = mek.evaluate_mek_power()
	var role_scoring_function = {
		Enums.MekRole.SNIPER: _score_sniper_suitability,
		Enums.MekRole.BRAWLER: _score_brawler_suitability,
		Enums.MekRole.ARTILLERY: _score_artillery_suitability,
		Enums.MekRole.SUPPORT: _score_support_suitability,
	}[role]
	for slot_type in Enums.SlotType.values():
		var slot_count = mek.slots[slot_type]
		if slot_count <= 0:
			continue
		# Gather and score candidates.
		var candidates: Array = []
		for item in TemplateManager.item_templates.values():
			if item.slot != slot_type:
				continue
			var score = role_scoring_function.call(item)
			if score > 0.0:
				candidates.append({ "item": item, "score": score })
		if candidates.is_empty():
			push_error("  No valid items found for slot type %s." % str(slot_type))
			continue
		# Sort by descending score.
		candidates.sort_custom(func(a, b): return b["score"] < a["score"])
		var equipped = 0
		var attempts = 0
		while equipped < slot_count and attempts < 20:
			for candidate in candidates:
				if equipped >= slot_count:
					break
				var item_template = candidate["item"]
				var item = item_template.build_item()
				var item_power = item_template.evaluate_item_template_power()
				mek.add_item(item)
				mek_total_power += item_power
				equipped += 1
			attempts += 1
		if equipped == 0:
			push_error("No items were equipped in %s slots." % str(slot_type))
	# Final check
	if mek_total_power < _min_power:
		push_error("Mek %s failed to reach minimum power: %.1f < %d" % [
			mek.template.mek_name, mek_total_power, _min_power
		])

# =============================================================================
# ROLE DEFINITION SUPPORT
# =============================================================================

static func _score_sniper_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item based on how suitable it is for the SNIPER role.
	Snipers rely on long-range, high-precision, single-target damage.
	- Reward: long range, ENEMY-targeted DAMAGE effects.
	- Penalty: AREA effects, low damage.
	"""
	var score = 0.0
	for module in item.modules:
		var module_score = 0.01
		if module.module_range >= 5:
			module_score += module.module_range * 2.0
		for effect in module.effects:
			if effect.target == Enums.TargetType.ENEMY and effect.type == Enums.EffectType.DAMAGE:
				module_score += effect.amount * 0.2
			elif effect.target == Enums.TargetType.AREA:
				module_score -= 10.0
		score = max(score, module_score)
	return score


static func _score_brawler_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the BRAWLER role.
	Brawlers thrive in close-range, high-burst engagements.
	- Reward: short range (<=2), repeating effects, ENEMY-targeted DAMAGE and debuffs.
	- Penalty: long-range or passive-only utility modules.
	"""
	var score = 0.0
	for module in item.modules:
		var module_score = 0.01
		var is_close = module.module_range <= 2
		var is_repeating = module.repeats >= 2
		for effect in module.effects:
			var target = effect.target
			var type = effect.type
			var is_damaging = type == Enums.EffectType.DAMAGE
			var is_cc = type in [Enums.EffectType.SPEED_MODIFIER, Enums.EffectType.ACCURACY_MODIFIER] or str(type).begins_with("DAMAGE_REDUCTION")
			if target == Enums.TargetType.ENEMY and (is_damaging or is_cc):
				module_score += effect.amount * 0.2
				if is_close:
					module_score += 3.0
				if is_repeating:
					module_score += module.repeats * 1.5
		score = max(score, module_score)
	return score


static func _score_artillery_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the ARTILLERY role.
	Artillery prioritizes long-range AoE suppression and terrain control.
	- Reward: range >= 4, AREA-targeted DAMAGE or CONTROL effects.
	- Penalty: single-target or close-range focus.
	"""
	var score = 0.0
	for module in item.modules:
		var module_score = module.module_range * 0.30
		for effect in module.effects:
			if effect.target == Enums.TargetType.AREA and effect.radius > 0:
				if effect.type in [
					Enums.EffectType.DAMAGE,
					Enums.EffectType.DAMAGE_OVER_TIME,
					Enums.EffectType.SPEED_MODIFIER,
					Enums.EffectType.ACCURACY_MODIFIER
				]:
					module_score += (effect.amount + effect.radius * 5.0) * 0.15
		score = max(score, module_score + module.module_range)
	return score


static func _score_support_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the SUPPORT role.
	Prioritizes healing, buffs, and soft control.
	Allows moderate scoring for low-damage or debuffing weapons.
	"""
	var best_score = 0.0

	for module in item.modules:
		var module_score = 0.01

		for effect in module.effects:
			var type_str = str(effect.type)
			var target = effect.target

			var is_healing = type_str.ends_with("REPAIR") or type_str.ends_with("REGEN")
			var is_buff = type_str.ends_with("MODIFIER") and target in [Enums.TargetType.SELF, Enums.TargetType.ALLY]
			var is_enemy_debuff = type_str.ends_with("MODIFIER") and target == Enums.TargetType.ENEMY
			var is_damage = type_str == "DAMAGE" or type_str == "DAMAGE_OVER_TIME"

			# High priority support actions
			if is_healing or is_buff:
				module_score += 12.0 + effect.amount * 0.3
			elif is_enemy_debuff:
				module_score += 6.0 + abs(effect.amount) * 0.2
			# Low-priority self-defense or soft control weapons
			elif is_damage:
				if target == Enums.TargetType.ENEMY and effect.amount <= 15:
					module_score += effect.amount * 0.1  # low score for low damage
				elif target == Enums.TargetType.AREA and effect.radius > 0:
					module_score += effect.amount * 0.05 + effect.radius  # AoE is helpful

		best_score = max(best_score, module_score)

	return best_score
