class_name UnitMoveState
extends UnitState

## 移动：推进到攻击距离，或远程单位被贴脸时后撤拉开射程。


func enter(_previous: StringName) -> void:
	unit.play_animation(&"move")


func update(delta: float) -> void:
	if not unit.alive:
		return
	if not unit.battle_active() or not unit.has_live_target():
		machine.transition_to(&"idle")
		return

	var intent: int = unit.brain.intent
	if intent == UnitBrain.Intent.ACTION and unit.can_execute_planned_action():
		machine.transition_to(&"action")
		return
	if intent == UnitBrain.Intent.IDLE:
		machine.transition_to(&"idle")
		return

	if intent == UnitBrain.Intent.KITE:
		_update_kite(delta)
		return

	# 推进：朝该英雄行为策略给出的阵型目标点移动。
	var goal := unit.movement_goal()
	var to_goal := goal - unit.global_position
	if to_goal.length() <= 8.0:
		if intent == UnitBrain.Intent.ACTION and unit.can_execute_planned_action():
			machine.transition_to(&"action")
		else:
			machine.transition_to(&"idle")
		return
	var before := unit.global_position
	unit.face_direction(to_goal.x)
	unit.play_animation(&"move")
	unit.move_step(to_goal, delta)
	if unit.global_position.distance_to(before) < 0.08:
		machine.transition_to(&"idle")


func _update_kite(delta: float) -> void:
	if not unit.has_live_target():
		machine.transition_to(&"idle")
		return
	if unit.distance_to_target() >= unit.kite_stop_distance():
		machine.transition_to(&"idle")
		return

	unit.face_target()
	unit.play_animation(&"move")
	var before := unit.global_position
	var away: Vector2 = unit.global_position - unit.target.global_position
	unit.move_step(away, delta)
	if before.distance_to(unit.global_position) < 0.08:
		machine.transition_to(&"idle")
