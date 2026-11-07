class_name DotBehavior
extends StatusBehavior

## 持续伤害行为：流血、燃烧、中毒共用骨架，通过配置区分物理/火焰/毒伤、
## 是否无视护甲/护盾，以及是否在满层时引爆剩余伤害。

enum DamageMode {
	FLAT_DPS,          ## power 表示每秒固定伤害
	MAX_HP_RATIO_DPS,  ## power 表示每秒造成目标最大生命值的比例
}

@export var damage_type: StringName = &"physical"
@export var damage_mode := DamageMode.FLAT_DPS
@export var ignore_armor := false
@export var ignore_shield := false
## 中毒：叠到最大层时立即结算剩余全部 DoT 伤害。
@export var burst_on_max_stacks := false
@export var burst_consumes_status := true


func on_tick(instance: StatusInstance) -> void:
	_deal_damage(instance, 1.0)


func on_expire(instance: StatusInstance) -> void:
	# 自然结束时把最后一个未满 Tick 的零头结算掉，和旧实现一致。
	if instance.definition.tick_interval > 0.0 and instance.tick_accum > 0.0:
		_deal_damage(instance, instance.tick_accum / instance.definition.tick_interval)
		instance.tick_accum = 0.0


func on_max_stacks(instance: StatusInstance) -> bool:
	if not burst_on_max_stacks:
		return false
	var interval := instance.definition.tick_interval
	var remaining_ticks := 0.0
	if interval > 0.0:
		remaining_ticks = maxf(0.0, instance.remaining + instance.tick_accum) / interval
	if remaining_ticks > 0.0:
		_deal_damage(instance, remaining_ticks)
	instance.tick_accum = 0.0
	return burst_consumes_status


func _damage_per_tick(instance: StatusInstance) -> float:
	var interval := instance.definition.tick_interval
	if interval <= 0.0 or instance.power <= 0.0:
		return 0.0
	var amount := instance.power * maxf(float(instance.stacks), 1.0)
	if damage_mode == DamageMode.MAX_HP_RATIO_DPS:
		amount *= instance.target.max_hp
	return amount * interval


func _deal_damage(instance: StatusInstance, tick_scale: float) -> void:
	if instance.target == null or not is_instance_valid(instance.target) or not instance.target.alive:
		return
	var amount := _damage_per_tick(instance) * tick_scale
	if amount <= 0.0:
		return
	var source: Unit = instance.source if is_instance_valid(instance.source) else null
	instance.target.take_damage(
		amount,
		source,
		instance.target.get_hit_point(),
		false,
		ignore_armor,
		ignore_shield
	)
