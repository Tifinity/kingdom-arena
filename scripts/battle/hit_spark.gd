class_name HitSpark
extends Node2D

## 命中先闪出十字亮芯，再散为像素碎屑。

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
	var distance := (8.0 + 28.0 * k) * scale_factor
	if k < 0.28:
		var core := Color("#fff0ce")
		draw_rect(Rect2(-2, -6, 4, 12), core)
		draw_rect(Rect2(-6, -2, 12, 4), core)
	for index in _angles.size():
		var direction := Vector2.from_angle(_angles[index])
		var reach := distance * (0.76 + 0.14 * (index % 3))
		var end := direction * reach + Vector2(0, k * k * 9.0)
		var start := end - direction * maxf(0.0, 16.0 * (1.0 - k * 1.35))
		var color := tint.lightened(0.64 if k < 0.38 else 0.24)
		color.a = 1.0 - k
		PixelCombatDraw.streak(self, start, end, color)
