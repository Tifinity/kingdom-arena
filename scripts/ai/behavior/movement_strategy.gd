class_name MovementStrategy
extends Resource

## 移动策略基类。返回目标周围的期望站位、是否后撤、后撤停止距离。


func desired_position(_unit: Unit) -> Vector2:
	return _unit.global_position


func should_kite(_unit: Unit) -> bool:
	return false


func get_kite_stop_ratio() -> float:
	return 0.72
