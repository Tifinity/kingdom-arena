class_name UnitDeathState
extends UnitState

## 死亡：播放死亡动画，尸体停留片刻后淡出并释放。


func enter(_previous: StringName) -> void:
	unit.visual.speed_scale = 1.0
	unit.visual.modulate = Color.WHITE
	unit.play_animation(&"death", true)
	var hold := 0.9
	if unit.definition != null and unit.definition.sprite_frames != null:
		var frames := unit.definition.sprite_frames.get_frame_count(&"death")
		var speed := unit.definition.sprite_frames.get_animation_speed(&"death")
		hold = maxf(0.75, float(frames) / maxf(speed, 0.01))
	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(unit.visual, "modulate:a", 0.0, 0.65)
	tween.parallel().tween_property(unit.shadow, "modulate:a", 0.0, 0.65)
	tween.tween_callback(unit.queue_free)
