class_name UnitHealthBar
extends Node2D

## 单位头顶血条：平滑追赶真实生命值，队伍色填充。

var bar_width := 54.0
var bar_height := 6.0
var ratio := 1.0
var shield_ratio := 0.0
var _shown := 1.0
var _shown_shield := 0.0
var _team_color := Color("#58a6ff")


func setup(width: float, team_color: Color) -> void:
	bar_width = maxf(width, 36.0)
	_team_color = team_color
	queue_redraw()


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)


func set_shield_ratio(value: float) -> void:
	shield_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if absf(_shown - ratio) < 0.001 and absf(_shown_shield - shield_ratio) < 0.001:
		_shown = ratio
		_shown_shield = shield_ratio
		return
	_shown = lerpf(_shown, ratio, 1.0 - exp(-14.0 * delta))
	_shown_shield = lerpf(_shown_shield, shield_ratio, 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _draw() -> void:
	var left := -bar_width * 0.5
	draw_rect(Rect2(left - 1.0, -1.0, bar_width + 2.0, bar_height + 2.0), Color(0.015, 0.025, 0.04, 0.9))
	draw_rect(Rect2(left, 0.0, bar_width, bar_height), Color(0.09, 0.12, 0.17, 0.95))
	var fill_width := bar_width * _shown
	if fill_width > 0.0:
		draw_rect(Rect2(left, 0.0, fill_width, bar_height), _team_color.darkened(0.18))
		draw_rect(Rect2(left, 0.0, fill_width, 2.0), _team_color.lightened(0.35))
	if _shown_shield > 0.001:
		draw_rect(Rect2(left, -4.0, bar_width * _shown_shield, 3.0), Color(0.35, 0.85, 1.0, 0.95))
	# 分段刻度，便于快速读血量。
	for index in range(1, 4):
		var x := left + bar_width * (float(index) / 4.0)
		draw_line(Vector2(x, 0.0), Vector2(x, bar_height), Color(0.03, 0.05, 0.08, 0.55), 1.0)
