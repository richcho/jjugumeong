class_name HeroChoiceView
extends Control

signal candidate_pressed(hero_id: String)

const LABEL_FONT: Font = preload("res://assets/fonts/NotoSansKR-Full.ttf")
const HIT_RADIUS: float = 50.0

var candidates: Array[Dictionary] = []
var preview_hero_id: String = ""
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func setup(hero_candidates: Array[Dictionary], selected_id: String = "") -> void:
	candidates = hero_candidates.duplicate(true)
	preview_hero_id = selected_id
	queue_redraw()


func set_preview_hero(hero_id: String) -> void:
	preview_hero_id = hero_id
	queue_redraw()


func get_candidate_position(index: int) -> Vector2:
	match index:
		0:
			return Vector2(size.x * 0.5, size.y * 0.3)
		1:
			return Vector2(size.x * 0.27, size.y * 0.67)
		2:
			return Vector2(size.x * 0.73, size.y * 0.67)
	return Vector2.ZERO


func submit_point(local_point: Vector2) -> String:
	for index: int in range(candidates.size()):
		if local_point.distance_to(get_candidate_position(index)) > HIT_RADIUS:
			continue
		var hero_id: String = _dictionary_string(candidates[index], "id", "")
		if not hero_id.is_empty():
			preview_hero_id = hero_id
			candidate_pressed.emit(hero_id)
			queue_redraw()
			return hero_id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		@warning_ignore("unsafe_cast")
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			submit_point(mouse_event.position)
			accept_event()
	elif event is InputEventScreenTouch:
		@warning_ignore("unsafe_cast")
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			submit_point(touch_event.position)
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0913"), true)
	if candidates.size() >= 3:
		var triangle: PackedVector2Array = PackedVector2Array([
			get_candidate_position(0),
			get_candidate_position(1),
			get_candidate_position(2),
			get_candidate_position(0)
		])
		draw_polyline(triangle, Color(0.5, 0.46, 0.66, 0.32), 3.0, true)
	for index: int in range(candidates.size()):
		var hero: Dictionary = candidates[index]
		var hero_id: String = _dictionary_string(hero, "id", "")
		var position: Vector2 = get_candidate_position(index)
		var color: Color = Color.from_string(
			_dictionary_string(hero, "color", "#ffd969"),
			Color("#ffd969")
		)
		var selected: bool = hero_id == preview_hero_id
		var pulse: float = sin(elapsed * 4.0 + float(index)) * 2.0
		draw_circle(position, 24.0, color)
		draw_circle(position, 36.0 + pulse, Color(color, 0.12))
		if selected:
			draw_arc(
				position,
				43.0 + pulse,
				0.0,
				TAU,
				40,
				Color("#fff4c4"),
				3.0,
				true
			)
		for memory_index: int in range(3):
			var angle: float = (
				elapsed * (0.7 + float(index) * 0.1)
				+ TAU * float(memory_index) / 3.0
			)
			draw_circle(
				position + Vector2.from_angle(angle) * 48.0,
				3.5,
				Color(color, 0.85)
			)
		var name_text: String = _dictionary_string(hero, "name", "후보")
		var text_width: float = LABEL_FONT.get_string_size(
			name_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16
		).x
		draw_string(
			LABEL_FONT,
			position + Vector2(-text_width * 0.5, 68.0),
			name_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			Color("#f5edf5")
		)


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	return value if value is String else fallback
