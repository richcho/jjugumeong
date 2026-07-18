class_name GatheringMouse
extends Node2D

signal reward_delivered(world_position: Vector2, amount: int)

const MOUSE_TEXTURE: Texture2D = preload("res://assets/mouse/sprites/field_mouse-v2.png")
const CARRYING_TEXTURE: Texture2D = preload(
	"res://assets/mouse/sprites/field_mouse_carrying-v2.png"
)

var hole_position: Vector2 = Vector2.ZERO
var resource_position: Vector2 = Vector2.ZERO
var lane_offset: float = 0.0
var route_points: PackedVector2Array = PackedVector2Array()
var route_progress: float = 0.0
var outbound: bool = true
var carrying: bool = false
var visual_index: int = 0
var walk_phase: float = 0.0
var _landing_squash: float = 0.0


func configure(start_position: Vector2, target_position: Vector2, offset: float, index: int) -> void:
	hole_position = start_position
	resource_position = target_position
	lane_offset = offset
	visual_index = index
	position = hole_position + Vector2(0.0, lane_offset)
	outbound = true
	carrying = false
	walk_phase = float(index) * 1.7
	_landing_squash = 0.0
	queue_redraw()


func update_route(start_position: Vector2, target_position: Vector2) -> void:
	hole_position = start_position
	resource_position = target_position


func configure_route(
	points: PackedVector2Array,
	offset: float,
	index: int,
	initial_progress: float
) -> void:
	route_points = points
	lane_offset = offset
	visual_index = index
	route_progress = clampf(initial_progress, 0.0, 0.92)
	outbound = true
	carrying = false
	walk_phase = float(index) * 1.7
	_landing_squash = 0.0
	position = _route_position(route_progress)
	queue_redraw()


func update_route_points(points: PackedVector2Array) -> void:
	route_points = points
	position = _route_position(route_progress)


func _process(delta: float) -> void:
	_landing_squash = maxf(_landing_squash - delta * 4.5, 0.0)
	if route_points.size() >= 2:
		_process_perspective_route(delta)
		return
	var destination: Vector2
	if outbound:
		destination = resource_position + Vector2(0.0, lane_offset)
	else:
		destination = hole_position + Vector2(0.0, lane_offset)
	var move_distance: float = GameManager.get_move_speed() * delta
	var previous_position: Vector2 = position
	position = position.move_toward(destination, move_distance)
	var traveled_distance: float = previous_position.distance_to(position)
	walk_phase = fposmod(walk_phase + traveled_distance * 0.115, TAU)
	if position.distance_squared_to(destination) <= 1.0:
		_landing_squash = 1.0
		if outbound:
			outbound = false
			carrying = true
			queue_redraw()
		else:
			var reward: int = GameManager.collect_trip(GameManager.get_carry_capacity())
			reward_delivered.emit(position, reward)
			outbound = true
			carrying = false
			queue_redraw()

	var direction_sign: float = 1.0 if outbound else -1.0
	scale.x = direction_sign
	queue_redraw()


func _process_perspective_route(delta: float) -> void:
	var previous_position: Vector2 = position
	var progress_delta: float = (
		GameManager.get_move_speed() * delta / maxf(_route_length(), 1.0)
	)
	route_progress += progress_delta if outbound else -progress_delta
	var reached_end: bool = outbound and route_progress >= 1.0
	var reached_hole: bool = not outbound and route_progress <= 0.0
	route_progress = clampf(route_progress, 0.0, 1.0)
	position = _route_position(route_progress)
	var traveled_distance: float = previous_position.distance_to(position)
	walk_phase = fposmod(walk_phase + traveled_distance * 0.115, TAU)

	if reached_end:
		_landing_squash = 1.0
		outbound = false
		carrying = true
	elif reached_hole:
		_landing_squash = 1.0
		var reward: int = GameManager.collect_trip(GameManager.get_carry_capacity())
		reward_delivered.emit(position, reward)
		outbound = true
		carrying = false

	var direction_sign: float = 1.0 if outbound else -1.0
	var perspective_scale: float = _route_perspective_scale(route_progress)
	scale = Vector2(direction_sign * perspective_scale, perspective_scale)
	queue_redraw()


func _route_position(progress: float) -> Vector2:
	if route_points.size() < 2:
		return hole_position.lerp(resource_position, progress) + Vector2(0.0, lane_offset)
	var segment_progress: float = clampf(progress, 0.0, 1.0) * float(route_points.size() - 1)
	var segment_index: int = mini(floori(segment_progress), route_points.size() - 2)
	var local_progress: float = segment_progress - float(segment_index)
	var start_point: Vector2 = route_points[segment_index]
	var end_point: Vector2 = route_points[segment_index + 1]
	var tangent: Vector2 = (end_point - start_point).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var lane_strength: float = sin(clampf(progress, 0.0, 1.0) * PI)
	return start_point.lerp(end_point, local_progress) + normal * lane_offset * lane_strength


func _route_length() -> float:
	var result: float = 0.0
	for index: int in range(route_points.size() - 1):
		result += route_points[index].distance_to(route_points[index + 1])
	return result


func _route_perspective_scale(progress: float) -> float:
	var current_position: Vector2 = _route_position(progress)
	var endpoint_floor: float = maxf(route_points[0].y, route_points[route_points.size() - 1].y)
	var depth: float = clampf((endpoint_floor - current_position.y) / 210.0, 0.0, 1.0)
	return lerpf(1.0, 0.64, depth)


func _draw() -> void:
	var stride_wave: float = sin(walk_phase)
	var lift: float = absf(stride_wave)
	var carrying_weight: float = 0.72 if carrying else 1.0
	var bob_offset: float = -lift * 1.4 * carrying_weight + _landing_squash * 1.2
	var body_rotation: float = stride_wave * 0.012 * carrying_weight
	var body_scale: Vector2 = Vector2(
		1.0 + lift * 0.012 - _landing_squash * 0.025,
		1.0 - lift * 0.022 + _landing_squash * 0.045
	)
	_draw_ground_shadow(lift)
	_draw_foot_contacts(stride_wave)
	draw_set_transform(Vector2(0.0, bob_offset), body_rotation, body_scale)
	var active_texture: Texture2D = CARRYING_TEXTURE if carrying else MOUSE_TEXTURE
	draw_texture_rect(active_texture, Rect2(Vector2(-39.0, -53.0), Vector2(78.0, 53.0)), false)
	draw_set_transform(Vector2.ZERO)


func _draw_ground_shadow(lift: float) -> void:
	var shadow_width: float = 1.0 - lift * 0.16
	var shadow_alpha: float = 0.24 - lift * 0.07
	draw_set_transform(Vector2(0.0, 1.5), 0.0, Vector2(shadow_width, 0.24))
	draw_circle(Vector2.ZERO, 29.0, Color(0.03, 0.02, 0.04, shadow_alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_dust_puff() -> void:
	var dust_progress: float = fposmod(walk_phase, PI) / PI
	var dust_alpha: float = (1.0 - dust_progress) * 0.18
	if carrying:
		dust_alpha *= 0.65
	var dust_color: Color = Color(0.86, 0.72, 0.53, dust_alpha)
	draw_circle(Vector2(-31.0 - dust_progress * 8.0, -2.0 - dust_progress * 5.0), 3.5 + dust_progress * 2.0, dust_color)
	draw_circle(Vector2(-25.0 - dust_progress * 5.0, -1.0 - dust_progress * 3.0), 2.0 + dust_progress, dust_color)


func _draw_foot_contacts(stride_wave: float) -> void:
	var front_alpha: float = clampf(stride_wave, 0.0, 1.0) * 0.18
	var back_alpha: float = clampf(-stride_wave, 0.0, 1.0) * 0.18
	draw_line(Vector2(12.0, 0.0), Vector2(23.0, 0.0), Color(0.12, 0.08, 0.08, front_alpha), 2.0, true)
	draw_line(Vector2(-20.0, 0.0), Vector2(-9.0, 0.0), Color(0.12, 0.08, 0.08, back_alpha), 2.0, true)
