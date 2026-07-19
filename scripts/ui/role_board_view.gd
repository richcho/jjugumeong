class_name RoleBoardView
extends Control

signal role_pressed(role_id: String)

const ROLE_IDS: Array[String] = ["gatherer", "explorer", "builder"]
const ROLE_COLORS: Array[Color] = [
	Color("#ffd969"),
	Color("#73d7ff"),
	Color("#df9cff")
]
const ROLE_LABELS: Array[String] = ["채집", "탐험", "건설"]
const LABEL_FONT: Font = preload("res://assets/fonts/NotoSansKR-Full.ttf")
const HIT_RADIUS: float = 48.0

var assignments: Dictionary = {
	"gatherer": 1,
	"explorer": 0,
	"builder": 0
}
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


func set_assignments(value: Dictionary) -> void:
	assignments = value.duplicate(true)
	queue_redraw()


func get_role_position(role_id: String) -> Vector2:
	var index: int = ROLE_IDS.find(role_id)
	if index < 0:
		return Vector2.ZERO
	return Vector2(size.x * (0.2 + float(index) * 0.3), size.y * 0.52)


func submit_point(local_point: Vector2) -> String:
	for role_id: String in ROLE_IDS:
		if local_point.distance_to(get_role_position(role_id)) <= HIT_RADIUS:
			role_pressed.emit(role_id)
			return role_id
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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090b13"), true)
	var line_y: float = size.y * 0.52
	draw_line(
		Vector2(size.x * 0.12, line_y),
		Vector2(size.x * 0.88, line_y),
		Color(0.42, 0.46, 0.58, 0.35),
		3.0,
		true
	)
	for index: int in range(ROLE_IDS.size()):
		var role_id: String = ROLE_IDS[index]
		var position: Vector2 = get_role_position(role_id)
		var color: Color = ROLE_COLORS[index]
		var count: int = _dictionary_int(assignments, role_id, 0)
		var pulse: float = sin(elapsed * 3.0 + float(index)) * 2.0
		draw_circle(position, 27.0 + pulse, Color(color, 0.12))
		draw_circle(position, 18.0, color)
		draw_arc(position, 34.0 + pulse, 0.0, TAU, 36, Color(color, 0.65), 2.0, true)
		var label_text: String = "%s %d" % [ROLE_LABELS[index], count]
		var label_width: float = LABEL_FONT.get_string_size(
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16
		).x
		draw_string(
			LABEL_FONT,
			position + Vector2(-label_width * 0.5, 76.0),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			Color("#f4edf4")
		)
		for mouse_index: int in range(count):
			var angle: float = (
				elapsed * (0.65 + float(index) * 0.12)
				+ TAU * float(mouse_index) / float(maxi(1, count))
			)
			var orbit_radius: float = 48.0 + float(mouse_index % 2) * 8.0
			draw_circle(
				position + Vector2.from_angle(angle) * orbit_radius,
				4.5,
				Color("#f5eef3")
			)


func _dictionary_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int:
		return value
	if value is float:
		@warning_ignore("unsafe_cast")
		var float_value: float = value as float
		return roundi(float_value)
	return fallback
