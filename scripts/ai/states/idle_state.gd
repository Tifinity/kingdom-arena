class_name UnitIdleState
extends UnitState

## 待机：原地播放 idle，观察大脑意图并选择下一步。


func enter(_previous: StringName) -> void:
	unit.visual.speed_scale = 1.0
	unit.play_animation(&"idle")


func update(_delta: float) -> void:
	if not unit.alive:
		return
	unit.face_target()
	unit.play_animation(&"idle")
	if not unit.battle_active() or unit.brain == null:
		return

	match unit.brain.intent:
		UnitBrain.Intent.ATTACK:
			if unit.can_attack():
				machine.transition_to(&"attack")
		UnitBrain.Intent.KITE:
			if unit.has_live_target() and unit.distance_to_target() < unit.attack_range * 0.70:
				machine.transition_to(&"move")
		UnitBrain.Intent.ADVANCE:
			if unit.has_live_target() and not unit.is_target_in_range(0.0):
				machine.transition_to(&"move")
