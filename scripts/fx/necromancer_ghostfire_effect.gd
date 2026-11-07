class_name NecromancerGhostFireEffect
extends AnimatedSprite2D

## 鬼火不飞行，直接在锁定目标的位置播放。
func _ready() -> void:
	animation_finished.connect(queue_free)
	if sprite_frames != null and sprite_frames.has_animation(&"default"):
		play(&"default")


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	if source == null:
		return
	if source.target != null and is_instance_valid(source.target):
		global_position = source.target.get_hit_point()
	else:
		global_position = source.get_hit_point()
	play(&"default")
