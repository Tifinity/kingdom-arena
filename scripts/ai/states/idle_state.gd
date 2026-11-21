class_name UnitIdleState
extends UnitState

## 待机：原地播放 idle，观察大脑意图并选择下一步。


func enter(_previous: StringName) -> void:
	unit.visual.speed_scale = 1.0
	unit.play_animation(&"idle")


func update(_delta: float) -> void:
	if not unit.alive:
		return
	if unit.is_stunned():
		# 防御性兜底：正常路径会在施加眩晕时直接切到 Hurt。
		machine.transition_to(&"hurt")
		return
	if not unit.can_move():
		return
	unit.face_target()
	unit.play_animation(&"idle")
	if not unit.battle_active() or unit.brain == null:
		return

	match unit.brain.intent:
		UnitBrain.Intent.ACTION:
			if unit.can_execute_planned_action():
				machine.transition_to(&"action")
		UnitBrain.Intent.KITE, UnitBrain.Intent.ADVANCE, UnitBrain.Intent.REPOSITION:
			if unit.brain.has_movement_goal() and unit.global_position.distance_squared_to(unit.brain.movement_destination) > 12.0 * 12.0:
				machine.transition_to(&"move")
