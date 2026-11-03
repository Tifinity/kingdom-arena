class_name DamageNumber
extends Node2D

## 飘字伤害数字。

var _label: Label


func _ready() -> void:
	_label = $Label


func setup(value: float, color: Color, at: Vector2) -> void:
	setup_text("-%d" % maxi(1, roundi(value)), color, at)


func setup_text(text: String, color: Color, at: Vector2) -> void:
	position = at
	z_index = 30
	if _label == null:
		_label = $Label
	_label.text = text
	_label.add_theme_color_override("font_color", color.lightened(0.25))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", at + Vector2(0, -48), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tween.chain().tween_callback(queue_free)
