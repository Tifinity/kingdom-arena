@tool
extends Node2D

## 编辑器专用对照台：复用实战人物视觉场景与技能特效场景。
@export var preview_play := true
@export_range(0.0, 2.0, 0.033) var preview_time := 0.0
@export_range(0.1, 3.0, 0.1) var preview_actor_speed := 1.0
@export_range(0.1, 3.0, 0.1) var preview_effect_speed := 1.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)
		return
	var effect := get_node_or_null("Effect")
	if effect != null:
		effect.set("preview_play", false)
	_update_preview()


func _process(delta: float) -> void:
	if preview_play:
		preview_time = fmod(preview_time + delta, 2.0)
	_update_preview()


func _update_preview() -> void:
	var body := get_node_or_null("Axeman/Body") as AnimatedSprite2D
	var effect := get_node_or_null("Effect")
	if body == null or effect == null:
		return
	body.animation = &"attack_01"
	var count := body.sprite_frames.get_frame_count(&"attack_01")
	var fps := body.sprite_frames.get_animation_speed(&"attack_01")
	body.frame = mini(int(preview_time * preview_actor_speed * fps) + 1, count - 1)
	effect.set("preview_time", fmod(preview_time * preview_effect_speed, 1.9))
