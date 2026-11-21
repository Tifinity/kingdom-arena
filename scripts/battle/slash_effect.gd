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
	var radius := 30.0 + 18.0 * k
	var mid := 0.0 if facing > 0 else PI
	var tilt := -0.24 * facing
	var start := mid - 1.18 + k * 1.02
	var end := mid + 1.04
	var steps := ceili(radius * (end - start) / 3.0)
	var previous := Vector2.INF
	for index in range(steps + 1):
		var progress := float(index) / float(steps)
		var direction := Vector2.from_angle(lerpf(start, end, progress)) * Vector2(1.0, 0.86)
		var tip := (direction.rotated(tilt) * radius).snapped(PixelCombatDraw.CELL)
		if tip == previous:
			continue
		var rim := tint.lightened(0.76 if k < 0.4 else 0.34)
		PixelCombatDraw.dot(self, tip, Color(rim, alpha))
		if progress > 0.22 and progress < 0.95:
			var inside := direction.rotated(tilt) * (radius - 5.0)
			PixelCombatDraw.dot(self, inside, Color(tint, alpha * 0.76))
		previous = tip
