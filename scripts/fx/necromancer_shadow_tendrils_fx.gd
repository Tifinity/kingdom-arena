extends AnimatedSprite2D


func _ready() -> void:
	animation_finished.connect(queue_free)
	play(&"default")


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	if source == null:
		return
	var cast_target: Unit = source.current_cast.target if source.current_cast != null else source.target
	var center := source.global_position
	if cast_target != null and is_instance_valid(cast_target):
		center = cast_target.global_position
	# pixelfx 原点在帧内 (104, 106)，贴到目标脚下。
	global_position = center + Vector2(0, -41.0 * scale.y)
