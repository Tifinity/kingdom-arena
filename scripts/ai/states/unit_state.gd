class_name UnitState
extends Node

## 有限状态机状态基类。状态节点由 unit.tscn 提供，脚本只写行为。

var machine: UnitStateMachine
var unit: Unit


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func can_transition(_next: StringName) -> bool:
	return true
