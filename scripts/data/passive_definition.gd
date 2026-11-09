class_name PassiveDefinition
extends Resource

## 不占动作槽的被动技能。开战效果复用已有的状态系统。
@export var display_name := "被动"
@export_multiline var description := ""
@export var battle_start_statuses: Array[StatusDefinition] = []


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
	return result


func _number_text(value: float) -> String:
	var rounded := snappedf(value, 0.001)
	return str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else str(rounded)
