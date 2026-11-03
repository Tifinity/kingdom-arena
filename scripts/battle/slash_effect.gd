class_name SlashEffect
extends Node2D

## 近战挥砍弧光。

var life := 0.18
var tint := Color.WHITE
var facing := 1
var _time := 0.0


func setup(at: Vector2, color: Color, direction: float) -> void:
	position = at
	tint = color
	facing = 1 if direction >= 0.0 else -1
	z_index = 11


func _process(delta: float) -> void:
	_time += delta
	if _time >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / life, 0.0, 1.0)
	var alpha := 1.0 - k
	var radius := 26.0 + 26.0 * k
	var mid := 0.0 if facing > 0 else PI
	var start := mid - 1.1
	var end := mid + 1.1
	draw_arc(Vector2.ZERO, radius, start, end, 16, Color(tint, alpha * 0.85), 4.0 * (1.0 - k * 0.5), true)
	draw_arc(Vector2.ZERO, radius * 0.82, start + 0.2, end - 0.2, 12, Color(1.0, 1.0, 1.0, alpha * 0.55), 1.5, true)
	for index in 3:
		var angle := lerpf(start, end, float(index) / 2.0)
		var direction := Vector2.from_angle(angle)
		draw_line(direction * radius * 0.75, direction * radius * 1.08, Color(tint, alpha), 1.5)
