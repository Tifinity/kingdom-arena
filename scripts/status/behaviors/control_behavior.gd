class_name ControlBehavior
extends StatusBehavior

## 控制类状态：眩晕、定身、沉默都复用这套行为，只改开关。
## 状态本身不直接操作 FSM，Unit 提供 interrupt_current_action()，FSM 通过
## can_move / can_act / can_use_skill 查询控制结果。

@export var block_move := true
@export var block_action := true
@export var block_skill := true
@export var interrupt_action := true


func on_apply(instance: StatusInstance) -> void:
	if interrupt_action and instance.target != null:
		instance.target.interrupt_current_action()


func blocks_move(_instance: StatusInstance) -> bool:
	return block_move


func blocks_action(_instance: StatusInstance) -> bool:
	return block_action


func blocks_skill(_instance: StatusInstance) -> bool:
	return block_skill
