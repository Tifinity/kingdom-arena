class_name UnitBehaviorProfile
extends Resource

## 每个英雄的行为配置：索敌策略 + 移动策略。
## 两个策略都可以是共享资源，也可以是该英雄专用的小脚本资源。

@export var behavior_id: StringName
@export var display_name := "默认行为"
@export var targeting: TargetingStrategy
@export var movement: MovementStrategy
