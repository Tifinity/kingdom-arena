class_name FlameSlashAoe
extends Node2D

## 骑士火焰斩击的地面扇形表现。伤害由 ActionEffect 结算，本节点只做视觉。

var radius := 170.0
var half_angle := 65.0
var facing := 1
var life := 0.55
var _time := 0.0
var _embers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	global_position = source.global_position
	radius = effect.radius
	half_angle = effect.half_angle
	facing = source.facing
	z_index = 12
	_rng.seed = Time.get_ticks_usec()
	for index in 18:
		_embers.append({
			"angle": _rng.randf_range(-half_angle, half_angle),
			"speed": _rng.randf_range(0.35, 1.0),
			"size": _rng.randf_range(1.0, 3.0),
			"offset": _rng.randf_range(0.0, 0.15),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _time >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / life, 0.0, 1.0)
	var dir := 1.0 if facing > 0 else -1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))

	var start := deg_to_rad(-half_angle)
	var end := deg_to_rad(half_angle)
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 18
	for index in steps + 1:
		var angle := lerpf(start, end, float(index) / float(steps))
		var direction := Vector2.from_angle(angle) * radius * (0.82 + 0.18 * k)
		direction.x *= dir
		points.append(direction)
	draw_colored_polygon(points, Color(1.0, 0.32, 0.05, (1.0 - k) * 0.14))

	for band in 4:
		var r := radius * (0.35 + 0.17 * band) * (0.92 + 0.08 * k)
		var alpha := (1.0 - k) * (0.34 - band * 0.055)
		var arc_start := start if dir > 0.0 else PI - end
		var arc_end := end if dir > 0.0 else PI - start
		draw_arc(Vector2.ZERO, r, arc_start, arc_end, 20, Color(1.0, 0.55 + band * 0.1, 0.12, alpha), 4.0 - band * 0.6, true)

	# 剑刃扫过的中心亮线
	var shine_start := Vector2.from_angle(start + 0.25) * radius * 0.25
	var shine_end := Vector2.from_angle(end - 0.25) * radius * 0.95
	shine_start.x *= dir
	shine_end.x *= dir
	draw_line(shine_start, shine_end, Color(1.0, 0.93, 0.62, (1.0 - k) * 0.7), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for ember in _embers:
		var t: float = _time - float(ember["offset"])
		if t <= 0.0:
			continue
		var angle: float = ember["angle"]
		var distance: float = radius * float(ember["speed"]) * clampf(t / life * 1.7, 0.0, 1.0)
		var pos := Vector2(cos(deg_to_rad(angle)) * distance * dir, sin(deg_to_rad(angle)) * distance * 0.55)
		var alpha := clampf(1.0 - t / life, 0.0, 1.0)
		draw_circle(pos, float(ember["size"]) * (0.6 + alpha), Color(1.0, 0.55, 0.16, alpha * 0.8))
