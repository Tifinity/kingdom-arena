class_name TargetingStrategy
extends Resource

## 索敌策略基类。默认返回 0，由具体策略覆盖。


func score_target(_brain: UnitBrain, _enemy: Unit, _distance: float) -> float:
	return 0.0
