extends Node2D

## 圣光裁决的纯视觉冲击波。方向与范围直接读取伤害效果，保持表现与命中形状一致。

var radius := 190.0
var half_angle := deg_to_rad(55.0)
var life := 0.38
var elapsed := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(source) or effect == null:
		queue_free()
		return
	global_position = source.global_position
	radius = maxf(effect.radius, 1.0)
	half_angle = deg_to_rad(absf(effect.half_angle))
	var aim := source.current_cast.direction if source.current_cast != null else source.planned_direction
	if aim.length_squared() < 0.0001 and is_instance_valid(source.target):
		aim = source.target.global_position - source.global_position
	if aim.length_squared() < 0.0001:
		aim = Vector2(float(source.facing), 0.0)
	rotation = aim.angle()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / life, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var front := lerpf(22.0, radius, eased)
	var tail := maxf(0.0, front - lerpf(46.0, 27.0, progress))
	var fade := pow(1.0 - progress, 0.75)
	var start := -half_angle
	var finish := half_angle
	var steps := 24
	var warm := Color(1.0, 0.72, 0.18, 0.20 * fade)
	for index in steps:
		var a := lerpf(start, finish, float(index) / float(steps))
		var b := lerpf(start, finish, float(index + 1) / float(steps))
		draw_colored_polygon(PackedVector2Array([
			Vector2.from_angle(a) * tail,
			Vector2.from_angle(a) * front,
			Vector2.from_angle(b) * front,
			Vector2.from_angle(b) * tail,
		]), warm)
	# 三道半透明弧构成向外推开的波前，最亮的一道贴近剑气边缘。
	draw_arc(Vector2.ZERO, front, start, finish, 32, Color(1.0, 0.54, 0.10, 0.32 * fade), 24.0, true)
	draw_arc(Vector2.ZERO, front, start, finish, 32, Color(1.0, 0.82, 0.30, 0.88 * fade), 11.0, true)
	draw_arc(Vector2.ZERO, front - 4.0, start, finish, 32, Color(1.0, 0.98, 0.78, fade), 4.0, true)
	draw_arc(Vector2.ZERO, maxf(0.0, front - 24.0), start, finish, 28,
		Color(1.0, 0.67, 0.17, 0.28 * fade), 3.0, true)
	# 放射状碎光跟随波前，提供冲击感；位置固定，避免随机闪烁。
	for index in 9:
		var angle := lerpf(start + 0.08, finish - 0.08, float(index) / 8.0)
		var direction := Vector2.from_angle(angle)
		var stagger := 0.8 + float((index * 3) % 5) * 0.045
		var outer := front * stagger
		draw_line(direction * (outer - 14.0), direction * (outer + 9.0),
			Color(1.0, 0.92, 0.52, 0.65 * fade), 2.0)
		if index % 2 == 0:
			draw_circle(direction * (outer + 11.0), 2.4 * (1.0 - progress * 0.5),
				Color(1.0, 1.0, 0.83, 0.85 * fade))
