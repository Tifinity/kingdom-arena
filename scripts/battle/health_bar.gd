class_name UnitHealthBar
extends Node2D

## 血量变化有缓动，显示宽度按一格美术像素取整。
const PIXEL := 4.0
const SHIELD := Color("#94d7e1")

var bar_width := 56.0
var bar_height := 8.0
var ratio := 1.0
var shield_ratio := 0.0
var _shown := 1.0
var _shown_shield := 0.0
var _team_color := Color("#82bdcf")


func setup(width: float, team_color: Color) -> void:
	bar_width = snappedf(maxf(width, 36.0), PIXEL * 2.0)
	_team_color = team_color
	queue_redraw()


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)


func set_shield_ratio(value: float) -> void:
	shield_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	var old_health := _filled_width(_shown)
	var old_shield := _filled_width(_shown_shield)
	if absf(_shown - ratio) < 0.001 and absf(_shown_shield - shield_ratio) < 0.001:
		_shown = ratio
		_shown_shield = shield_ratio
	else:
		_shown = lerpf(_shown, ratio, 1.0 - exp(-14.0 * delta))
		_shown_shield = lerpf(_shown_shield, shield_ratio, 1.0 - exp(-14.0 * delta))
	if old_health != _filled_width(_shown) or old_shield != _filled_width(_shown_shield):
		queue_redraw()


func _filled_width(value: float) -> float:
	return ceilf(value * bar_width / PIXEL) * PIXEL if value >= 0.001 else 0.0


func _draw() -> void:
	var left := -bar_width * 0.5
	draw_rect(Rect2(left - PIXEL, -PIXEL, bar_width + 2.0 * PIXEL, bar_height + 2.0 * PIXEL), Color("#141222"))
	draw_rect(Rect2(left, 0.0, bar_width, bar_height), Color("#40354d"))
	var fill_width := _filled_width(_shown)
	if fill_width > 0.0:
		draw_rect(Rect2(left, PIXEL, fill_width, PIXEL), _team_color.darkened(0.36))
		draw_rect(Rect2(left, 0.0, fill_width, PIXEL), _team_color)
	var shield_width := _filled_width(_shown_shield)
	if shield_width > 0.0:
		draw_rect(Rect2(left, -PIXEL, shield_width, PIXEL), SHIELD)
