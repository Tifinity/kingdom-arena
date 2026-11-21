class_name ZealDuelBehavior
extends StatusBehavior

## 剑士「热诚决斗」的叠层行为：
## 每层提供 5% 攻速；满层时每次伤害命中额外造成固定伤害。

@export var attack_speed_per_stack := 0.05
@export var max_stack_bonus_damage := 5.0


func modify_stat(instance: StatusInstance, stat: StringName, value: float) -> float:
	if stat == &"attack_speed":
		return value * (1.0 + attack_speed_per_stack * instance.stacks)
	return value


func modify_damage(instance: StatusInstance, amount: float, _is_basic: bool) -> float:
	if instance.stacks >= instance.definition.max_stacks:
		return amount + max_stack_bonus_damage
	return amount
