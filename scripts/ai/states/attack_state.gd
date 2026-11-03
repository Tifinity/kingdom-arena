class_name UnitAttackState
extends UnitState

## 普通攻击状态。
##
## 这里把“动作”抽象成 attack_animation + windup + 命中方式（近战/投射物），
## 技能只需提供另一份动作参数即可复用这个状态。

var _elapsed := 0.0
var _struck := false
var _duration := 0.5


func enter(_previous: StringName) -> void:
	unit.face_target()
	unit.play_animation(unit.attack_animation, true)
	var base_duration: float = maxf(unit.attack_anim_duration, 0.12)
	_duration = clampf(base_duration, 0.36, 0.75)
	_duration = maxf(_duration, unit.attack_windup + 0.16)
	# 让动画刚好覆盖起手时间：起手长则放慢，帧数多则加速。
	unit.visual.speed_scale = clampf(base_duration / _duration, 0.45, 2.6)
	_elapsed = 0.0
	_struck = false


func update(delta: float) -> void:
	if not unit.alive:
		return
	_elapsed += delta
	if not _struck and _elapsed >= unit.attack_windup:
		_struck = true
		unit.execute_attack()
	if _elapsed >= _duration:
		unit.visual.speed_scale = 1.0
		machine.transition_to(&"idle")


func exit() -> void:
	unit.visual.speed_scale = 1.0
