class_name WorldView
extends Node2D

const MOUSE_SCENE: PackedScene = preload("res://scenes/mouse/mouse.tscn")
const GAME_FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Full.ttf")
const RESIDENT_MOUSE_TEXTURE: Texture2D = preload("res://assets/mouse/sprites/field_mouse-v2.png")
const STAGE_BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/background/stages/old_kitchen.jpg"),
	preload("res://assets/background/stages/food_storage.jpg"),
	preload("res://assets/background/stages/convenience_store.jpg"),
	preload("res://assets/background/stages/restaurant.jpg"),
	preload("res://assets/background/stages/cheese_factory.jpg")
]
const STAGE_HOLE_ANCHORS: Array[Vector2] = [
	Vector2(205.0, 456.0),
	Vector2(120.0, 500.0),
	Vector2(205.0, 495.0),
	Vector2(155.0, 495.0),
	Vector2(215.0, 540.0)
]
const STAGE_RESOURCE_ANCHORS: Array[Vector2] = [
	Vector2(1110.0, 470.0),
	Vector2(1115.0, 475.0),
	Vector2(1100.0, 490.0),
	Vector2(1110.0, 485.0),
	Vector2(1050.0, 545.0)
]
static var STAGE_ROUTE_CONTROLS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(390.0, 470.0), Vector2(700.0, 430.0), Vector2(930.0, 455.0)]),
	PackedVector2Array([Vector2(350.0, 490.0), Vector2(650.0, 440.0), Vector2(930.0, 455.0)]),
	PackedVector2Array([Vector2(370.0, 500.0), Vector2(650.0, 450.0), Vector2(920.0, 470.0)]),
	PackedVector2Array([Vector2(360.0, 520.0), Vector2(650.0, 455.0), Vector2(910.0, 475.0)]),
	PackedVector2Array([Vector2(390.0, 555.0), Vector2(650.0, 520.0), Vector2(890.0, 535.0)])
]
const MAX_LANE_ROWS: int = 7
const MAX_VISIBLE_WORK_GROUPS: int = 3
const REWARD_FONT_SIZE: int = 22
const REWARD_SIDE_MARGIN: float = 24.0
const REWARD_TOP_MARGIN: float = 165.0
const REWARD_BOTTOM_MARGIN: float = 205.0
const SHOW_ROUTE_DEBUG: bool = false

var hole_position: Vector2 = Vector2.ZERO
var resource_position: Vector2 = Vector2.ZERO
var _mouse_nodes: Array[GatheringMouse] = []
var _effects: Array[Dictionary] = []
var _stage_color: Color = Color("#352a3b")
var _route_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	EventBus.mouse_count_changed.connect(_on_mouse_count_changed)
	EventBus.stage_changed.connect(_on_stage_changed)
	EventBus.golden_cheese_changed.connect(_on_golden_cheese_changed)
	_update_layout()
	_rebuild_mice(GameManager.mouse_count)
	_on_stage_changed(GameManager.current_stage_index)


func _process(delta: float) -> void:
	var index: int = _effects.size() - 1
	while index >= 0:
		var effect: Dictionary = _effects[index]
		var remaining: float = _dictionary_float(effect, "remaining", 0.0) - delta
		if remaining <= 0.0:
			_effects.remove_at(index)
		else:
			effect["remaining"] = remaining
			var effect_position: Vector2 = _dictionary_vector2(effect, "position", Vector2.ZERO)
			effect["position"] = effect_position + Vector2(0.0, -24.0 * delta)
			_effects[index] = effect
		index -= 1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			GameManager.activate_click_boost()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			GameManager.activate_click_boost()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_draw_stage_background(viewport_size)
	_draw_atmosphere(viewport_size)
	if GameManager.current_stage_index < STAGE_BACKGROUNDS.size():
		_draw_embedded_hole_progress()
		_draw_resident_mice()
	if SHOW_ROUTE_DEBUG:
		draw_line(hole_position, resource_position, Color(1.0, 0.82, 0.42, 0.28), 3.0, true)
		for marker_index: int in range(1, 8):
			var marker_position: Vector2 = hole_position.lerp(
				resource_position,
				float(marker_index) / 8.0
			)
			draw_circle(marker_position, 3.0, Color(1.0, 0.9, 0.56, 0.48))

	_draw_mouse_hole()
	_draw_cheese_resource()

	for effect: Dictionary in _effects:
		var effect_position: Vector2 = _dictionary_vector2(effect, "position", Vector2.ZERO)
		var amount: int = _dictionary_int(effect, "amount", 0)
		var alpha: float = clampf(_dictionary_float(effect, "remaining", 0.0), 0.0, 1.0)
		var reward_text: String = "+%s 치즈" % _format_reward_amount(amount)
		var text_width: float = GAME_FONT.get_string_size(
			reward_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			REWARD_FONT_SIZE
		).x
		effect_position = _clamp_reward_position(effect_position, text_width, viewport_size)
		draw_string(
			GAME_FONT,
			effect_position,
			reward_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			REWARD_FONT_SIZE,
			Color(1.0, 0.86, 0.28, alpha)
		)


func _draw_stage_background(viewport_size: Vector2) -> void:
	if GameManager.current_stage_index < STAGE_BACKGROUNDS.size():
		var background: Texture2D = STAGE_BACKGROUNDS[GameManager.current_stage_index]
		var source_rect: Rect2 = _get_background_source_rect(background, viewport_size)
		draw_texture_rect_region(
			background,
			Rect2(Vector2.ZERO, viewport_size),
			source_rect
		)
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.03, 0.02, 0.05, 0.18))
	else:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), _stage_color)
		var floor_top: float = viewport_size.y * 0.67
		draw_rect(
			Rect2(0.0, floor_top, viewport_size.x, viewport_size.y - floor_top),
			Color("#211b26")
		)


func _draw_atmosphere(viewport_size: Vector2) -> void:
	var elapsed: float = float(Time.get_ticks_msec()) * 0.001
	var atmosphere_color: Color = Color("#ffd67a")
	if GameManager.current_stage_index == 1:
		atmosphere_color = Color("#a9d8ff")
	elif GameManager.current_stage_index >= 2:
		atmosphere_color = Color("#75f4e8")
	for index: int in range(14):
		var seed_value: float = float(index) * 81.7
		var x_value: float = fposmod(seed_value + elapsed * (4.0 + float(index % 3)), viewport_size.x)
		var y_value: float = 175.0 + fposmod(seed_value * 1.9, maxf(80.0, viewport_size.y - 390.0))
		var pulse: float = 0.18 + sin(elapsed * 1.4 + float(index)) * 0.07
		draw_circle(Vector2(x_value, y_value), 1.5 + float(index % 2), Color(
			atmosphere_color.r,
			atmosphere_color.g,
			atmosphere_color.b,
			pulse
		))


func _draw_mouse_hole() -> void:
	if GameManager.current_stage_index < STAGE_BACKGROUNDS.size():
		return
	var hole_tier: int = VisualProgression.hole_tier(GameManager.hole_level)
	var hole_scale: float = 1.0 + minf(float(GameManager.hole_level - 1) * 0.07, 0.55)
	draw_circle(hole_position + Vector2(0.0, 10.0), 62.0 * hole_scale, Color(0.07, 0.04, 0.08, 0.78))
	draw_circle(hole_position + Vector2(0.0, 12.0), 43.0 * hole_scale, Color(0.02, 0.015, 0.025, 0.9))
	draw_arc(hole_position + Vector2(0.0, 10.0), 64.0 * hole_scale, PI, TAU, 28, Color("#8b6849"), 8.0, true)
	if hole_tier >= 1:
		draw_line(hole_position + Vector2(-52.0, 50.0), hole_position + Vector2(-52.0, -20.0), Color("#a7794d"), 8.0, true)
		draw_line(hole_position + Vector2(52.0, 50.0), hole_position + Vector2(52.0, -20.0), Color("#a7794d"), 8.0, true)
	if hole_tier >= 2:
		draw_rect(Rect2(hole_position + Vector2(-70.0, 48.0), Vector2(140.0, 8.0)), Color("#c09155"))
		for item_index: int in range(4):
			draw_circle(hole_position + Vector2(-45.0 + float(item_index) * 30.0, 38.0), 7.0, Color("#f0bd45"))
	if hole_tier >= 3:
		draw_circle(hole_position + Vector2(0.0, -62.0), 12.0, Color(1.0, 0.72, 0.2, 0.32))
		draw_circle(hole_position + Vector2(0.0, -62.0), 5.0, Color("#ffd879"))
	if hole_tier >= 4:
		draw_rect(Rect2(hole_position + Vector2(-42.0, -88.0), Vector2(84.0, 20.0)), Color("#6f4f36"), true)
		draw_line(hole_position + Vector2(-28.0, 56.0), hole_position + Vector2(-45.0, 82.0), Color("#b58a55"), 4.0, true)
		draw_line(hole_position + Vector2(28.0, 56.0), hole_position + Vector2(45.0, 82.0), Color("#b58a55"), 4.0, true)
	draw_string(
		GAME_FONT,
		hole_position + Vector2(-54.0, 103.0),
		"쥐구멍 Lv.%d" % GameManager.hole_level,
		HORIZONTAL_ALIGNMENT_CENTER,
		108.0,
		18,
		Color("#e7d9c7")
	)


func _draw_embedded_hole_progress() -> void:
	var hole_tier: int = VisualProgression.hole_tier(GameManager.hole_level)
	var pulse: float = 0.5 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.12
	draw_circle(hole_position, 45.0, Color(1.0, 0.63, 0.2, 0.05 + pulse * 0.05))
	draw_arc(hole_position, 39.0, 0.15, PI - 0.15, 28, Color(1.0, 0.77, 0.36, 0.52), 3.0, true)
	if hole_tier >= 1:
		draw_line(hole_position + Vector2(-30.0, 20.0), hole_position + Vector2(-30.0, -20.0), Color("#b7834e"), 5.0, true)
		draw_line(hole_position + Vector2(30.0, 20.0), hole_position + Vector2(30.0, -20.0), Color("#b7834e"), 5.0, true)
	if hole_tier >= 2:
		for item_index: int in range(3):
			draw_circle(hole_position + Vector2(-18.0 + float(item_index) * 18.0, 28.0), 4.0, Color("#f0bd45"))
	if hole_tier >= 3:
		draw_circle(hole_position + Vector2(0.0, -42.0), 7.0, Color(1.0, 0.75, 0.28, pulse))
	if hole_tier >= 4:
		draw_rect(Rect2(hole_position + Vector2(-25.0, -57.0), Vector2(50.0, 11.0)), Color("#715039"), true)
		draw_line(hole_position + Vector2(-20.0, 28.0), hole_position + Vector2(-35.0, 42.0), Color("#c49a62"), 3.0, true)
		draw_line(hole_position + Vector2(20.0, 28.0), hole_position + Vector2(35.0, 42.0), Color("#c49a62"), 3.0, true)


func _draw_cheese_resource() -> void:
	if GameManager.current_stage_index < STAGE_BACKGROUNDS.size():
		return
	var cheese_color: Color = Color("#ffd35a")
	if GameManager.golden_remaining > 0.0:
		cheese_color = Color("#fff09b")
		var glow_radius: float = 63.0 + sin(Time.get_ticks_msec() * 0.008) * 6.0
		draw_circle(resource_position, glow_radius, Color(1.0, 0.79, 0.15, 0.18))
	var points: PackedVector2Array = PackedVector2Array([
		resource_position + Vector2(-52.0, 40.0),
		resource_position + Vector2(50.0, 40.0),
		resource_position + Vector2(35.0, -42.0)
	])
	draw_colored_polygon(points, cheese_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("#9d6720"), 4.0, true)
	draw_circle(resource_position + Vector2(6.0, 12.0), 8.0, Color("#d79a2c"))
	draw_circle(resource_position + Vector2(24.0, -12.0), 6.0, Color("#d79a2c"))
	draw_circle(resource_position + Vector2(-24.0, 22.0), 5.0, Color("#d79a2c"))
	var label: String = "황금치즈!" if GameManager.golden_remaining > 0.0 else "치즈"
	draw_string(
		GAME_FONT,
		resource_position + Vector2(-48.0, 78.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		96.0,
		20,
		Color("#fff3d1")
	)


func _draw_resident_mice() -> void:
	var resident_count: int = mini(maxi(0, GameManager.mouse_count - 1), 6)
	var elapsed: float = float(Time.get_ticks_msec()) * 0.001
	for index: int in range(resident_count):
		var column: int = index % 3
		var row: int = index / 3
		var resident_position: Vector2 = hole_position + Vector2(
			-52.0 + float(column) * 48.0,
			92.0 + float(row) * 30.0 + sin(elapsed * 2.0 + float(index)) * 2.0
		)
		_draw_resident_mouse(resident_position, index)


func _draw_resident_mouse(resident_position: Vector2, resident_index: int) -> void:
	draw_set_transform(resident_position)
	draw_texture_rect(
		RESIDENT_MOUSE_TEXTURE,
		Rect2(Vector2(-18.0, -24.0), Vector2(36.0, 24.0)),
		false
	)
	if resident_index % 3 == 0:
		draw_circle(Vector2(13.0, 4.0), 4.0, Color("#f0bd45"))
		draw_line(Vector2(8.0, 2.0), Vector2(12.0, 3.0), Color("#e7d8bf"), 2.0, true)
	elif resident_index % 3 == 1:
		draw_line(Vector2(8.0, 2.0), Vector2(16.0, -5.0), Color("#c7a06a"), 2.0, true)
		draw_line(Vector2(15.0, -5.0), Vector2(18.0, 2.0), Color("#c7a06a"), 2.0, true)
	else:
		draw_rect(Rect2(Vector2(9.0, -3.0), Vector2(8.0, 8.0)), Color("#8d6a47"), true)
	draw_set_transform(Vector2.ZERO)


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if GameManager.current_stage_index < STAGE_BACKGROUNDS.size():
		var background: Texture2D = STAGE_BACKGROUNDS[GameManager.current_stage_index]
		hole_position = _background_point_to_viewport(
			STAGE_HOLE_ANCHORS[GameManager.current_stage_index],
			background,
			viewport_size
		)
		resource_position = _background_point_to_viewport(
			STAGE_RESOURCE_ANCHORS[GameManager.current_stage_index],
			background,
			viewport_size
		)
		_route_points = _build_stage_route(
			GameManager.current_stage_index,
			background,
			viewport_size
		)
	else:
		var vertical_center: float = clampf(viewport_size.y * 0.68, 260.0, viewport_size.y - 190.0)
		hole_position = Vector2(maxf(90.0, viewport_size.x * 0.13), vertical_center)
		resource_position = Vector2(minf(viewport_size.x - 90.0, viewport_size.x * 0.87), vertical_center)
		_route_points = PackedVector2Array([hole_position, resource_position])
	for mouse_node: GatheringMouse in _mouse_nodes:
		mouse_node.update_route_points(_route_points)
	queue_redraw()


func _rebuild_mice(count: int) -> void:
	for mouse_node: GatheringMouse in _mouse_nodes:
		mouse_node.queue_free()
	_mouse_nodes.clear()

	var visible_group_count: int = mini(count, MAX_VISIBLE_WORK_GROUPS)
	for index: int in range(visible_group_count):
		var instance: Node = MOUSE_SCENE.instantiate()
		var mouse_node: GatheringMouse = instance as GatheringMouse
		add_child(mouse_node)
		var lane_row: int = index % MAX_LANE_ROWS
		var mice_in_first_group: int = mini(visible_group_count, MAX_LANE_ROWS)
		var centered_lane: float = (
			float(lane_row)
			- float(mice_in_first_group - 1) * 0.5
		)
		var lane_offset: float = centered_lane * 4.0
		var initial_progress: float = fposmod(float(index) * 0.13, 0.88)
		var worker_group_size: int = count / visible_group_count
		if index < count % visible_group_count:
			worker_group_size += 1
		mouse_node.configure_route(
			_route_points,
			lane_offset,
			index,
			initial_progress,
			worker_group_size
		)
		mouse_node.reward_delivered.connect(_on_reward_delivered)
		_mouse_nodes.append(mouse_node)


func _on_reward_delivered(world_position_value: Vector2, amount: int) -> void:
	_effects.append({
		"position": world_position_value + Vector2(-20.0, -25.0),
		"amount": amount,
		"remaining": 1.0
	})


func _on_mouse_count_changed(count: int) -> void:
	_rebuild_mice(count)


func _on_stage_changed(_stage_index: int) -> void:
	var stage: Dictionary = GameManager.get_current_stage()
	_stage_color = Color.from_string(
		_dictionary_string(stage, "background_color", "#352a3b"),
		Color("#352a3b")
	)
	_update_layout()
	queue_redraw()


func _on_golden_cheese_changed(_active: bool, _remaining: float) -> void:
	queue_redraw()


func _on_viewport_size_changed() -> void:
	_update_layout()


func _get_background_source_rect(background: Texture2D, viewport_size: Vector2) -> Rect2:
	var texture_size: Vector2 = background.get_size()
	var source_rect: Rect2 = Rect2(Vector2.ZERO, texture_size)
	var viewport_aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var texture_aspect: float = texture_size.x / maxf(1.0, texture_size.y)
	if viewport_aspect > texture_aspect:
		var source_height: float = texture_size.x / viewport_aspect
		source_rect.position.y = (texture_size.y - source_height) * 0.5
		source_rect.size.y = source_height
	else:
		var source_width: float = texture_size.y * viewport_aspect
		source_rect.position.x = (texture_size.x - source_width) * 0.5
		source_rect.size.x = source_width
	return source_rect


func _background_point_to_viewport(
	texture_point: Vector2,
	background: Texture2D,
	viewport_size: Vector2
) -> Vector2:
	var source_rect: Rect2 = _get_background_source_rect(background, viewport_size)
	var normalized_point: Vector2 = Vector2(
		(texture_point.x - source_rect.position.x) / source_rect.size.x,
		(texture_point.y - source_rect.position.y) / source_rect.size.y
	)
	return Vector2(
		clampf(normalized_point.x * viewport_size.x, 44.0, viewport_size.x - 44.0),
		clampf(normalized_point.y * viewport_size.y, 185.0, viewport_size.y - 165.0)
	)


func _build_stage_route(
	stage_index: int,
	background: Texture2D,
	viewport_size: Vector2
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array([hole_position])
	for texture_point: Vector2 in STAGE_ROUTE_CONTROLS[stage_index]:
		result.append(_background_point_to_viewport(texture_point, background, viewport_size))
	result.append(resource_position)
	return result


func _clamp_reward_position(
	position_value: Vector2,
	text_width: float,
	viewport_size: Vector2
) -> Vector2:
	var compact_layout: bool = viewport_size.x < 1000.0
	var safe_top: float = 450.0 if compact_layout else 350.0
	var safe_bottom: float = 245.0 if compact_layout else REWARD_BOTTOM_MARGIN
	var maximum_x: float = maxf(
		REWARD_SIDE_MARGIN,
		viewport_size.x - text_width - REWARD_SIDE_MARGIN
	)
	var maximum_y: float = maxf(
		safe_top,
		viewport_size.y - safe_bottom
	)
	return Vector2(
		clampf(position_value.x, REWARD_SIDE_MARGIN, maximum_x),
		clampf(position_value.y, safe_top, maximum_y)
	)


func _format_reward_amount(amount: int) -> String:
	var absolute_amount: int = absi(amount)
	if absolute_amount >= 1_000_000_000:
		return "%.2fB" % (float(amount) / 1_000_000_000.0)
	if absolute_amount >= 1_000_000:
		return "%.2fM" % (float(amount) / 1_000_000.0)
	if absolute_amount >= 1_000:
		return "%.2fK" % (float(amount) / 1_000.0)
	return "%d" % amount


func _dictionary_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value is float:
		return value
	if value is int:
		@warning_ignore("unsafe_call_argument")
		return float(value)
	return fallback


func _dictionary_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int:
		return value
	if value is float:
		@warning_ignore("unsafe_call_argument")
		return int(value)
	return fallback


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	if value is String:
		return value
	if value is StringName:
		@warning_ignore("unsafe_call_argument")
		return String(value)
	return fallback


func _dictionary_vector2(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = data.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
