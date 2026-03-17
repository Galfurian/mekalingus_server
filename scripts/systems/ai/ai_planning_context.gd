class_name AIPlanningContext
extends RefCounted

var source: MapCombatEntity
var game_map
var aggressiveness: float = 1.0
var turn_context: RefCounted = null

var _visible_enemies: Array[MapCombatEntity] = []
var _visible_enemies_ready: bool = false

var _all_enemies: Array[MapCombatEntity] = []
var _all_enemies_ready: bool = false

var _allies: Array[MapCombatEntity] = []
var _allies_ready: bool = false

var _offensive_modules: Array[EquippedModule] = []
var _offensive_modules_ready: bool = false

var _utility_modules: Array[EquippedModule] = []
var _utility_modules_ready: bool = false

var _reachable_tiles: Array[Vector2i] = []
var _reachable_tiles_ready: bool = false

var _squad_entities: Array[MapCombatEntity] = []
var _squad_entities_ready: bool = false
var _squad_center_cache: Vector2i = Vector2i.ZERO
var _squad_center_ready: bool = false

var _threat_cache: Dictionary = {}
var _enemy_offensive_modules_cache: Dictionary = {}


func _init(
	p_source: MapCombatEntity,
	p_game_map,
	p_aggressiveness: float,
	p_turn_context: RefCounted = null
) -> void:
	source = p_source
	game_map = p_game_map
	aggressiveness = p_aggressiveness
	turn_context = p_turn_context


func get_visible_enemies() -> Array[MapCombatEntity]:
	if _visible_enemies_ready:
		return _visible_enemies
	if turn_context:
		_visible_enemies = turn_context.get_visible_enemies(
			source, game_map.DEFAULT_DETECTION_RANGE
		)
	else:
		_visible_enemies = AIUnitQueries.get_enemies_in_range(
			game_map, source, game_map.DEFAULT_DETECTION_RANGE
		)
	_visible_enemies_ready = true
	return _visible_enemies


func get_all_enemies() -> Array[MapCombatEntity]:
	if _all_enemies_ready:
		return _all_enemies
	var scan_radius: int = AITuning.get_global_scan_radius(game_map)
	if turn_context:
		_all_enemies = turn_context.get_all_enemies(source, scan_radius)
	else:
		_all_enemies = AIUnitQueries.get_enemies_in_range(game_map, source, scan_radius)
	_all_enemies_ready = true
	return _all_enemies


func get_allies() -> Array[MapCombatEntity]:
	if _allies_ready:
		return _allies
	var scan_radius: int = AITuning.get_global_scan_radius(game_map)
	if turn_context:
		_allies = turn_context.get_allies(source, scan_radius)
	else:
		_allies = AIUnitQueries.get_allies_in_range(game_map, source, scan_radius)
	_allies_ready = true
	return _allies


func get_allies_with_self() -> Array[MapCombatEntity]:
	var allies_with_self: Array[MapCombatEntity] = [source]
	for ally: MapCombatEntity in get_allies():
		allies_with_self.append(ally)
	return allies_with_self


func get_offensive_modules() -> Array[EquippedModule]:
	if _offensive_modules_ready:
		return _offensive_modules
	_offensive_modules = AIUtils.find_matching_modules(source.combatant, true, false, false)
	_offensive_modules_ready = true
	return _offensive_modules


func get_utility_modules() -> Array[EquippedModule]:
	if _utility_modules_ready:
		return _utility_modules
	_utility_modules = AIUtils.find_matching_modules(source.combatant, false, false, false)
	_utility_modules_ready = true
	return _utility_modules


func get_reachable_tiles() -> Array[Vector2i]:
	if _reachable_tiles_ready:
		return _reachable_tiles
	_reachable_tiles = AIPathfinder.get_reachable_tiles(
		game_map, source.position, source.combatant.speed
	)
	_reachable_tiles_ready = true
	return _reachable_tiles


func get_squad_entities() -> Array[MapCombatEntity]:
	if _squad_entities_ready:
		return _squad_entities
	_squad_entities = game_map.get_owned_combat_entities(source.owner)
	_squad_entities_ready = true
	return _squad_entities


func get_squad_center(fallback: Vector2i) -> Vector2i:
	if _squad_center_ready:
		return _squad_center_cache

	var entities: Array[MapCombatEntity] = get_squad_entities()
	if entities.is_empty():
		_squad_center_cache = fallback
		_squad_center_ready = true
		return _squad_center_cache

	var sum_x: int = 0
	var sum_y: int = 0
	for entity: MapCombatEntity in entities:
		sum_x += entity.position.x
		sum_y += entity.position.y

	_squad_center_cache = Vector2i(
		int(round(float(sum_x) / entities.size())), int(round(float(sum_y) / entities.size()))
	)
	_squad_center_ready = true
	return _squad_center_cache


func get_threat(tile: Vector2i) -> float:
	var key: String = _tile_key(tile)
	if _threat_cache.has(key):
		return _threat_cache[key]

	var enemy_modules_cache: Dictionary = {}
	for enemy: MapCombatEntity in get_all_enemies():
		enemy_modules_cache[enemy.combatant.uuid] = _get_enemy_offensive_modules(enemy)

	var threat_score: float = AIThreatEvaluator.get_threat_level_from_enemy_cache(
		tile, get_all_enemies(), enemy_modules_cache
	)

	_threat_cache[key] = threat_score
	return threat_score


func _get_enemy_offensive_modules(enemy: MapCombatEntity) -> Array[EquippedModule]:
	var enemy_key: String = enemy.combatant.uuid
	if _enemy_offensive_modules_cache.has(enemy_key):
		return _enemy_offensive_modules_cache[enemy_key]

	var modules: Array[EquippedModule] = []
	if turn_context:
		modules = turn_context.get_offensive_modules_for(enemy)
	else:
		modules = AIUtils.find_matching_modules(enemy.combatant, true, false, false)
	_enemy_offensive_modules_cache[enemy_key] = modules
	return modules


func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
