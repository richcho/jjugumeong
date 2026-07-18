class_name GatheringMouse
extends Node2D

signal reward_delivered(world_position: Vector2, amount: int)

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
	) * 2.0
	draw_set_transform(Vector2(0.0, bob_offset))
	var body_color: Color = Color("#9aa0a8")
	var ear_color: Color = Color("#d9a7b0")
	var outline_color: Color = Color("#34313a")
	draw_circle(Vector2.ZERO, 15.0, outline_color)
	draw_circle(Vector2.ZERO, 12.5, body_color)
	draw_circle(Vector2(-7.0, -10.0), 6.0, outline_color)
	draw_circle(Vector2(-7.0, -10.0), 4.2, ear_color)
	draw_circle(Vector2(9.0, -1.0), 3.0, Color("#e5bcc2"))
	draw_circle(Vector2(5.0, -6.0), 2.0, Color("#17141a"))
	draw_arc(Vector2(-12.0, 4.0), 13.0, 1.4, 3.3, 14, Color("#d9a7b0"), 2.0, true)
	draw_circle(Vector2(-5.0, 11.0), 3.0, Color("#56515b"))
	draw_circle(Vector2(6.0, 11.0), 3.0, Color("#56515b"))
	if GameManager.speed_level >= 1:
		draw_line(Vector2(-9.0, -3.0), Vector2(-19.0, 5.0), Color("#e45f6f"), 4.0, true)
		draw_line(Vector2(-17.0, 5.0), Vector2(-25.0, 1.0), Color("#f28b78"), 3.0, true)
	if GameManager.carry_level >= 1:
		var bag_color: Color = Color("#b98550") if GameManager.carry_level < 3 else Color("#537e8c")
		draw_rect(Rect2(Vector2(-11.0, -2.0), Vector2(9.0, 12.0)), bag_color, true)
		draw_arc(Vector2(-6.5, -2.0), 5.0, PI, TAU, 10, Color("#e7c18a"), 2.0, true)
	if carrying:
		var cheese_center: Vector2 = Vector2(-2.0, -21.0)
		draw_colored_polygon(PackedVector2Array([
			cheese_center + Vector2(-7.0, 5.0),
			cheese_center + Vector2(7.0, 5.0),
			cheese_center + Vector2(5.0, -6.0)
		]), Color("#f6c445"))
		draw_circle(cheese_center + Vector2(1.0, 1.0), 1.5, Color("#c88b24"))
