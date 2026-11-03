class_name UnitSelectionRing
extends Node2D

## 选中单位的金色虚线圈。

var radius := 40.0
var _time := 0.0
const GOLD := Color("#e7c46b")


func setup(ring_radius: float) -> void:
	radius = ring_radius
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(GOLD, 0.16), 1.5, true)
	for index in 8:
		var start := _time * 1.4 + TAU * float(index) / 8.0
		draw_arc(Vector2.ZERO, radius, start, start + 0.26, 6, Color(GOLD, 0.85), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
