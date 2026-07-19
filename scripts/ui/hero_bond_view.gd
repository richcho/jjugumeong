class_name HeroBondView
extends Control

signal status_changed(status_text: String)
signal mission_completed(hero_id: String, mistakes: int)

const TOTAL_STEPS: int = 5

var hero_id: String = ""
var mission_type: String = ""
var step: int = 0
var mistakes: int = 0
var elapsed: float = 0.0
var finished: bool = false


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


func setup(hero: Dictionary) -> void:
	hero_id = _dictionary_string(hero, "id", "")
	mission_type = _dictionary_string(hero, "mission_type", "")
	step = 0
	mistakes = 0
	elapsed = 0.0
	finished = false
	status_changed.emit(get_status_text())
	queue_redraw()


func get_status_text() -> String:
	if finished:
		return "임무 완료 · 실수 %d회" % mistakes
	return "빛나는 점을 순서대로 누르세요 · %d/%d · 실수 %d" % [
		step,
		TOTAL_STEPS,
		mistakes
	]


func get_active_target_position() -> Vector2:
	if finished or step >= TOTAL_STEPS:
		return Vector2.ZERO
	return _mission_points()[step]


func submit_point(local_point: Vector2) -> bool:
	if finished or hero_id.is_empty():
		return false
	var target: Vector2 = get_active_target_position()
	var correct: bool = local_point.distance_to(target) <= 36.0
	if correct:
		step += 1
		if step >= TOTAL_STEPS:
			finished = true
			status_changed.emit(get_status_text())
			queue_redraw()
			mission_completed.emit(hero_id, mistakes)
			return true
	else:
		mistakes += 1
		step = maxi(0, step - 1)
	status_changed.emit(get_status_text())
	queue_redraw()
	return correct


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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090812"), true)
	var points: PackedVector2Array = _mission_points()
	match mission_type:
		"balance":
			_draw_balance_background(points)
		"trail":
			_draw_trail_background(points)
		"breath":
			_draw_breath_background(points)
	for index: int in range(points.size()):
		var completed: bool = index < step
		var active: bool = index == step and not finished
		var color: Color = Color("#5b5768")
		var radius: float = 9.0
		if completed:
			color = Color("#9ee0bd")
		elif active:
			color = Color("#ffd969")
			radius = 14.0 + sin(elapsed * 5.0) * 2.0
			draw_arc(points[index], 24.0, 0.0, TAU, 28, Color("#fff3b3"), 2.0, true)
		draw_circle(points[index], radius, color)


func _mission_points() -> PackedVector2Array:
	match mission_type:
		"balance":
			return PackedVector2Array([
				Vector2(size.x * 0.3, size.y * 0.22),
				Vector2(size.x * 0.7, size.y * 0.36),
				Vector2(size.x * 0.3, size.y * 0.5),
				Vector2(size.x * 0.7, size.y * 0.64),
				Vector2(size.x * 0.3, size.y * 0.78)
			])
		"trail":
			return PackedVector2Array([
				Vector2(size.x * 0.15, size.y * 0.72),
				Vector2(size.x * 0.32, size.y * 0.38),
				Vector2(size.x * 0.5, size.y * 0.62),
				Vector2(size.x * 0.68, size.y * 0.28),
				Vector2(size.x * 0.85, size.y * 0.5)
			])
		"breath":
			var center: Vector2 = size * 0.5
			var points: PackedVector2Array = PackedVector2Array()
			for index: int in range(TOTAL_STEPS):
				var angle: float = -PI * 0.5 + TAU * float(index) / float(TOTAL_STEPS)
				points.append(center + Vector2.from_angle(angle) * minf(size.x, size.y) * 0.3)
			return points
	return PackedVector2Array()


func _draw_balance_background(points: PackedVector2Array) -> void:
	draw_line(
		Vector2(size.x * 0.5, size.y * 0.1),
		Vector2(size.x * 0.5, size.y * 0.88),
		Color(0.62, 0.48, 0.3, 0.4),
		4.0,
		true
	)
	for point: Vector2 in points:
		draw_line(
			Vector2(size.x * 0.5, point.y),
			point,
			Color(0.62, 0.48, 0.3, 0.28),
			2.0,
			true
		)


func _draw_trail_background(points: PackedVector2Array) -> void:
	draw_polyline(points, Color(0.31, 0.65, 0.82, 0.32), 4.0, true)
	for index: int in range(20):
		var star_position: Vector2 = Vector2(
			size.x * fposmod(float(index) * 0.381966, 1.0),
			size.y * fposmod(float(index * index + 3) * 0.173205, 1.0)
		)
		draw_circle(star_position, 1.5, Color(0.65, 0.8, 1.0, 0.25))


func _draw_breath_background(points: PackedVector2Array) -> void:
	var center: Vector2 = size * 0.5
	var base_radius: float = minf(size.x, size.y) * 0.3
	draw_circle(center, base_radius + 24.0, Color(0.48, 0.25, 0.48, 0.18))
	draw_arc(
		center,
		base_radius + sin(elapsed * 2.0) * 5.0,
		0.0,
		TAU,
		48,
		Color(0.87, 0.6, 0.9, 0.45),
		3.0,
		true
	)
	var closed_points: PackedVector2Array = points.duplicate()
	if not points.is_empty():
		closed_points.append(points[0])
	draw_polyline(closed_points, Color(0.87, 0.6, 0.9, 0.2), 2.0, true)


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	return value if value is String else fallback
