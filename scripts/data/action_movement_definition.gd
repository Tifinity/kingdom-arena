class_name ActionMovementDefinition
extends Resource

## 动作期间的位移配置；同一动作只选择一种位移方式。

enum Kind { NONE, ADVANCE, TELEPORT, CHARGE, DASH_TO_POINT, RETREAT }

@export_enum("原地:0", "推进:1", "闪现:2", "冲锋:3", "冲向施法点:4", "后撤:5") var kind: int = Kind.NONE
@export var speed := 0.0
@export var distance := 0.0
@export var target_gap := 10.0
## 冲向施法点时角色腾空的视觉高度；0 表示贴地移动。
@export var leap_height := 0.0
