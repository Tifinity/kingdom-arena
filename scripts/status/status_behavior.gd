class_name StatusBehavior
extends Resource

## 状态行为策略基类。状态差异由 Behavior 提供，Controller 只负责生命周期与公共规则。
## 注意：Behavior 是共享 Resource，运行时数据必须写在 StatusInstance 上。

func on_apply(_instance: StatusInstance) -> void:
	pass


func on_refresh(_instance: StatusInstance) -> void:
	pass


func on_stack(_instance: StatusInstance, _old_stacks: int) -> void:
	pass


func on_tick(_instance: StatusInstance) -> void:
	pass


## 自然到期时调用，可结算最后不足一个 Tick 的伤害。
func on_expire(_instance: StatusInstance) -> void:
	pass


## 被驱散、死亡清理等非自然移除时调用。
func on_remove(_instance: StatusInstance) -> void:
	pass


## 叠到最大层时调用；返回 true 表示该状态应被移除。
func on_max_stacks(_instance: StatusInstance) -> bool:
	return false


## STRONGEST 策略下比较两次施加谁更强。
func is_stronger(_existing_power: float, _new_power: float) -> bool:
	return _new_power >= _existing_power


func modify_stat(_instance: StatusInstance, _stat: StringName, value: float) -> float:
	return value


func blocks_move(_instance: StatusInstance) -> bool:
	return false


func blocks_action(_instance: StatusInstance) -> bool:
	return false


func blocks_skill(_instance: StatusInstance) -> bool:
	return false
