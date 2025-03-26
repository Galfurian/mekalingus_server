extends Node


func _get_max_mek_size(difficulty: int) -> Enums.MekSize:
	"""
	Returns the maximum Mek size allowed based on difficulty level.
	"""
	var difficulty_size_map = {
		Enums.MapDifficulty.NOVICE: Enums.MekSize.LIGHT,
		Enums.MapDifficulty.CADET: Enums.MekSize.LIGHT,
		Enums.MapDifficulty.CHALLENGING: Enums.MekSize.MEDIUM,
		Enums.MapDifficulty.VETERAN: Enums.MekSize.HEAVY,
		Enums.MapDifficulty.ELITE: Enums.MekSize.HEAVY,
		Enums.MapDifficulty.LEGENDARY: Enums.MekSize.COLOSSAL
	}
	return difficulty_size_map.get(difficulty, Enums.MekSize.MEDIUM)


func _get_meks_by_size(min_size: Enums.MekSize, max_size: Enums.MekSize) -> Array[MekTemplate]:
	"""
	Retrieves a list of Meks within a specified size range.
	"""
	var filtered_meks: Array[MekTemplate] = []
	for mek_template in TemplateManager.mek_templates.values():
		if min_size <= mek_template.size and mek_template.size <= max_size:
			filtered_meks.append(mek_template)
	return filtered_meks


func _get_available_meks(difficulty: int) -> Array[MekTemplate]:
	"""
	Retrieves a list of Meks that match the difficulty's size constraints.
	"""
	return _get_meks_by_size(Enums.MekSize.LIGHT, _get_max_mek_size(difficulty))


func _get_items_by_category(category: Enums.SlotType) -> Array[ItemTemplate]:
	"""
	Retrieves a list of items that match the given slot category.
	"""
	var filtered_items: Array[ItemTemplate] = []
	for item_template in TemplateManager.item_templates.values():
		if item_template.slot == category:
			filtered_items.append(item_template)
	return filtered_items

func _generate_random_empty_mek(difficulty: int) -> Mek:
	"""
	Generates a random Mek based on the given difficulty.
	"""
	# First, get the list of available Meks for the given difficulty.
	var available_meks = _get_available_meks(difficulty)
	if available_meks.is_empty():
		push_error("No available Meks for difficulty: " + str(difficulty))
		return null
	# Randomly select a Mek from the list, and build it.
	var mek_template = available_meks.pick_random()
	# Build the Mek from the template.
	return mek_template.build_mek()

func _generate_random_loadout(mek: Mek):
	"""
	Randomly assigns items to a Mek based on its available slots.
	"""

	for slot_type in Enums.SlotType.values():
		# If the mek has no more room for this slot type, skip it.
		if mek.slots[slot_type] <= 0:
			continue
		# Get the list of available items for this slot type.
		var available_item_templates = _get_items_by_category(slot_type)
		# If there are no items available, skip this slot type.
		if available_item_templates.is_empty():
			continue
		# Add items to the Mek until it reaches its slot limit.
		for _ignore in range(mek.slots[slot_type]):
			var item_template = available_item_templates.pick_random()
			var item = item_template.build_item()
			mek.add_item(item)


func generate_random_enemy(difficulty: int) -> Mek:
	"""
	Generates a randomized enemy Mek based on difficulty.
	"""
	# First
	var mek = _generate_random_empty_mek(difficulty)
	if mek:
		_generate_random_loadout(mek)
		return mek
	return null
