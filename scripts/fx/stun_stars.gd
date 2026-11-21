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
var _draw_frame := -1
var _elapsed := 0.0


func _ready() -> void:
	z_index = 30
	visible = false
	set_process(false)
	queue_redraw()


## 开始播放；重复调用会重新做一次淡入，但不会重置旋转角度。
func play() -> void:
	_playing = true
	_fade = 0.0
	_draw_frame = -1
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
	_elapsed += delta
	var frame := int(_elapsed * 12.0)
	if _draw_frame != frame:
		_draw_frame = frame
		queue_redraw()


func _draw() -> void:
	if not _playing:
		return
	for index in STAR_COUNT:
		var orbit := _angle + TAU * float(index) / float(STAR_COUNT)
		var depth := (sin(orbit) + 1.0) * 0.5
		var bob := sin(_pulse + float(index) * 1.3) * 2.0
		var center := Vector2(cos(orbit) * orbit_radius_x, sin(orbit) * orbit_radius_y + bob)
		center = center.snapped(Vector2(4, 4))
		var extent := maxf(4.0, snappedf(star_radius * lerpf(0.9, 1.4, depth), 4.0))
		var alpha := _fade * lerpf(0.6, 1.0, depth)
		draw_rect(Rect2(center - Vector2(4.0, extent), Vector2(8.0, extent * 2.0)), Color(gold_dark, alpha))
		draw_rect(Rect2(center - Vector2(extent, 4.0), Vector2(extent * 2.0, 8.0)), Color(gold_dark, alpha))
		draw_rect(Rect2(center - Vector2(2.0, extent), Vector2(4.0, extent * 2.0)), Color(gold, alpha))
		draw_rect(Rect2(center - Vector2(extent, 2.0), Vector2(extent * 2.0, 4.0)), Color(gold, alpha))
