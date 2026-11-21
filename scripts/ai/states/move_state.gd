class_name UnitMoveState
extends UnitState

## 执行大脑选定的接敌、换位或撤退路线，近处有单位时先绕开。


func enter(_previous: StringName) -> void:
	unit.play_animation(&"move")


func update(delta: float) -> void:
	if not unit.alive:
		return
	if unit.is_stunned():
		machine.transition_to(&"hurt")
		return
	if not unit.can_move() or not unit.battle_active() or not unit.has_live_target():
		machine.transition_to(&"idle")
		return
	var brain := unit.brain
	if brain.intent == UnitBrain.Intent.ACTION and unit.can_execute_planned_action():
		machine.transition_to(&"action")
		return
	if not brain.has_movement_goal():
		machine.transition_to(&"idle")
		return

	var to_goal := brain.movement_destination - unit.global_position
	if to_goal.length_squared() <= 12.0 * 12.0:
		machine.transition_to(&"idle")
		return
	var direction := to_goal
	if not unit.battle.training_mode:
		direction = _steer_around_units(to_goal)
	if brain.intent == UnitBrain.Intent.ADVANCE:
		unit.face_direction(direction.x)
	else:
		unit.face_target()
	var before := unit.global_position
	unit.move_step(direction, delta)
	if unit.global_position.distance_squared_to(before) < 0.08 * 0.08:
		machine.transition_to(&"idle")


func _steer_around_units(to_goal: Vector2) -> Vector2:
	var forward := to_goal.normalized()
	var blocker: Unit
	var blocker_distance := INF
	for other: Unit in unit.battle.living_units():
		if other == unit or other.is_charging() or other.is_training_dummy():
			continue
		var offset := other.global_position - unit.global_position
		var ahead := offset.dot(forward)
		var clearance := (unit.body_radius + other.body_radius) * 0.95
		if ahead <= 0.0 or ahead >= minf(to_goal.length(), clearance + 36.0):
			continue
		if absf(offset.cross(forward)) < clearance and ahead < blocker_distance:
			blocker = other
			blocker_distance = ahead
	if blocker == null:
		return forward

	var offset := blocker.global_position - unit.global_position
	var clearance := (unit.body_radius + blocker.body_radius) * 0.95
	var bearing := offset.normalized()
	var side := signf(bearing.cross(forward))
	if absf(bearing.cross(forward)) < 0.12:
		side = -1.0 if posmod(unit.slot, 2) == 0 else 1.0
	var angle := asin(clampf(clearance / maxf(offset.length(), 1.0), 0.0, 1.0))
	var avoid := bearing.rotated(side * (angle + 0.12))
	var probe: Vector2 = unit.battle.clamp_unit_position(unit.global_position + avoid * 36.0)
	if probe.distance_squared_to(unit.global_position) < 18.0 * 18.0:
		avoid = bearing.rotated(-side * (angle + 0.12))
	return avoid
