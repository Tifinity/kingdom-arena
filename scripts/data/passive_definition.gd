class_name PassiveDefinition
extends Resource

## 不占动作槽的被动技能。开战效果复用已有的状态系统。
@export var display_name := "被动"
@export_multiline var description := ""
@export var battle_start_statuses: Array[StatusDefinition] = []
## 每次技能伤害命中施加一层；叠加、持续时间和上限由状态资源自身控制。
@export var skill_hit_stacks_status: StatusDefinition
@export var heal_below_hp_ratio := 0.0
@export var heal_bonus_ratio := 0.0
## 生命低于该比例时施加 hp_threshold_status（例如狂怒）；0 表示没有低血量被动。
@export var hp_threshold := 0.0
## 低血量期间持续存在的状态，通常是攻击/吸血增益，自带特效；由 Unit 按生命自动施加和移除。
@export var hp_threshold_status: StatusDefinition


func detail_text() -> String:
	var rendered := description
	for index in battle_start_statuses.size():
		var status := battle_start_statuses[index]
		if status == null:
			continue
		var prefix := "{status_%d_" % index
		rendered = rendered.replace(prefix + "power_percent}", _number_text(status.base_power * 100.0))
		rendered = rendered.replace(prefix + "power}", _number_text(status.base_power))
		rendered = rendered.replace(prefix + "duration}", _number_text(status.duration))
	return rendered


func remaining(controller: Node) -> float:
	if controller == null:
		return 0.0
	var result := 0.0
	for status in battle_start_statuses:
		if status != null:
			result = maxf(result, controller.remaining(status.id))
	if skill_hit_stacks_status != null:
		result = maxf(result, controller.remaining(skill_hit_stacks_status.id))
	if hp_threshold_status != null:
		result = maxf(result, controller.remaining(hp_threshold_status.id))
	return result


## 低血量被动当前是否生效。
func threshold_active(controller: Node) -> bool:
	return hp_threshold_status != null and controller != null and controller.has_status(hp_threshold_status.id)


func _number_text(value: float) -> String:
	var rounded := snappedf(value, 0.001)
	return str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else str(rounded)
