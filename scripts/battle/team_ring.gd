class_name UnitTeamRing
extends Node2D

## 脚下的队伍色圆环，帮助在混战中区分敌我。

var draw_in_3d := false
var radius := 30.0
var ring_color := Color("#58a6ff")


func setup(team_color: Color, ring_radius: float) -> void:
	ring_color = team_color
	radius = ring_radius
	queue_redraw()


func _draw() -> void:
	if draw_in_3d:
		return
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ring_color, 0.60), 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
