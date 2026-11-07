class_name UnitHurtState
extends UnitState

## 受击硬直：被打断当前动作，短暂僵直后回到待机。
## 如果带有眩晕，受击动画会保持到眩晕结束，期间不再接受新的行动。

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
