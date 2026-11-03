class_name HitSpark
extends Node2D

## 命中小火花：扩散圆环 + 短线。魔法命中的范围更大。

var life := 0.26
var tint := Color.WHITE
var scale_factor := 1.0
var _time := 0.0
var _angles: Array[float] = []


func setup(at: Vector2, color: Color, size := 1.0) -> void:
	position = at
	tint = color
	scale_factor = size
	z_index = 12
	for index in 8:
		_angles.append(float(index) * TAU / 8.0 + randf() * 0.4)


func _process(delta: float) -> void:
	_time += delta
	if _time >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / life, 0.0, 1.0)
	var radius := (8.0 + 24.0 * k) * scale_factor
	draw_circle(Vector2.ZERO, radius * 0.55, Color(tint, (1.0 - k) * 0.30))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, (1.0 - k) * 0.75), 2.0, true)
	for angle in _angles:
		var start := Vector2.from_angle(angle) * radius * 0.4
		var end := Vector2.from_angle(angle) * radius * (1.0 + 0.4 * k)
		draw_line(start, end, Color(tint.lightened(0.4), (1.0 - k) * 0.8), 2.0)
