class_name ActionPlan
extends RefCounted

## 决策层的产物：选中的动作 + 目标 + 可选方向。
## ActionState 只执行这个计划，不在执行阶段重新决策。

var action: CombatActionDefinition
var target: Unit
var direction := Vector2.ZERO


static func create(p_action: CombatActionDefinition, p_target: Unit, p_direction := Vector2.ZERO) -> ActionPlan:
	var plan := ActionPlan.new()
	plan.action = p_action
	plan.target = p_target
	plan.direction = p_direction
	return plan
