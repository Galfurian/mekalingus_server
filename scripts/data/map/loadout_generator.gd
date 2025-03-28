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

# Describes different combat roles a Mek can be built for.
enum MekRole {
	BRAWLER,
	SNIPER,
	ARTILLERY,
	SUPPORT,
}

const DIFFICULTY_POWER_RANGES = {
	Enums.MapDifficulty.NOVICE:      { "min": 250, "max": 750 },
	Enums.MapDifficulty.CADET:       { "min": 500, "max": 1000 },
	Enums.MapDifficulty.CHALLENGING: { "min": 750, "max": 1250 },
	Enums.MapDifficulty.VETERAN:     { "min": 1000, "max": 1500 },
	Enums.MapDifficulty.ELITE:       { "min": 1250, "max": 1750 },
	Enums.MapDifficulty.LEGENDARY:   { "min": 1500, "max": 2250 },
}

const DIFFICULTY_MEK_SIZE = {
	Enums.MapDifficulty.NOVICE: Enums.MekSize.LIGHT,
	Enums.MapDifficulty.CADET: Enums.MekSize.LIGHT,
	Enums.MapDifficulty.CHALLENGING: Enums.MekSize.MEDIUM,
	Enums.MapDifficulty.VETERAN: Enums.MekSize.HEAVY,
	Enums.MapDifficulty.ELITE: Enums.MekSize.HEAVY,
	Enums.MapDifficulty.LEGENDARY: Enums.MekSize.COLOSSAL
}


func generate_balanced_enemy(difficulty: int, role: MekRole) -> Mek:
	"""
	Generates an NPC Mek with a loadout tailored to the specified role and balanced
	against a difficulty-based power range.
	@param difficulty The difficulty level, based on MapDifficulty.
	@param role The intended combat role (e.g., BRAWLER, SNIPER).
	@return A Mek instance equipped with a role-appropriate, balanced loadout.
	"""
	var max_size := _get_max_mek_size(difficulty)
	var available_meks := _get_meks_by_size(Enums.MekSize.LIGHT, max_size)
	if available_meks.is_empty():
		push_error("No available Meks for difficulty: " + str(difficulty))
		return null

	# Randomly select a candidate Mek template.
	var mek_template = available_meks.pick_random()
	var mek = mek_template.build_mek()

	# Get the power range for this difficulty.
	var power_range = DIFFICULTY_POWER_RANGES.get(difficulty, {"min": 0, "max": 9999})
	var attempts := 10

	while attempts > 0:
		_assign_role_based_loadout(mek, role, power_range)
		var total_power :float= mek.evaluate_mek_power()
		if power_range["min"] <= total_power and total_power <= power_range["max"]:
			return mek
		attempts -= 1

	# Fallback: return last attempted Mek even if it's out of range.
	return mek


func _assign_role_based_loadout(mek: Mek, role: MekRole, power_range: Dictionary) -> void:
	"""
	Assigns a loadout to the given Mek based on its role and a desired power range.
	It scores items by how well they fit the role, then greedily adds them until
	the Mek reaches the target power window.
	"""
	var min_power = power_range.get("min", 0.0)
	var max_power = power_range.get("max", 9999.0)

	# Clear current items.
	mek.clear_items()

	# Function map to get role scoring function.
	var role_scorers = {
		MekRole.SNIPER: _score_sniper_suitability,
		MekRole.BRAWLER: _score_brawler_suitability,
		MekRole.ARTILLERY: _score_artillery_suitability,
		MekRole.SUPPORT: _score_support_suitability,
	}

	# Loop over each slot type.
	for slot_type in Enums.SlotType.values():
		var slot_count := mek.slots[slot_type]
		if slot_count <= 0:
			continue

		# Gather candidates and score them based on role.
		var scored_candidates: Array = []
		for item in TemplateManager.item_templates.values():
			if item.slot != slot_type:
				continue
			var score :float= role_scorers[role].call(item)
			if score > 0.0:
				scored_candidates.append({ "item": item, "score": score })

		# Sort by descending score.
		scored_candidates.sort_custom(func(a, b): return b["score"] <= a["score"])

		# Try to equip up to slot_count items without breaching max power.
		for i in range(min(slot_count, scored_candidates.size())):
			var item_template = scored_candidates[i]["item"]
			var item_instance = item_template.build_item()
			mek.add_item(item_instance)

			var mek_total_power :float= mek.evaluate_mek_power()
			if mek_total_power > max_power:
				# Undo the item if it breaches max power.
				mek.remove_item(item_instance)
				GameServer.free_uuid(item_instance.uuid)
				break

	# Final power evaluation.
	var total_power := mek.evaluate_mek_power()
	var status := ""
	if total_power < min_power:
		status = "❌ UNDERPOWERED"
	elif total_power > max_power:
		status = "❌ OVERPOWERED"
	else:
		status = "✅ WITHIN RANGE"

	print("[LOADOUT] Role:", MekRole.keys()[role], "Power:", total_power, status)


# =============================================================================
# FILTERING FUNCTIONS
# =============================================================================

func _get_max_mek_size(difficulty: int) -> Enums.MekSize:
	"""
	Returns the maximum Mek size allowed based on difficulty level.
	"""
	return DIFFICULTY_MEK_SIZE.get(difficulty, Enums.MekSize.MEDIUM)

func _get_meks_by_size(min_size: Enums.MekSize, max_size: Enums.MekSize) -> Array[MekTemplate]:
	"""
	Retrieves a list of Meks within a specified size range.
	"""
	var filtered_meks: Array[MekTemplate] = []
	for mek_template in TemplateManager.mek_templates.values():
		if min_size <= mek_template.size and mek_template.size <= max_size:
			filtered_meks.append(mek_template)
	return filtered_meks

# =============================================================================
# ROLE DEFINITION SUPPORT
# =============================================================================
func _score_sniper_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item based on how suitable it is for the SNIPER role.
	Snipers rely on long-range, high-precision, single-target damage.
	- Reward: long range, ENEMY-targeted DAMAGE effects.
	- Penalty: AREA effects, low damage.
	"""
	var score := 0.0
	for module in item.modules:
		var module_score := 0.0
		if module.module_range >= 5:
			module_score += module.module_range * 2.0
		for effect in module.effects:
			if effect.target == Enums.TargetType.ENEMY and effect.type == Enums.EffectType.DAMAGE:
				module_score += effect.amount * 0.2
			elif effect.target == Enums.TargetType.AREA:
				module_score -= 10.0
		score = max(score, module_score)
	return score


func _score_brawler_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the BRAWLER role.
	Brawlers thrive in close-range, high-burst engagements.
	- Reward: short range (<=2), repeating effects, ENEMY-targeted DAMAGE and debuffs.
	- Penalty: long-range or passive-only utility modules.
	"""
	var score := 0.0
	for module in item.modules:
		var module_score := 0.0
		var is_close := module.module_range <= 2
		var is_repeating := module.repeats >= 2
		for effect in module.effects:
			var target := effect.target
			var type := effect.type
			var is_damaging := type == Enums.EffectType.DAMAGE
			var is_cc := type in [Enums.EffectType.SPEED_MODIFIER, Enums.EffectType.ACCURACY_MODIFIER] or str(type).begins_with("DAMAGE_REDUCTION")
			if target == Enums.TargetType.ENEMY and (is_damaging or is_cc):
				module_score += effect.amount * 0.2
				if is_close:
					module_score += 3.0
				if is_repeating:
					module_score += module.repeats * 1.5
		score = max(score, module_score)
	return score


func _score_artillery_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the ARTILLERY role.
	Artillery prioritizes long-range AoE suppression and terrain control.
	- Reward: range >= 4, AREA-targeted DAMAGE or CONTROL effects.
	- Penalty: single-target or close-range focus.
	"""
	var score := 0.0
	for module in item.modules:
		if module.module_range < 4:
			continue
		var module_score := 0.0
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


func _score_support_suitability(item: ItemTemplate) -> float:
	"""
	Scores an item for the SUPPORT role.
	Support units provide healing, buffs, or non-lethal debuffs.
	- Reward: REPAIR, REGEN, MODIFIER effects to SELF or ALLY.
	- Also valid: debuffs to ENEMY that do not deal direct damage.
	- Penalty: pure DPS tools.
	"""
	var score := 0.0
	for module in item.modules:
		var module_score := 0.0
		for effect in module.effects:
			var type_str := str(effect.type)
			var target := effect.target
			var is_healing := type_str.ends_with("REPAIR") or type_str.ends_with("REGEN")
			var is_buff := type_str.ends_with("MODIFIER") and target in [Enums.TargetType.SELF, Enums.TargetType.ALLY]
			var is_enemy_debuff := type_str.ends_with("MODIFIER") and target == Enums.TargetType.ENEMY
			if is_healing or is_buff:
				module_score += 10.0 + effect.amount * 0.2
			elif is_enemy_debuff:
				module_score += 5.0 + abs(effect.amount) * 0.15
		score = max(score, module_score)
	return score
