class_name LineupPanel
extends PanelContainer

## 一侧的 5 个布阵槽位 + 队伍名/战力。

signal slot_pressed(team: int, slot: int)
signal remove_requested(team: int, slot: int)
signal hero_dropped(team: int, slot: int, unit_id: StringName)
signal slot_dropped(source_team: int, source_slot: int, target_team: int, target_slot: int)
signal preset_changed

@export var team := 0

var slots: Array[LineupSlot] = []

@onready var accent_bar: ColorRect = $Margin/VBox/Header/AccentBar
@onready var preset_option: OptionButton = $Margin/VBox/Header/TeamPreset
@onready var restore_preset_button: Button = $Margin/VBox/PowerRow/RestorePreset
@onready var count_label: Label = $Margin/VBox/Header/CountLabel
@onready var power_label: Label = $Margin/VBox/PowerRow/PowerLabel
@onready var slots_box: VBoxContainer = $Margin/VBox/Slots


func _ready() -> void:
	for preset in GameState.TEAM_PRESETS:
		preset_option.add_item(preset["name"])
	preset_option.item_selected.connect(_on_preset_selected)
	restore_preset_button.pressed.connect(_on_restore_preset)
	accent_bar.color = GameState.team_color(team)
	count_label.add_theme_color_override("font_color", GameState.team_color(team))
	for index in GameState.TEAM_SIZE:
		var slot: LineupSlot = slots_box.get_node("Slot%d" % (index + 1))
		slots.append(slot)
		slot.configure(team, index)
		slot.slot_pressed.connect(_on_slot_pressed)
		slot.remove_requested.connect(_on_remove_requested)
		slot.hero_dropped.connect(_on_slot_hero_dropped)
		slot.slot_dropped.connect(_on_slot_slot_dropped)
	refresh()


func refresh() -> void:
	preset_option.select(GameState.selected_team_preset(team))
	restore_preset_button.disabled = not GameState.is_team_preset_edited(team)
	var lineup: Array = GameState.get_lineup(team)
	var count := 0
	for index in GameState.TEAM_SIZE:
		var unit_id: Variant = lineup[index]
		var definition: UnitDefinition = null
		if unit_id != null:
			definition = UnitCatalog.get_definition(unit_id)
			if definition != null:
				count += 1
		slots[index].set_definition(definition)
	count_label.text = "%d/%d" % [count, GameState.TEAM_SIZE]
	power_label.text = "战力 %d" % GameState.lineup_power(team)


func _on_preset_selected(index: int) -> void:
	GameState.select_team_preset(team, index)
	refresh()
	preset_changed.emit()


func _on_restore_preset() -> void:
	GameState.restore_team_preset(team)
	refresh()
	preset_changed.emit()


func _on_slot_pressed(slot_team: int, slot_index: int) -> void:
	slot_pressed.emit(slot_team, slot_index)


func _on_remove_requested(slot_team: int, slot_index: int) -> void:
	remove_requested.emit(slot_team, slot_index)


func _on_slot_hero_dropped(slot_team: int, slot_index: int, unit_id: StringName) -> void:
	hero_dropped.emit(slot_team, slot_index, unit_id)


func _on_slot_slot_dropped(source_team: int, source_slot: int, target_team: int, target_slot: int) -> void:
	slot_dropped.emit(source_team, source_slot, target_team, target_slot)
