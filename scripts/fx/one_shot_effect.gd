class_name OneShotEffect
extends AnimatedSprite2D

## 播放一次 default 动画后自动释放。


func _ready() -> void:
	animation_finished.connect(queue_free)
	if sprite_frames != null and sprite_frames.has_animation(&"default"):
		play(&"default")
