class_name GatheringMouse
extends Node2D

signal reward_delivered(world_position: Vector2, amount: int)

enum ActivityState {
	TRAVELING,
	SNIFFING,
	LOADING,
	ENTERING_HOLE,
	RESTING,
	LEAVING_HOLE
}

const MOUSE_TEXTURE: Texture2D = preload("res://assets/mouse/sprites/field_mouse-v2.png")
const CARRYING_TEXTURE: Texture2D = preload(
	"res://assets/mouse/sprites/field_mouse_carrying-v2.png"
)
const MOVEMENT_ACCELERATION: float = 420.0
const CARRYING_ACCELERATION: float = 310.0
const MOVING_SPEED_COMPENSATION: float = 1.12
const CARRYING_SPEED_MULTIPLIER: float = 0.82
const FACING_TURN_SPEED: float = 6.5
const SNIFF_MIN_PROGRESS: float = 0.18
const SNIFF_MAX_PROGRESS: float = 0.78
const TAIL_SOURCE_END_RATIO: float = 0.41
const BODY_SOURCE_START_RATIO: float = 0.30

var hole_position: Vector2 = Vector2.ZERO
var resource_position: Vector2 = Vector2.ZERO
var lane_offset: float = 0.0
var route_points: PackedVector2Array = PackedVector2Array()
var route_progress: float = 0.0
var represented_workers: int = 1
var outbound: bool = true
var carrying: bool = false
var visual_index: int = 0
var walk_phase: float = 0.0
var current_speed: float = 0.0
var _landing_squash: float = 0.0
var _activity_state: ActivityState = ActivityState.TRAVELING
var _activity_remaining: float = 0.0
var _behavior_elapsed: float = 0.0
var _observation_timer: float = 0.0
var _facing_sign: float = 1.0
var _tail_angle: float = 0.0
var _acceleration_pose: float = 0.0
var _sniff_intensity: float = 0.0
var _personality_speed: float = 1.0


func configure(start_position: Vector2, target_position: Vector2, offset: float, index: int) -> void:
	hole_position = start_position
	resource_position = target_position
	lane_offset = offset
	visual_index = index
	position = hole_position + Vector2(0.0, lane_offset)
	outbound = true
	carrying = false
	_reset_living_motion(index)
	queue_redraw()


func update_route(start_position: Vector2, target_position: Vector2) -> void:
	hole_position = start_position
	resource_position = target_position


func configure_route(
	points: PackedVector2Array,
	offset: float,
	index: int,
	initial_progress: float,
	worker_group_size: int
) -> void:
	route_points = points
	lane_offset = offset
	visual_index = index
	route_progress = clampf(initial_progress, 0.0, 0.92)
	represented_workers = maxi(1, worker_group_size)
	outbound = true
	carrying = false
	_reset_living_motion(index)
	_activity_state = ActivityState.TRAVELING
	_activity_remaining = 0.0
	position = _route_position(route_progress)
	queue_redraw()


func update_route_points(points: PackedVector2Array) -> void:
	route_points = points
	position = _route_position(route_progress)


func _process(delta: float) -> void:
	_landing_squash = maxf(_landing_squash - delta * 4.5, 0.0)
	_behavior_elapsed += delta
	_update_tail_motion(delta)
	if route_points.size() >= 2:
		_process_perspective_route(delta)
		return
	var destination: Vector2
	if outbound:
		destination = resource_position + Vector2(0.0, lane_offset)
	else:
		destination = hole_position + Vector2(0.0, lane_offset)
	var target_speed: float = _get_target_speed()
	_advance_speed(delta, target_speed)
	var move_distance: float = current_speed * delta
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

	_update_facing(delta)
	scale.x = _facing_sign
	queue_redraw()


func _process_perspective_route(delta: float) -> void:
	if _activity_state != ActivityState.TRAVELING:
		_process_activity(delta)
		return
	_observation_timer -= delta
	if (
		_observation_timer <= 0.0
		and outbound
		and not carrying
		and route_progress >= SNIFF_MIN_PROGRESS
		and route_progress <= SNIFF_MAX_PROGRESS
	):
		_activity_state = ActivityState.SNIFFING
		_activity_remaining = 0.45 + float(visual_index % 4) * 0.08
		_sniff_intensity = 1.0
		_reset_observation_timer()
		_process_activity(delta)
		return
	var previous_position: Vector2 = position
	_advance_speed(delta, _get_target_speed())
	var progress_delta: float = current_speed * delta / maxf(_route_length(), 1.0)
	route_progress += progress_delta if outbound else -progress_delta
	var reached_end: bool = outbound and route_progress >= 1.0
	var reached_hole: bool = not outbound and route_progress <= 0.0
	route_progress = clampf(route_progress, 0.0, 1.0)
	position = _route_position(route_progress)
	var traveled_distance: float = previous_position.distance_to(position)
	walk_phase = fposmod(walk_phase + traveled_distance * 0.115, TAU)

	if reached_end:
		_landing_squash = 1.0
		current_speed *= 0.32
		outbound = false
		carrying = true
		_activity_state = ActivityState.LOADING
		_activity_remaining = 0.65 + float(visual_index % 4) * 0.18
	elif reached_hole:
		_landing_squash = 1.0
		current_speed *= 0.25
		var group_capacity: int = GameManager.get_carry_capacity() * represented_workers
		var reward: int = GameManager.collect_trip(group_capacity)
		reward_delivered.emit(position, reward)
		_activity_state = ActivityState.ENTERING_HOLE
		_activity_remaining = 0.42

	var perspective_scale: float = _route_perspective_scale(route_progress)
	_update_facing(delta)
	scale = Vector2(_facing_sign * perspective_scale, perspective_scale)
	queue_redraw()


func _process_activity(delta: float) -> void:
	_activity_remaining -= delta
	_update_facing(delta)
	match _activity_state:
		ActivityState.SNIFFING:
			_advance_speed(delta, 0.0)
			_sniff_intensity = clampf(_activity_remaining / 0.24, 0.0, 1.0)
			var sniff_scale: float = _route_perspective_scale(route_progress)
			scale = Vector2(_facing_sign * sniff_scale, sniff_scale)
			if _activity_remaining <= 0.0:
				_sniff_intensity = 0.0
				_activity_state = ActivityState.TRAVELING
		ActivityState.LOADING:
			_advance_speed(delta, 0.0)
			_sniff_intensity = 0.7
			var loading_scale: float = _route_perspective_scale(route_progress)
			scale = Vector2(_facing_sign * loading_scale, loading_scale)
			if _activity_remaining <= 0.0:
				_sniff_intensity = 0.0
				_activity_state = ActivityState.TRAVELING
		ActivityState.ENTERING_HOLE:
			_advance_speed(delta, 0.0)
			var enter_ratio: float = clampf(_activity_remaining / 0.42, 0.0, 1.0)
			scale = Vector2(_facing_sign * enter_ratio, enter_ratio)
			modulate.a = enter_ratio
			if _activity_remaining <= 0.0:
				visible = false
				_activity_state = ActivityState.RESTING
				_activity_remaining = 2.4 + float((visual_index * 7) % 6) * 0.65
		ActivityState.RESTING:
			if _activity_remaining <= 0.0:
				visible = true
				modulate.a = 0.0
				outbound = true
				carrying = false
				current_speed = 0.0
				route_progress = 0.0
				position = _route_position(0.0)
				_activity_state = ActivityState.LEAVING_HOLE
				_activity_remaining = 0.48
		ActivityState.LEAVING_HOLE:
			_advance_speed(delta, _get_target_speed())
			var leave_ratio: float = clampf(1.0 - _activity_remaining / 0.48, 0.0, 1.0)
			scale = Vector2(_facing_sign * leave_ratio, leave_ratio)
			modulate.a = leave_ratio
			if _activity_remaining <= 0.0:
				modulate.a = 1.0
				scale = Vector2.ONE
				_activity_state = ActivityState.TRAVELING
		_:
			_activity_state = ActivityState.TRAVELING
	queue_redraw()


func get_activity_state_name() -> String:
	match _activity_state:
		ActivityState.TRAVELING:
			return "traveling"
		ActivityState.SNIFFING:
			return "sniffing"
		ActivityState.LOADING:
			return "loading"
		ActivityState.ENTERING_HOLE:
			return "entering_hole"
		ActivityState.RESTING:
			return "resting"
		ActivityState.LEAVING_HOLE:
			return "leaving_hole"
	return "unknown"


func _reset_living_motion(index: int) -> void:
	walk_phase = float(index) * 1.7
	current_speed = 0.0
	_landing_squash = 0.0
	_behavior_elapsed = float(index) * 0.37
	_facing_sign = 1.0
	_tail_angle = 0.0
	_acceleration_pose = 0.0
	_sniff_intensity = 0.0
	_personality_speed = 0.94 + float((index * 7) % 5) * 0.025
	_reset_observation_timer()


func _reset_observation_timer() -> void:
	_observation_timer = 4.2 + float((visual_index * 11 + 3) % 7) * 0.47


func _get_target_speed() -> float:
	var carry_multiplier: float = CARRYING_SPEED_MULTIPLIER if carrying else 1.0
	var cadence: float = 0.96 + sin(
		_behavior_elapsed * 1.35 + float(visual_index) * 1.7
	) * 0.04
	return (
		GameManager.get_move_speed()
		* MOVING_SPEED_COMPENSATION
		* _personality_speed
		* carry_multiplier
		* cadence
	)


func _advance_speed(delta: float, target_speed: float) -> void:
	var base_speed: float = maxf(GameManager.get_move_speed(), 1.0)
	var desired_pose: float = clampf(
		(target_speed - current_speed) / base_speed,
		-1.0,
		1.0
	)
	_acceleration_pose = lerpf(
		_acceleration_pose,
		desired_pose,
		1.0 - exp(-delta * 7.0)
	)
	var acceleration: float = (
		CARRYING_ACCELERATION
		if carrying
		else MOVEMENT_ACCELERATION
	)
	current_speed = move_toward(current_speed, target_speed, acceleration * delta)


func _update_facing(delta: float) -> void:
	var desired_facing: float = 1.0 if outbound else -1.0
	_facing_sign = move_toward(
		_facing_sign,
		desired_facing,
		FACING_TURN_SPEED * delta
	)


func _update_tail_motion(delta: float) -> void:
	var movement_ratio: float = clampf(
		current_speed / maxf(GameManager.get_move_speed(), 1.0),
		0.0,
		1.0
	)
	var carry_weight: float = 0.58 if carrying else 1.0
	var sniff_wave: float = sin(_behavior_elapsed * 14.0) * _sniff_intensity
	var target_angle: float = (
		sin(walk_phase * 0.72 + float(visual_index)) * 0.055 * movement_ratio
		+ sniff_wave * 0.018
		- _acceleration_pose * 0.025
	) * carry_weight
	_tail_angle = lerp_angle(
		_tail_angle,
		target_angle,
		1.0 - exp(-delta * 5.2)
	)


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
	var movement_ratio: float = clampf(
		current_speed / maxf(GameManager.get_move_speed(), 1.0),
		0.0,
		1.0
	)
	var lift: float = absf(stride_wave) * movement_ratio
	var carrying_weight: float = 0.72 if carrying else 1.0
	var sniff_wave: float = sin(_behavior_elapsed * 14.0) * _sniff_intensity
	var bob_offset: float = (
		-lift * 1.4 * carrying_weight
		+ _landing_squash * 1.2
		+ sniff_wave * 0.45
		+ (1.1 if carrying else 0.0)
	)
	var body_rotation: float = (
		stride_wave * 0.012 * carrying_weight * movement_ratio
		+ sniff_wave * 0.009
		- _acceleration_pose * 0.014
	)
	var body_scale: Vector2 = Vector2(
		1.0
		+ lift * 0.012
		+ _acceleration_pose * 0.026
		- _landing_squash * 0.025,
		1.0
		- lift * 0.022
		- _acceleration_pose * 0.018
		+ _landing_squash * 0.045
		+ sniff_wave * 0.006
	)
	_draw_ground_shadow(lift)
	_draw_foot_contacts(stride_wave, movement_ratio)
	var active_texture: Texture2D = CARRYING_TEXTURE if carrying else MOUSE_TEXTURE
	_draw_living_mouse_texture(
		active_texture,
		Vector2(0.0, bob_offset),
		body_rotation,
		body_scale
	)
	draw_set_transform(Vector2.ZERO)


func _draw_living_mouse_texture(
	texture: Texture2D,
	body_offset: Vector2,
	body_rotation: float,
	body_scale: Vector2
) -> void:
	var source_size: Vector2 = texture.get_size()
	var destination: Rect2 = Rect2(Vector2(-39.0, -53.0), Vector2(78.0, 53.0))
	if source_size.x <= 1.0 or source_size.y <= 1.0:
		draw_set_transform(body_offset, body_rotation, body_scale)
		draw_texture_rect(texture, destination, false)
		return

	var tail_source_width: float = source_size.x * TAIL_SOURCE_END_RATIO
	var body_source_x: float = source_size.x * BODY_SOURCE_START_RATIO
	var source_to_destination: Vector2 = Vector2(
		destination.size.x / source_size.x,
		destination.size.y / source_size.y
	)
	var tail_source: Rect2 = Rect2(
		Vector2.ZERO,
		Vector2(tail_source_width, source_size.y)
	)
	var tail_destination: Rect2 = Rect2(
		destination.position,
		Vector2(
			tail_source_width * source_to_destination.x,
			destination.size.y
		)
	)
	var tail_pivot: Vector2 = Vector2(-12.0, -19.0)
	draw_set_transform(
		body_offset + tail_pivot,
		body_rotation + _tail_angle,
		body_scale
	)
	draw_texture_rect_region(
		texture,
		Rect2(tail_destination.position - tail_pivot, tail_destination.size),
		tail_source
	)

	var body_source: Rect2 = Rect2(
		Vector2(body_source_x, 0.0),
		Vector2(source_size.x - body_source_x, source_size.y)
	)
	var body_destination: Rect2 = Rect2(
		destination.position + Vector2(body_source_x * source_to_destination.x, 0.0),
		Vector2(body_source.size.x * source_to_destination.x, destination.size.y)
	)
	draw_set_transform(body_offset, body_rotation, body_scale)
	draw_texture_rect_region(texture, body_destination, body_source)


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


func _draw_foot_contacts(stride_wave: float, movement_ratio: float) -> void:
	var front_alpha: float = (
		clampf(stride_wave, 0.0, 1.0) * 0.18 * movement_ratio
	)
	var back_alpha: float = (
		clampf(-stride_wave, 0.0, 1.0) * 0.18 * movement_ratio
	)
	draw_line(Vector2(12.0, 0.0), Vector2(23.0, 0.0), Color(0.12, 0.08, 0.08, front_alpha), 2.0, true)
	draw_line(Vector2(-20.0, 0.0), Vector2(-9.0, 0.0), Color(0.12, 0.08, 0.08, back_alpha), 2.0, true)
