class_name UnitStateMachine
extends Node

## 有限状态机：待机 / 移动 / 攻击 / 受击 / 死亡。
##
## 每个状态都是场景里的子节点（UnitState），状态之间不直接互相调用，
## 统一通过 transition_to() 切换，方便后续插入施法、闪避或控制状态。

signal state_changed(state_name: String)

const DISPLAY_NAMES := {
	&"idle": "待机",
	&"move": "移动",
	&"attack": "攻击",
	&"hurt": "受击",
	&"death": "死亡",
}

var unit: Unit
var states: Dictionary = {}
var current: UnitState
var current_name: StringName = &""


func _ready() -> void:
	for child in get_children():
		if child is UnitState:
			var key := StringName(String(child.name).to_lower())
			states[key] = child
			child.machine = self


func setup(p_unit: Unit) -> void:
	unit = p_unit
	for state in states.values():
		(state as UnitState).unit = p_unit
	transition_to(&"idle", true)


func _physics_process(delta: float) -> void:
	if current == null or unit == null or not unit.initialized:
		return
	current.update(delta)


func transition_to(next_name: StringName, force := false) -> bool:
	if current_name == &"death":
		return false
	if not states.has(next_name):
		push_warning("未知单位状态: %s" % next_name)
		return false
	if current_name == next_name:
		return false
	if current != null and not force and not current.can_transition(next_name):
		return false

	var previous := current_name
	if current != null:
		current.exit()
	current_name = next_name
	current = states[next_name]
	current.enter(previous)
	state_changed.emit(display_name())
	return true


func display_name() -> String:
	return DISPLAY_NAMES.get(current_name, String(current_name))


func is_state(state_name: StringName) -> bool:
	return current_name == state_name
