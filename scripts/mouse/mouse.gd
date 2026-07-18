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


func _process(delta: float) -> void:
	_landing_squash = maxf(_landing_squash - delta * 4.5, 0.0)
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


func _draw() -> void:
	var stride_wave: float = sin(walk_phase)
	var lift: float = absf(stride_wave)
	var carrying_weight: float = 0.72 if carrying else 1.0
	var bob_offset: float = -lift * 3.2 * carrying_weight + _landing_squash * 1.8
	var body_rotation: float = stride_wave * 0.035 * carrying_weight
	var body_scale: Vector2 = Vector2(
		1.0 + lift * 0.025 - _landing_squash * 0.035,
		1.0 - lift * 0.045 + _landing_squash * 0.065
	)
	_draw_ground_shadow(lift)
	_draw_dust_puff()
	_draw_foot_contacts(stride_wave)
	draw_set_transform(Vector2(0.0, bob_offset), body_rotation, body_scale)
	var active_texture: Texture2D = CARRYING_TEXTURE if carrying else MOUSE_TEXTURE
	draw_texture_rect(active_texture, Rect2(Vector2(-39.0, -53.0), Vector2(78.0, 53.0)), false)
	if GameManager.speed_level >= 1:
		draw_line(Vector2(-4.0, -28.0), Vector2(-19.0, -19.0), Color("#e45f6f"), 4.0, true)
		draw_line(Vector2(-17.0, -20.0), Vector2(-27.0, -25.0), Color("#f28b78"), 3.0, true)
	if GameManager.carry_level >= 1:
		var bag_color: Color = Color("#b98550") if GameManager.carry_level < 3 else Color("#537e8c")
		draw_rect(Rect2(Vector2(-12.0, -34.0), Vector2(15.0, 17.0)), bag_color, true)
		draw_arc(Vector2(-4.5, -33.0), 8.0, PI, TAU, 12, Color("#e7c18a"), 2.0, true)
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
	var front_alpha: float = clampf(stride_wave, 0.0, 1.0) * 0.32
	var back_alpha: float = clampf(-stride_wave, 0.0, 1.0) * 0.32
	draw_line(Vector2(12.0, 0.0), Vector2(23.0, 0.0), Color(0.12, 0.08, 0.08, front_alpha), 2.0, true)
	draw_line(Vector2(-20.0, 0.0), Vector2(-9.0, 0.0), Color(0.12, 0.08, 0.08, back_alpha), 2.0, true)
