class_name StatModifierBehavior
extends StatusBehavior

## 属性修改行为：减速、破甲、易伤等。
## power 的语义由具体状态决定；减速使用“移速倍率”，例如 0.55 表示 55% 移速。

enum Mode { MULTIPLY, ADD }

@export var stat: StringName = &"move_speed"
@export var mode := Mode.MULTIPLY
## 数值越低越强时设为 true，例如减速倍率 0.5 比 0.7 更强。
@export var stronger_when_lower := false


func modify_stat(instance: StatusInstance, stat_name: StringName, value: float) -> float:
	if stat_name != stat:
		return value
	if mode == Mode.MULTIPLY:
		return value * instance.power
	return value + instance.power


func is_stronger(existing_power: float, new_power: float) -> bool:
	if stronger_when_lower:
		return new_power < existing_power
	return new_power > existing_power
