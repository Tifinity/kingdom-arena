class_name StatModifierBehavior
extends StatusBehavior

## 属性修改行为：减速、破甲、易伤等。
## power 的语义由具体状态决定；减速使用“移速倍率”，例如 0.55 表示 55% 移速。

enum Mode { MULTIPLY, ADD }

@export var stat: StringName = &"move_speed"
@export var mode := Mode.MULTIPLY
## 数值越低越强时设为 true，例如减速倍率 0.5 比 0.7 更强。
@export var stronger_when_lower := false
## 附带的吸血比例，例如 0.1 表示造成伤害的 10% 回复生命。
@export var lifesteal_bonus := 0.0


func modify_stat(instance: StatusInstance, stat_name: StringName, value: float) -> float:
	if stat_name != stat:
		return value
	if mode == Mode.MULTIPLY:
		return value * instance.power
	return value + instance.power


func modify_lifesteal(_instance: StatusInstance, value: float) -> float:
	return value + lifesteal_bonus


func is_stronger(existing_power: float, new_power: float) -> bool:
	if stronger_when_lower:
		return new_power < existing_power
	return new_power > existing_power
