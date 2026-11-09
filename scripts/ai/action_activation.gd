class_name ActionActivation
extends RefCounted

## 所有施放入口与 HUD 共用同一组前置条件；返回空字符串表示可施放。


static func reason(unit: Unit, action: CombatActionDefinition, target: Variant = null, direction := Vector2.ZERO, point := Vector2.ZERO, has_point := false) -> String:
	if unit == null or action == null or not unit.alive:
		return "动作无效"
	if not unit.can_act():
		return "无法行动"
	if action.category != CombatActionDefinition.Category.BASIC and not unit.can_use_skill():
		return "技能被封锁"
	if not unit.is_action_ready(action):
		return "冷却中"
	if not unit.has_mana(action):
		return "蓝量不足"
	if unit.hp_ratio() < action.min_self_hp_ratio or unit.hp_ratio() > action.max_self_hp_ratio:
		return "生命条件未满足"
	if action.requires_wounded_ally and not _has_wounded_ally(unit):
		return "没有受伤队友"
	match action.target_mode:
		CombatActionDefinition.TargetMode.ENEMY, CombatActionDefinition.TargetMode.ALLY:
			# 目标可能在 AI 选定后、HUD 下一帧刷新前被释放。
			# 先检查 Variant，再转成 Unit；类型化参数会在进入函数前报错。
			if not is_instance_valid(target) or not (target is Unit):
				return "目标无效"
			var live_target: Unit = target
			if not live_target.alive:
				return "目标无效"
			if (live_target.team == unit.team) != (action.target_mode == CombatActionDefinition.TargetMode.ALLY):
				return "目标阵营不符"
			if action.target_mode == CombatActionDefinition.TargetMode.ENEMY and action.movement_kind() != ActionMovementDefinition.Kind.CHARGE:
				if not _in_range(unit, action, live_target):
					return "目标超出范围"
			elif action.target_mode == CombatActionDefinition.TargetMode.ALLY and action.action_range > 0.0:
				if unit.global_position.distance_to(live_target.global_position) > action.action_range + live_target.body_radius:
					return "目标超出范围"
			if unit.global_position.distance_to(live_target.global_position) < action.min_range:
				return "目标过近"
		CombatActionDefinition.TargetMode.DIRECTION:
			if direction.length_squared() < 0.0001:
				return "缺少施放方向"
		CombatActionDefinition.TargetMode.POINT:
			if not has_point:
				return "缺少施放地点"
			if unit.global_position.distance_to(point) > action.action_range:
				return "地点超出范围"
	return ""


static func _in_range(unit: Unit, action: CombatActionDefinition, target: Unit) -> bool:
	var aoe_reach := unit.action_aoe_reach(action)
	if aoe_reach > 0.0:
		return unit.global_position.distance_to(target.global_position) <= (aoe_reach + target.body_radius + 6.0) * unit.AOE_CAST_BUFFER
	return unit.global_position.distance_to(target.global_position) <= action.action_range + target.body_radius + unit.body_radius * 0.35 + 6.0


static func _has_wounded_ally(unit: Unit) -> bool:
	if unit.battle == null:
		return false
	for ally in unit.battle.living_units():
		if ally.team == unit.team and ally.hp < ally.max_hp - 0.5:
			return true
	return false
