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
	if intent == UnitBrain.Intent.ATTACK and unit.can_attack():
		machine.transition_to(&"attack")
		return
	if intent == UnitBrain.Intent.IDLE:
		machine.transition_to(&"idle")
		return

	if intent == UnitBrain.Intent.KITE:
		_update_kite(delta)
		return

	# 默认按“推进”处理：走向自己在目标周围的战斗位，而不是目标原点。
	if unit.is_target_in_range(-4.0):
		if unit.can_attack():
			machine.transition_to(&"attack")
		else:
			machine.transition_to(&"idle")
		return
	var desired := unit.desired_combat_position()
	var direction: Vector2 = desired - unit.global_position
	if direction.length() < 8.0:
		machine.transition_to(&"idle")
		return
	unit.face_direction(direction.x)
	unit.play_animation(&"move")
	unit.move_step(direction, delta)
	if unit.is_target_in_range(-4.0):
		if unit.can_attack():
			machine.transition_to(&"attack")
		else:
			machine.transition_to(&"idle")


func _update_kite(delta: float) -> void:
	if not unit.has_live_target():
		machine.transition_to(&"idle")
		return
	if unit.distance_to_target() >= unit.attack_range * 0.72:
		machine.transition_to(&"idle")
		return

	unit.face_target()
	unit.play_animation(&"move")
	var before := unit.global_position
	var away: Vector2 = unit.global_position - unit.target.global_position
	unit.move_step(away, delta)
	# 已经贴到场地边缘、无法继续后撤时停下，避免原地抖动。
	if before.distance_to(unit.global_position) < 0.08:
		machine.transition_to(&"idle")
