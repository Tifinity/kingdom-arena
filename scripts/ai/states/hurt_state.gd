class_name UnitHurtState
extends UnitState

## 受击硬直：被打断当前动作，短暂僵直后回到待机。

const DURATION := 0.26

var _elapsed := 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	unit.visual.speed_scale = 1.0
	unit.play_animation(&"hurt", true)


func update(delta: float) -> void:
	if not unit.alive:
		return
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition_to(&"idle")
