class_name UnitHurtState
extends UnitState

## 控制效果打断动作时的受击姿态；普通伤害不进入此状态。
## 眩晕期间保持受击动画，结束后恢复待机。

const DURATION := 0.26

var _elapsed := 0.0
var _stun_hold := false


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_stun_hold = unit.is_stunned()
	unit.visual.speed_scale = 1.0
	unit.play_animation(&"hurt", true)


func update(delta: float) -> void:
	if not unit.alive:
		return
	if unit.is_stunned():
		_stun_hold = true
		# hurt 动画本身不循环；保持最后一帧即可，不要被 idle / move 覆盖。
		unit.play_animation(&"hurt")
		return
	if _stun_hold:
		# 眩晕结束时立刻解除受击姿态，不需要再等满 0.26 秒。
		_stun_hold = false
		machine.transition_to(&"idle")
		return
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition_to(&"idle")
