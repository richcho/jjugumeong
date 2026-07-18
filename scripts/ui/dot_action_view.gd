class_name DotActionView
extends Control

signal action_completed(action_id: String, mistakes: int)
signal status_changed(status_text: String)

const SIGNAL_COLORS: Array[Color] = [
	Color("#ffd969"),
	Color("#73d7ff"),
	Color("#d796ff")
]

var action_id: String = ""
var action_type: String = ""
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


func setup(action: Dictionary) -> void:
	action_id = _dictionary_string(action, "id", "")
	action_type = _dictionary_string(action, "type", "")
	step = 0
	mistakes = 0
	elapsed = 0.0
	finished = false
	status_changed.emit(get_status_text())
	queue_redraw()


func get_status_text() -> String:
	var total_steps: int = get_total_steps()
	if finished:
		return "완료 · 실수 %d회" % mistakes
	match action_type:
		"untangle":
			return "실의 연결을 따라 매듭을 누르세요 · %d/%d · 실수 %d" % [
				step,
				total_steps,
				mistakes
			]
		"tower":
			return "아래에서 위로 빛나는 발판을 밟으세요 · %d/%d · 실수 %d" % [
				step,
				total_steps,
				mistakes
			]
		"infinite":
			return "중앙 신호와 같은 색의 문으로 들어가세요 · %d/%d · 실수 %d" % [
				step,
				total_steps,
				mistakes
			]
	return "행동 데이터가 준비되지 않았습니다."


func get_total_steps() -> int:
	match action_type:
		"untangle":
			return 6
		"tower":
			return 7
		"infinite":
			return 5
	return 0


func get_active_target_position() -> Vector2:
	if finished:
		return Vector2.ZERO
	if action_type == "untangle":
		var knots: PackedVector2Array = _untangle_points()
		var thread_order: PackedInt32Array = _untangle_order()
		if step < thread_order.size():
			return knots[thread_order[step]]
	elif action_type == "tower":
		var footholds: PackedVector2Array = _tower_points()
		if step < footholds.size():
			return footholds[step]
	elif action_type == "infinite":
		var portals: PackedVector2Array = _portal_points()
		var target_color_index: int = step % SIGNAL_COLORS.size()
		for portal_index: int in range(portals.size()):
			if _portal_color_index(portal_index) == target_color_index:
				return portals[portal_index]
	return Vector2.ZERO


func submit_point(local_point: Vector2) -> bool:
	if finished or action_id.is_empty():
		return false
	var target: Vector2 = get_active_target_position()
	var hit_radius: float = 48.0 if action_type == "infinite" else 34.0
	var correct: bool = local_point.distance_to(target) <= hit_radius
	if correct:
		step += 1
		if step >= get_total_steps():
			finished = true
			status_changed.emit(get_status_text())
			queue_redraw()
			action_completed.emit(action_id, mistakes)
			return true
	else:
		mistakes += 1
		if action_type == "untangle" or action_type == "tower":
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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090811"), true)
	_draw_star_field()
	match action_type:
		"untangle":
			_draw_untangle()
		"tower":
			_draw_tower()
		"infinite":
			_draw_infinite()
		_:
			draw_circle(size * 0.5, 8.0, Color("#8b8298"))


func _draw_star_field() -> void:
	for index: int in range(28):
		var x_ratio: float = fposmod(float(index) * 0.381966, 1.0)
		var y_ratio: float = fposmod(float(index * index + 7) * 0.173205, 1.0)
		var pulse: float = 0.13 + sin(elapsed * 1.4 + float(index)) * 0.05
		draw_circle(
			Vector2(size.x * x_ratio, size.y * y_ratio),
			1.0 + float(index % 2),
			Color(0.72, 0.79, 0.92, pulse)
		)


func _draw_untangle() -> void:
	var knots: PackedVector2Array = _untangle_points()
	var thread_order: PackedInt32Array = _untangle_order()
	for index: int in range(thread_order.size() - 1):
		var from_point: Vector2 = knots[thread_order[index]]
		var to_point: Vector2 = knots[thread_order[index + 1]]
		draw_line(from_point, to_point, Color(0.44, 0.33, 0.58, 0.72), 4.0, true)
	for knot_index: int in range(knots.size()):
		var order_position: int = thread_order.find(knot_index)
		var completed: bool = order_position < step
		var active: bool = order_position == step and not finished
		var radius: float = 12.0
		var color: Color = Color("#6f637b")
		if completed:
			color = Color("#73d7ff")
			radius = 9.0
		elif active:
			color = Color("#ffd969")
			radius = 14.0 + sin(elapsed * 5.0) * 2.0
			draw_arc(knots[knot_index], 23.0, 0.0, TAU, 24, Color("#fff2a8"), 2.0, true)
		draw_circle(knots[knot_index], radius, color)
	if not knots.is_empty():
		var explorer_step: int = clampi(step - 1, 0, thread_order.size() - 1)
		_draw_explorer(knots[thread_order[explorer_step]])


func _draw_tower() -> void:
	var center_x: float = size.x * 0.5
	draw_line(
		Vector2(center_x - 72.0, size.y - 22.0),
		Vector2(center_x - 34.0, 24.0),
		Color("#64717d"),
		5.0,
		true
	)
	draw_line(
		Vector2(center_x + 72.0, size.y - 22.0),
		Vector2(center_x + 34.0, 24.0),
		Color("#64717d"),
		5.0,
		true
	)
	for rung_index: int in range(6):
		var rung_y: float = size.y - 42.0 - float(rung_index) * (size.y - 82.0) / 5.0
		var half_width: float = 66.0 - float(rung_index) * 5.0
		draw_line(
			Vector2(center_x - half_width, rung_y),
			Vector2(center_x + half_width, rung_y),
			Color(0.34, 0.42, 0.48, 0.7),
			2.0,
			true
		)
	var footholds: PackedVector2Array = _tower_points()
	for foothold_index: int in range(footholds.size()):
		var completed: bool = foothold_index < step
		var active: bool = foothold_index == step and not finished
		var color: Color = Color("#59636b")
		var radius: float = 11.0
		if completed:
			color = Color("#94e0b5")
		elif active:
			color = Color("#ffd969")
			radius = 14.0 + sin(elapsed * 5.0) * 2.0
			draw_arc(footholds[foothold_index], 23.0, 0.0, TAU, 24, Color("#fff2a8"), 2.0, true)
		draw_circle(footholds[foothold_index], radius, color)
	var explorer_index: int = clampi(step - 1, 0, footholds.size() - 1)
	if not footholds.is_empty():
		_draw_explorer(footholds[explorer_index])


func _draw_infinite() -> void:
	var center: Vector2 = size * 0.5
	var target_color_index: int = step % SIGNAL_COLORS.size()
	var target_color: Color = SIGNAL_COLORS[target_color_index]
	var signal_radius: float = 15.0 + sin(elapsed * 4.0) * 3.0
	draw_circle(center, signal_radius, target_color)
	draw_arc(center, 29.0, 0.0, TAU, 32, Color(target_color, 0.55), 3.0, true)
	var portals: PackedVector2Array = _portal_points()
	for portal_index: int in range(portals.size()):
		var color_index: int = _portal_color_index(portal_index)
		var portal_color: Color = SIGNAL_COLORS[color_index]
		var portal_radius: float = 36.0 + sin(elapsed * 2.5 + float(portal_index)) * 4.0
		draw_arc(portals[portal_index], portal_radius, 0.0, TAU, 40, portal_color, 7.0, true)
		draw_circle(portals[portal_index], 5.0, Color(portal_color, 0.75))
		for echo_index: int in range(2):
			draw_arc(
				portals[portal_index],
				portal_radius + 12.0 + float(echo_index) * 10.0,
				0.0,
				TAU,
				40,
				Color(portal_color, 0.12),
				2.0,
				true
			)
	var explorer_angle: float = elapsed * 0.8
	_draw_explorer(center + Vector2(cos(explorer_angle), sin(explorer_angle)) * 48.0)


func _draw_explorer(point: Vector2) -> void:
	draw_circle(point, 6.0, Color("#fff7e0"))
	draw_arc(point, 11.0, 0.0, TAU, 18, Color(1.0, 0.85, 0.4, 0.4), 2.0, true)


func _untangle_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(size.x * 0.16, size.y * 0.68),
		Vector2(size.x * 0.38, size.y * 0.27),
		Vector2(size.x * 0.55, size.y * 0.73),
		Vector2(size.x * 0.68, size.y * 0.23),
		Vector2(size.x * 0.82, size.y * 0.62),
		Vector2(size.x * 0.91, size.y * 0.32)
	])


func _untangle_order() -> PackedInt32Array:
	return PackedInt32Array([0, 3, 1, 4, 2, 5])


func _tower_points() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for index: int in range(7):
		var x_offset: float = -42.0 if index % 2 == 0 else 42.0
		var y_value: float = size.y - 30.0 - float(index) * (size.y - 70.0) / 6.0
		result.append(Vector2(size.x * 0.5 + x_offset, y_value))
	return result


func _portal_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(size.x * 0.18, size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.2),
		Vector2(size.x * 0.82, size.y * 0.5)
	])


func _portal_color_index(portal_index: int) -> int:
	return (portal_index + step * 2 + 1) % SIGNAL_COLORS.size()


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	if value is String:
		return value
	return fallback
