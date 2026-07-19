class_name NurseryView
extends Control

signal pup_pressed(pup_id: int)

const HIT_RADIUS: float = 42.0

var pups: Array[Dictionary] = []
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


func set_pups(pup_snapshots: Array[Dictionary]) -> void:
	pups = pup_snapshots.duplicate(true)
	queue_redraw()


func get_pup_position(index: int) -> Vector2:
	if index == 0:
		return Vector2(size.x * 0.34, size.y * 0.56)
	return Vector2(size.x * 0.66, size.y * 0.56)


func submit_point(local_point: Vector2) -> int:
	for index: int in range(pups.size()):
		var pup: Dictionary = pups[index]
		if local_point.distance_to(get_pup_position(index)) <= HIT_RADIUS:
			var pup_id: int = _dictionary_int(pup, "id", 0)
			if pup_id > 0:
				pup_pressed.emit(pup_id)
				return pup_id
	return 0


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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#100c16"), true)
	var center: Vector2 = size * Vector2(0.5, 0.56)
	var room_radius: float = minf(size.x * 0.42, size.y * 0.43)
	draw_circle(center, room_radius, Color(0.23, 0.13, 0.18, 0.95))
	draw_arc(center, room_radius, 0.0, TAU, 64, Color("#8d5f68"), 4.0, true)
	draw_arc(center, room_radius * 0.72, 0.0, TAU, 64, Color(0.95, 0.68, 0.43, 0.25), 2.0, true)

	for slot_index: int in range(GameManager.NURSERY_LEVEL_ONE_CAPACITY):
		var slot_position: Vector2 = get_pup_position(slot_index)
		draw_circle(slot_position, 31.0, Color(0.08, 0.07, 0.1, 0.86))
		draw_arc(slot_position, 31.0, 0.0, TAU, 32, Color("#594a62"), 2.0, true)
		if slot_index >= pups.size():
			draw_circle(slot_position, 4.0, Color("#655b69"))

	for index: int in range(pups.size()):
		var pup: Dictionary = pups[index]
		var position: Vector2 = get_pup_position(index)
		var ready: bool = _dictionary_bool(pup, "ready", false)
		var care_count: int = _dictionary_int(pup, "care_count", 0)
		var pulse: float = sin(elapsed * 4.5 + float(index)) * 2.0
		var radius: float = (16.0 if ready else 11.0 + float(care_count)) + pulse
		var color: Color = Color("#fff0a4") if ready else Color("#f2a6bc")
		draw_circle(position, radius + 9.0, Color(color, 0.12))
		draw_circle(position, radius, color)
		draw_arc(position, 24.0 + pulse, 0.0, TAU, 32, Color(color, 0.75), 2.0, true)
		for care_index: int in range(GameManager.NURSERY_MAX_CARE):
			var care_angle: float = -PI * 0.75 + float(care_index) * PI * 0.75
			var care_position: Vector2 = position + Vector2.from_angle(care_angle) * 35.0
			draw_circle(
				care_position,
				3.5,
				Color("#9fe0c0") if care_index < care_count else Color("#493e4e")
			)

	var caregiver_angle: float = elapsed * 0.8
	var caregiver_position: Vector2 = center + Vector2.from_angle(caregiver_angle) * room_radius * 0.76
	draw_circle(caregiver_position, 7.0, Color("#9fe0c0"))
	draw_line(
		caregiver_position,
		center + Vector2.from_angle(caregiver_angle) * room_radius * 0.6,
		Color(0.62, 0.88, 0.75, 0.28),
		2.0,
		true
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


func _dictionary_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key, fallback)
	if value is bool:
		return value
	return fallback
