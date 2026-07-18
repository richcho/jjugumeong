class_name WorldView
extends Node2D

const MOUSE_SCENE: PackedScene = preload("res://scenes/mouse/mouse.tscn")
const GAME_FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Subset.ttf")
const MAX_LANE_ROWS: int = 7

var hole_position: Vector2 = Vector2.ZERO
var resource_position: Vector2 = Vector2.ZERO
var _mouse_nodes: Array[GatheringMouse] = []
var _effects: Array[Dictionary] = []
var _stage_color: Color = Color("#352a3b")


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
	draw_rect(Rect2(Vector2.ZERO, viewport_size), _stage_color)

	var floor_top: float = viewport_size.y * 0.67
	draw_rect(Rect2(0.0, floor_top, viewport_size.x, viewport_size.y - floor_top), Color("#211b26"))
	draw_line(hole_position, resource_position, Color(0.82, 0.72, 0.54, 0.22), 5.0, true)
	for marker_index: int in range(1, 8):
		var marker_position: Vector2 = hole_position.lerp(resource_position, float(marker_index) / 8.0)
		draw_circle(marker_position, 3.0, Color(0.95, 0.86, 0.67, 0.35))

	_draw_mouse_hole()
	_draw_cheese_resource()

	for effect: Dictionary in _effects:
		var effect_position: Vector2 = _dictionary_vector2(effect, "position", Vector2.ZERO)
		var amount: int = _dictionary_int(effect, "amount", 0)
		var alpha: float = clampf(_dictionary_float(effect, "remaining", 0.0), 0.0, 1.0)
		draw_string(
			GAME_FONT,
			effect_position,
			"+%d 치즈" % amount,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			22,
			Color(1.0, 0.86, 0.28, alpha)
		)


func _draw_mouse_hole() -> void:
	var hole_scale: float = 1.0 + minf(float(GameManager.hole_level - 1) * 0.07, 0.55)
	draw_circle(hole_position + Vector2(0.0, 10.0), 70.0 * hole_scale, Color("#1a151d"))
	draw_circle(hole_position + Vector2(0.0, 12.0), 52.0 * hole_scale, Color("#09080b"))
	draw_arc(hole_position + Vector2(0.0, 10.0), 72.0 * hole_scale, PI, TAU, 28, Color("#6b5546"), 8.0, true)
	draw_string(
		GAME_FONT,
		hole_position + Vector2(-54.0, 103.0),
		"쥐구멍 Lv.%d" % GameManager.hole_level,
		HORIZONTAL_ALIGNMENT_CENTER,
		108.0,
		18,
		Color("#e7d9c7")
	)


func _draw_cheese_resource() -> void:
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


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var vertical_center: float = clampf(viewport_size.y * 0.49, 210.0, viewport_size.y - 190.0)
	hole_position = Vector2(maxf(110.0, viewport_size.x * 0.13), vertical_center)
	resource_position = Vector2(minf(viewport_size.x - 110.0, viewport_size.x * 0.87), vertical_center)
	for mouse_node: GatheringMouse in _mouse_nodes:
		mouse_node.update_route(hole_position, resource_position)
	queue_redraw()


func _rebuild_mice(count: int) -> void:
	for mouse_node: GatheringMouse in _mouse_nodes:
		mouse_node.queue_free()
	_mouse_nodes.clear()

	for index: int in range(count):
		var instance: Node = MOUSE_SCENE.instantiate()
		var mouse_node: GatheringMouse = instance as GatheringMouse
		add_child(mouse_node)
		var lane_row: int = index % MAX_LANE_ROWS
		var lane_offset: float = float(lane_row - MAX_LANE_ROWS / 2) * 17.0
		var progress_offset: float = float(index / MAX_LANE_ROWS) * 32.0
		mouse_node.configure(
			hole_position + Vector2(progress_offset, 0.0),
			resource_position,
			lane_offset,
			index
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
	queue_redraw()


func _on_golden_cheese_changed(_active: bool, _remaining: float) -> void:
	queue_redraw()


func _on_viewport_size_changed() -> void:
	_update_layout()


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
