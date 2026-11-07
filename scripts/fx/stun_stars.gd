class_name StunStars
extends Node2D

## 眩晕状态特效：三颗金色小星星围绕头顶旋转。
##
## 由 Unit 在进入/结束眩晕时调用 play() / stop()，自身只负责表现，
## 不参与伤害或状态判定。星星用 _draw() 程序化绘制，不依赖额外贴图。

const STAR_COUNT := 3

## 椭圆轨道的横向/纵向半径；纵向刻意压扁，模拟绕头旋转的透视感。
@export var orbit_radius_x := 22.0
@export var orbit_radius_y := 7.5
@export var star_radius := 6.2
@export var orbit_speed := 4.6
@export var gold := Color("#ffd35e")
@export var gold_dark := Color("#8a5a12")

var _playing := false
var _angle := 0.0
var _fade := 0.0
var _pulse := 0.0


func _ready() -> void:
	z_index = 30
	visible = false
	set_process(false)
	queue_redraw()


## 开始播放；重复调用会重新做一次淡入，但不会重置旋转角度。
func play() -> void:
	_playing = true
	_fade = 0.0
	visible = true
	set_process(true)
	queue_redraw()


## 立即结束并隐藏。
func stop() -> void:
	_playing = false
	visible = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func star_count() -> int:
	return STAR_COUNT


func _process(delta: float) -> void:
	if not _playing:
		return
	_angle = fmod(_angle + orbit_speed * delta, TAU)
	_fade = minf(1.0, _fade + delta * 9.0)
	_pulse = fmod(_pulse + delta * 6.0, TAU)
	queue_redraw()


func _draw() -> void:
	if not _playing:
		return
	var alpha := _fade
	# 柔和的金色光晕，让星星在混战中更容易被看到。
	draw_circle(Vector2.ZERO, orbit_radius_x * 1.05, Color(gold, 0.055 * alpha))
	draw_circle(Vector2.ZERO, orbit_radius_x * 0.62, Color(gold, 0.065 * alpha))

	for index in STAR_COUNT:
		var orbit := _angle + TAU * float(index) / float(STAR_COUNT)
		# sin > 0 表示转到轨道前半圈，画得更大更亮。
		var depth := (sin(orbit) + 1.0) * 0.5
		var bob := sin(_pulse + float(index) * 1.3) * 1.1
		var center := Vector2(
			cos(orbit) * orbit_radius_x,
			sin(orbit) * orbit_radius_y + bob - 1.5
		)
		var radius := star_radius * lerpf(0.72, 1.0, depth)
		var spin := -_angle * 1.7 + float(index) * 0.9
		var star_alpha := alpha * lerpf(0.62, 1.0, depth)

		draw_circle(center, radius * 1.45, Color(gold, 0.10 * star_alpha))
		_draw_star(center, radius + 1.25, spin, Color(gold_dark, star_alpha * 0.9))
		_draw_star(center, radius, spin, Color(gold, star_alpha))
		_draw_star(center, radius * 0.52, spin + 0.12, Color(1.0, 0.97, 0.78, star_alpha * 0.92))


func _draw_star(center: Vector2, radius: float, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in 10:
		var point_radius := radius if point_index % 2 == 0 else radius * 0.42
		var angle := rotation - PI * 0.5 + float(point_index) * PI / 5.0
		points.append(center + Vector2.from_angle(angle) * point_radius)
	draw_colored_polygon(points, color)
