class_name UnitSelectionRing
extends Node2D

## 选中单位的金色虚线圈。

var radius := 40.0
var attack_range := 0.0
var skill_range := 0.0
var _time := 0.0
const GOLD := Color("#e7c46b")


func setup(ring_radius: float) -> void:
	radius = ring_radius
	queue_redraw()


func set_combat_ranges(p_attack_range: float, p_skill_range: float) -> void:
	attack_range = p_attack_range
	skill_range = p_skill_range
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	# 调试范围：选中单位时显示基础攻击距离与技能距离。
	if attack_range > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(0.45, 0.72, 1.0, 0.26), 1.6, true)
		if skill_range > attack_range + 0.5:
			var segments := 28
			for index in segments:
				if index % 2 == 0:
					var start := TAU * float(index) / float(segments)
					draw_arc(Vector2.ZERO, skill_range, start, start + TAU / float(segments), 4, Color(1.0, 0.58, 0.22, 0.30), 1.8, true)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(GOLD, 0.16), 1.5, true)
	for index in 8:
		var start := _time * 1.4 + TAU * float(index) / 8.0
		draw_arc(Vector2.ZERO, radius, start, start + 0.26, 6, Color(GOLD, 0.85), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
