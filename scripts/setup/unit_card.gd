class_name UnitCard
extends Button

## 名册中的英雄卡片。

signal card_selected(definition: UnitDefinition)

const DRAG_PREVIEW := preload("res://scenes/setup/drag_preview.tscn")

var definition: UnitDefinition

@onready var portrait: TextureRect = $Margin/VBox/PortraitFrame/Portrait
@onready var name_label: Label = $Margin/VBox/Name
@onready var meta_label: Label = $Margin/VBox/Meta
@onready var hp_label: Label = $Margin/VBox/Stats/Hp
@onready var atk_label: Label = $Margin/VBox/Stats/Atk
@onready var selected_overlay: Panel = $SelectedOverlay


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	pressed.connect(_on_pressed)


## 从名册卡拖出一个英雄；实际部署由 LineupSlot 的 _drop_data 触发。
func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null:
		return null
	var preview: HeroDragPreview = DRAG_PREVIEW.instantiate()
	preview.setup(definition)
	set_drag_preview(preview)
	return HeroDragData.from_hero(definition.unit_id)


func setup(p_definition: UnitDefinition) -> void:
	definition = p_definition
	portrait.texture = p_definition.portrait
	name_label.text = p_definition.display_name
	meta_label.text = "%s · %s" % [p_definition.faction_label(), p_definition.role]
	meta_label.add_theme_color_override("font_color", p_definition.accent_color)
	hp_label.text = "生命 %d" % roundi(p_definition.max_hp)
	atk_label.text = "攻击 %d" % roundi(p_definition.attack_damage)
	tooltip_text = "%s · %s\n%s\n%s\n拖拽到左右槽位部署" % [
		p_definition.display_name, p_definition.title,
		p_definition.description, p_definition.stat_line(),
	]


func set_selected(value: bool) -> void:
	selected_overlay.visible = value


func _on_pressed() -> void:
	card_selected.emit(definition)
