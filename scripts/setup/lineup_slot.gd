class_name LineupSlot
extends Button

## 布阵面板中的单个槽位：空槽接收拖拽，已部署时可拖拽移动/交换，× 移除。

signal slot_pressed(team: int, slot: int)
signal remove_requested(team: int, slot: int)
signal hero_dropped(team: int, slot: int, unit_id: StringName)
signal slot_dropped(source_team: int, source_slot: int, target_team: int, target_slot: int)

const DRAG_PREVIEW := preload("res://scenes/setup/drag_preview.tscn")

var team := 0
var slot := 0
var definition: UnitDefinition

@onready var index_label: Label = $Margin/HBox/IndexLabel
@onready var filled: HBoxContainer = $Margin/HBox/Filled
@onready var empty_state: HBoxContainer = $Margin/HBox/EmptyState
@onready var portrait: TextureRect = $Margin/HBox/Filled/PortraitFrame/Portrait
@onready var name_label: Label = $Margin/HBox/Filled/Info/Name
@onready var meta_label: Label = $Margin/HBox/Filled/Info/Meta
@onready var stats_label: Label = $Margin/HBox/Filled/Info/Stats
@onready var remove_button: Button = $RemoveButton
@onready var drop_highlight: Panel = $DropHighlight


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	gui_input.connect(_on_gui_input)
	_make_children_click_through(self)
	set_process(true)


func _make_children_click_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child != remove_button:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_children_click_through(child)


func configure(p_team: int, p_slot: int) -> void:
	team = p_team
	slot = p_slot
	index_label.text = "%02d" % (slot + 1)
	index_label.add_theme_color_override("font_color", GameState.team_color(team).darkened(0.1))
	set_definition(null)


func set_definition(p_definition: UnitDefinition) -> void:
	definition = p_definition
	var has_unit := definition != null
	filled.visible = has_unit
	empty_state.visible = not has_unit
	remove_button.visible = has_unit
	mouse_default_cursor_shape = Control.CURSOR_DRAG if has_unit else Control.CURSOR_POINTING_HAND
	if not has_unit:
		tooltip_text = "空槽位 %d\n从名册拖拽英雄到这里" % (slot + 1)
		return
	portrait.texture = definition.portrait
	name_label.text = definition.display_name
	meta_label.text = "%s · %s" % [definition.faction_label(), definition.role]
	meta_label.add_theme_color_override("font_color", definition.accent_color)
	stats_label.text = "生命 %d · 攻击 %d" % [roundi(definition.max_hp), roundi(definition.attack_damage)]
	tooltip_text = "%s · %s\n拖动到其他槽位可移动/交换；× 或右键移除" % [
		definition.display_name, definition.role,
	]


## 从已部署槽位拖出英雄，用于移动/交换。
func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null:
		return null
	var preview: HeroDragPreview = DRAG_PREVIEW.instantiate()
	preview.setup(definition)
	set_drag_preview(preview)
	return HeroDragData.from_slot(team, slot, definition.unit_id)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is HeroDragData


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is HeroDragData):
		return
	drop_highlight.visible = false
	var payload := data as HeroDragData
	if payload.kind == HeroDragData.Kind.HERO:
		hero_dropped.emit(team, slot, payload.unit_id)
	else:
		slot_dropped.emit(payload.source_team, payload.source_slot, team, slot)


## 拖拽经过时给槽位一个金色描边；游戏里只有英雄拖拽，所以只看是否在拖拽/是否悬停。
func _process(_delta: float) -> void:
	if drop_highlight == null:
		return
	if not get_viewport().gui_is_dragging():
		if drop_highlight.visible:
			drop_highlight.visible = false
		return
	var hovered := get_global_rect().has_point(get_global_mouse_position())
	if drop_highlight.visible != hovered:
		drop_highlight.visible = hovered


func _on_pressed() -> void:
	slot_pressed.emit(team, slot)


func _on_remove_pressed() -> void:
	remove_requested.emit(team, slot)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed and definition != null:
			remove_requested.emit(team, slot)
			accept_event()
