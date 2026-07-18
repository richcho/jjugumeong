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


func configure(start_position: Vector2, target_position: Vector2, offset: float, index: int) -> void:
	hole_position = start_position
	resource_position = target_position
	lane_offset = offset
	visual_index = index
	position = hole_position + Vector2(0.0, lane_offset)
	outbound = true
	carrying = false
	queue_redraw()


func update_route(start_position: Vector2, target_position: Vector2) -> void:
	hole_position = start_position
	resource_position = target_position


func _process(delta: float) -> void:
	var destination: Vector2
	if outbound:
		destination = resource_position + Vector2(0.0, lane_offset)
	else:
		destination = hole_position + Vector2(0.0, lane_offset)
	var move_distance: float = GameManager.get_move_speed() * delta
	position = position.move_toward(destination, move_distance)
	if position.distance_squared_to(destination) <= 1.0:
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
	var bob_offset: float = sin(
		float(Time.get_ticks_msec()) * 0.012 + float(visual_index) * 1.7
	) * 1.25
	draw_set_transform(Vector2(0.0, bob_offset))
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
