extends Node2D

# =============================================================================
# CONSTANTS
# =============================================================================

const MAJOR_GRID_COLOR = Color(0.2, 0.2, 0.2, 0.5)
const MAJOR_GRID_SIZE = 3
# Constants for border configuration
const BORDER_WIDTH = 1
const BORDER_COLOR = Color(0.2, 0.2, 0.2, 1.0)
const AI_MOVE_LINE_COLOR = Color(0.2, 0.9, 1.0, 0.85)
const AI_MOVE_DOT_COLOR = Color(0.1, 0.95, 0.8, 0.95)
const AI_ATTACK_ARC_COLOR = Color(1.0, 0.4, 0.25, 0.9)
const AI_ATTACK_TARGET_DOT_COLOR = Color(1.0, 0.25, 0.25, 0.95)
const AI_FRIENDLY_ARC_COLOR = Color(0.3, 1.0, 0.3, 0.9)
const AI_FRIENDLY_TARGET_DOT_COLOR = Color(0.5, 1.0, 0.5, 0.95)
const AI_LINE_WIDTH = 3.0
const AI_SCORE_LABEL_COLOR = Color(1.0, 1.0, 1.0, 0.92)
const AI_SCORE_LABEL_FONT_SIZE = 12
const AI_TRACE_LABEL_COLOR = Color(0.9, 0.95, 1.0, 0.9)
const AI_TRACE_LABEL_FONT_SIZE = 11

# =============================================================================
# VARIABLES
# =============================================================================

var game_map: GameMap
var grid_size: int
var sector_size: int
var padding_tiles: int
var selected_entity: MapEntity
var ai_overlay_enabled: bool = false

# Map texture and shader for posterization effect.
var tile_resolution: int = 6
var map_texture: ImageTexture
var posterization_shader: Shader = preload("res://shaders/posterization.gdshader")
var map_material: ShaderMaterial = ShaderMaterial.new()

# =============================================================================
# INITIALIZATION and CLEANUP
# =============================================================================


func setup(p_game_map: GameMap, p_grid_size: int, p_sector_size: int, p_padding_tiles: int):
	game_map = p_game_map
	grid_size = p_grid_size
	sector_size = p_sector_size
	padding_tiles = p_padding_tiles
	if not game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.connect(_on_turn_ended)
	generate_map_texture()
	queue_redraw()


func clear() -> void:
	if game_map and game_map.turn_manager.on_turn_ended.is_connected(_on_turn_ended):
		game_map.turn_manager.on_turn_ended.disconnect(_on_turn_ended)

	game_map = null
	grid_size = 0
	sector_size = 0
	padding_tiles = 0
	selected_entity = null

	queue_redraw()


func set_selected_entity(entity: MapEntity):
	"""Adds a highlighted cell at the given position."""
	selected_entity = entity
	queue_redraw()


func deselect_entity():
	if selected_entity:
		selected_entity = null
		queue_redraw()


func set_ai_overlay_enabled(enabled: bool) -> void:
	ai_overlay_enabled = enabled
	queue_redraw()


func get_draw_offset() -> Vector2:
	# Offset by the full outer padding in each direction.
	return Vector2(padding_tiles * grid_size, padding_tiles * grid_size)


func to_grid_position(map_position: Vector2) -> Vector2:
	# Offset by one sector in each direction
	return Vector2(map_position.x * grid_size, map_position.y * grid_size) + get_draw_offset()


func generate_map_texture():
	var img_width: int = game_map.map_width * tile_resolution
	var img_height: int = game_map.map_height * tile_resolution
	var map_image: Image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)

	for y in range(game_map.map_height):
		for x in range(game_map.map_width):
			var tile_color: Color = game_map.get_tile_color(x, y)
			var tile_rect: Rect2i = Rect2i(
				x * tile_resolution,
				y * tile_resolution,
				tile_resolution,
				tile_resolution,
			)
			map_image.fill_rect(tile_rect, tile_color)

	map_texture = ImageTexture.create_from_image(map_image)
	queue_redraw()


func _on_turn_ended(_turn_number: int):
	# Called when the turn ends
	queue_redraw()


func _ready():
	# Forza il rendering a non sfumare i pixel quando scala
	# texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 1. Force linear filtering so the texture gets blurred when scaled
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# 2. Setup and apply the shader material to this node
	map_material.shader = posterization_shader
	self.material = map_material


func _draw():
	if not game_map:
		return
	# Calculate the offset for drawing the map texture, accounting for padding.
	var offset: Vector2 = get_draw_offset()
	# Calculate the destination rectangle for drawing the map texture, accounting for padding.
	var dest_rect: Rect2 = Rect2(
		offset.x,
		offset.y,
		game_map.map_width * grid_size,
		game_map.map_height * grid_size,
	)
	# Draw the texture; the ShaderMaterial applied to this node
	# will automatically process whatever is drawn here.
	draw_texture_rect(map_texture, dest_rect, false)
	assert(game_map.map_width == game_map.map_height, "Map is not square!")
	# Draw grid overlay (including extended grid lines).
	for i in range(game_map.map_width + padding_tiles + padding_tiles):
		if (i % sector_size) == 0:
			var x_start = Vector2(i * grid_size, 0)
			var x_end = Vector2(
				i * grid_size, (game_map.map_height + padding_tiles * 2) * grid_size
			)
			draw_line(x_start, x_end, MAJOR_GRID_COLOR, MAJOR_GRID_SIZE)
			var y_start = Vector2(0, i * grid_size)
			var y_end = Vector2((game_map.map_width + padding_tiles * 2) * grid_size, i * grid_size)
			draw_line(y_start, y_end, MAJOR_GRID_COLOR, MAJOR_GRID_SIZE)

	if ai_overlay_enabled:
		_draw_ai_overlay()


func _draw_ai_overlay() -> void:
	if not game_map or not game_map.ai_controller:
		return

	for unit: MapCombatEntity in game_map.npc_units.values():
		if not unit or not unit.active or unit.combatant.is_dead():
			continue
		_draw_ai_plan_for_entity(unit)

	for structure: MapStructure in game_map.structures.values():
		if not structure or not structure.active or structure.combatant.is_dead():
			continue
		_draw_ai_plan_for_entity(structure)


func _draw_ai_plan_for_entity(entity: MapCombatEntity) -> void:
	var plan: AIPlan = game_map.ai_controller.get_current_plan(entity)
	if not plan or not plan.is_valid() or plan.is_complete():
		return

	var source_center: Vector2 = _tile_center(entity.position)
	_draw_plan_score_label(source_center, plan)

	if selected_entity and selected_entity == entity:
		_draw_selected_trace_labels(source_center, plan)

	if plan.intent == AIPlan.Intent.RETREAT:
		if plan.destination == Vector2i.ZERO or plan.destination == entity.position:
			return
		var destination_center: Vector2 = _tile_center(plan.destination)
		draw_line(source_center, destination_center, AI_MOVE_LINE_COLOR, AI_LINE_WIDTH)
		draw_circle(destination_center, maxf(3.0, grid_size * 0.16), AI_MOVE_DOT_COLOR)
		return

	if (
		(plan.intent == AIPlan.Intent.ATTACK or plan.intent == AIPlan.Intent.SUPPORT)
		and plan.target
	):
		var target_center: Vector2 = _tile_center(plan.target.position)
		var is_enemy_target: bool = game_map.is_enemy_of(entity, plan.target)
		var arc_color: Color
		var dot_color: Color
		if is_enemy_target:
			arc_color = AI_ATTACK_ARC_COLOR
			dot_color = AI_ATTACK_TARGET_DOT_COLOR
		else:
			arc_color = AI_FRIENDLY_ARC_COLOR
			dot_color = AI_FRIENDLY_TARGET_DOT_COLOR
		if _plan_target_in_range(plan):
			_draw_attack_arc(source_center, target_center, arc_color)
			draw_circle(target_center, maxf(3.0, grid_size * 0.15), dot_color)
			return

		var next_step: Vector2i = _compute_approach_tile(plan)
		if next_step == Vector2i.ZERO or next_step == entity.position:
			return
		var next_center: Vector2 = _tile_center(next_step)
		draw_line(source_center, next_center, AI_MOVE_LINE_COLOR, AI_LINE_WIDTH)
		draw_circle(next_center, maxf(3.0, grid_size * 0.16), AI_MOVE_DOT_COLOR)


func _compute_approach_tile(plan: AIPlan) -> Vector2i:
	if not plan.target or not plan.equipped_module:
		return Vector2i.ZERO

	var source: MapCombatEntity = plan.source
	var module_range: int = (
		plan.equipped_module.module.module_range + source.combatant.range_modifier
	)
	var movement_speed: int = source.combatant.speed
	var is_enemy_target: bool = game_map.is_enemy_of(source, plan.target)

	AIPathfinder.set_reserved_tiles({})
	if is_enemy_target:
		var min_range: int = AIUtils.get_offensive_min_range(module_range)
		return AIPathfinder.find_best_attack_tile(
			game_map, source, plan.target, min_range, module_range, movement_speed
		)

	return AIPathfinder.find_closest_reachable_tile(
		game_map, source, plan.target, 0, module_range, movement_speed
	)


func _draw_selected_trace_labels(source_center: Vector2, plan: AIPlan) -> void:
	if not plan.decision_trace:
		return

	var font: Font = ThemeDB.fallback_font
	if not font:
		return

	var lines: Array[String] = plan.decision_trace.format_panel_lines()
	if lines.is_empty():
		return

	var y_offset: float = 10.0
	for line: String in lines:
		draw_string(
			font,
			source_center + Vector2(6.0, y_offset),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			AI_TRACE_LABEL_FONT_SIZE,
			AI_TRACE_LABEL_COLOR,
		)
		y_offset += float(AI_TRACE_LABEL_FONT_SIZE + 2)


func _plan_target_in_range(plan: AIPlan) -> bool:
	if not plan.target or not plan.equipped_module:
		return false

	var source: MapCombatEntity = plan.source
	var module_range: int = (
		plan.equipped_module.module.module_range + source.combatant.range_modifier
	)
	var min_range: int = 0
	if game_map.is_enemy_of(source, plan.target):
		min_range = AIUtils.get_offensive_min_range(module_range)

	var distance: float = source.position.distance_to(plan.target.position)
	return source == plan.target or (distance >= min_range and distance <= module_range)


func _draw_attack_arc(start: Vector2, end: Vector2, color: Color) -> void:
	var direction: Vector2 = end - start
	if direction.length() <= 0.01:
		return

	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
	var arc_height: float = clamp(direction.length() * 0.25, 10.0, 50.0)
	var control: Vector2 = (start + end) * 0.5 + normal * arc_height

	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 16
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var inv_t: float = 1.0 - t
		var point: Vector2 = inv_t * inv_t * start + 2.0 * inv_t * t * control + t * t * end
		points.append(point)

	draw_polyline(points, color, AI_LINE_WIDTH, true)


func _tile_center(tile: Vector2i) -> Vector2:
	var origin: Vector2 = to_grid_position(tile)
	return origin + Vector2(grid_size * 0.5, grid_size * 0.5)


func _draw_plan_score_label(source_center: Vector2, plan: AIPlan) -> void:
	var font: Font = ThemeDB.fallback_font
	if not font:
		return

	var intent_name: String = AIPlan.Intent.keys()[plan.intent]
	var label: String = "%s %.1f" % [intent_name, plan.score]
	var label_pos: Vector2 = source_center + Vector2(6.0, -6.0)
	draw_string(
		font,
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		AI_SCORE_LABEL_FONT_SIZE,
		AI_SCORE_LABEL_COLOR,
	)
