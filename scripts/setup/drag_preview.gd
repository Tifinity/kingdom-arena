class_name HeroDragPreview
extends PanelContainer

## 拖拽时跟随鼠标的小卡片，展示英雄头像/名字/定位。
## 注意：拖拽预览在 set_drag_preview 之前就要完成 setup，
## 此时节点还没触发 _ready，因此不用 @onready，直接 get_node。

func setup(definition: UnitDefinition) -> void:
	var portrait: TextureRect = get_node("VBox/Portrait")
	var name_label: Label = get_node("VBox/Name")
	var meta_label: Label = get_node("VBox/Meta")
	portrait.texture = definition.portrait
	name_label.text = definition.display_name
	meta_label.text = "%s · %s" % [definition.faction_label(), definition.role]
	meta_label.add_theme_color_override("font_color", definition.accent_color)
	modulate = Color(1, 1, 1, 0.94)
