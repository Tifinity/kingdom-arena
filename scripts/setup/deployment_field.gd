extends Control

## 将场地上的鼠标输入和 Godot 的卡片拖拽转换到战场地面坐标。

@export var setup: ArenaSetup
@export var battle: Battle

var _dragged_unit: Unit
var _drag_payload: HeroDragData
var _click_pending := false


func _ready() -> void:
	process_priority = -10
	set_process(false)
	set_process_input(false)
	get_window().focus_exited.connect(_cancel_drag)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var unit := battle.unit_at_screen_position(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _click_pending:
			setup.select_field_unit(unit)
		_click_pending = event.pressed
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and unit != null:
		setup._on_remove_requested(unit.team, unit.slot)


func _get_drag_data(at_position: Vector2) -> Variant:
	var unit := battle.unit_at_screen_position(at_position)
	if unit == null:
		return null
	_click_pending = false
	var payload := HeroDragData.from_slot(unit.team, unit.slot, unit.definition.unit_id)
	payload.ground_offset = unit.position - battle.stage.screen_to_ground(at_position)
	_dragged_unit = unit
	_drag_payload = payload
	set_process(true)
	set_process_input(true)
	return payload


func _process(_delta: float) -> void:
	if is_instance_valid(_dragged_unit) and battle.deploying:
		_dragged_unit.position = battle.stage.screen_to_ground(get_global_mouse_position()) + _drag_payload.ground_offset


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel_drag()


func _cancel_drag() -> void:
	if _drag_payload != null and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_payload != null:
		_dragged_unit = null
		_drag_payload = null
		set_process(false)
		set_process_input(false)
		battle.refresh_deployment()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not battle.deploying or not data is HeroDragData:
		return false
	var payload := data as HeroDragData
	var definition := UnitCatalog.get_definition(payload.unit_id)
	if definition == null:
		return false
	var point := battle.stage.screen_to_ground(at_position) + payload.ground_offset
	var center_x := (battle.field_min.x + battle.field_max.x) * 0.5
	var team := 0 if point.x < center_x else 1
	if payload.kind == HeroDragData.Kind.SLOT:
		if team != payload.source_team or GameState.get_slot(team, payload.source_slot) != payload.unit_id:
			return false
	else:
		var target := battle.unit_at_screen_position(at_position)
		if target != null:
			return target.team == team
		if GameState.first_empty_slot(team) < 0:
			return false

	var margin := Vector2.ONE * definition.body_radius
	var lower := battle.field_min + margin
	var upper := battle.field_max - margin
	if team == 0:
		upper.x = center_x - margin.x
	else:
		lower.x = center_x + margin.x
	if point != point.clamp(lower, upper):
		return false
	for unit in battle.units:
		if payload.kind == HeroDragData.Kind.SLOT and unit.team == team and unit.slot == payload.source_slot:
			continue
		if point.distance_to(unit.position) < (definition.body_radius + unit.body_radius) * 0.86:
			return false
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var payload := data as HeroDragData
	var point := battle.stage.screen_to_ground(at_position) + payload.ground_offset
	if payload.kind == HeroDragData.Kind.SLOT:
		setup.move_deployed_unit(payload.source_team, payload.source_slot, point)
		return
	var target := battle.unit_at_screen_position(at_position)
	if target != null:
		setup._on_hero_dropped(target.team, target.slot, payload.unit_id)
	else:
		var team := 0 if point.x < (battle.field_min.x + battle.field_max.x) * 0.5 else 1
		setup._deploy_hero(team, GameState.first_empty_slot(team), payload.unit_id, point)
