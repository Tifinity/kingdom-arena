class_name TauntBehavior
extends StatusBehavior

## 嘲讽只改索敌目标，不打断已经开始的动作。


func on_apply(instance: StatusInstance) -> void:
	_retarget(instance)


func on_refresh(instance: StatusInstance) -> void:
	_retarget(instance)


func on_expire(instance: StatusInstance) -> void:
	if is_instance_valid(instance.target) and instance.target.alive and instance.target.brain != null:
		instance.target.brain.force_think()


func _retarget(instance: StatusInstance) -> void:
	if not is_instance_valid(instance.target) or not is_instance_valid(instance.source):
		return
	if not instance.target.alive or not instance.source.alive:
		return
	instance.target.target = instance.source
	if instance.target.brain != null:
		instance.target.brain.force_think()
