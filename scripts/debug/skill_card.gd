class_name TrainingSkillCard
extends Button

## 试炼场底部的技能卡：显示一个主动技能或被动技能的静态信息与实时状态。
## 主动技能被点击时只发出 cast_requested，由 Hero Lab 决定如何把技能打向稻草人。

signal cast_requested(action: CombatActionDefinition)

const READY_COLOR := Color("#8fe3a8")
const COOLDOWN_COLOR := Color("#93a0b4")
const MANA_COLOR := Color("#7fb6ff")
const CAST_COLOR := Color("#e7c46b")
const PASSIVE_COLOR := Color("#d8b877")
const MUTED_COLOR := Color("#6b7787")

var action: CombatActionDefinition
var passive: PassiveDefinition
var _last_attack_damage := NAN

@onready var slot_label: Label = $Margin/VBox/Header/Slot
@onready var state_label: Label = $Margin/VBox/Header/State
@onready var name_label: Label = $Margin/VBox/Name
@onready var meta_label: Label = $Margin/VBox/Meta
@onready var desc_label: Label = $Margin/VBox/Desc


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)


func setup_slot(slot_title: String, p_action: CombatActionDefinition, p_passive: PassiveDefinition,
		attack_damage: float, unit_max_mana: float, planned_index: int) -> void:
	action = p_action
	passive = p_passive
	slot_label.text = slot_title
	disabled = false
	modulate = Color.WHITE
	if action != null:
		name_label.text = action.display_name
		var cost := "满蓝" if action.mana_cost >= unit_max_mana - 0.001 and unit_max_mana > 0.0 else (
			"0 蓝" if action.mana_cost <= 0.001 else "%.0f 蓝" % action.mana_cost
		)
		meta_label.text = "%s · CD %.1fs" % [cost, action.cooldown]
		desc_label.text = action.detail_text(attack_damage)
		state_label.text = "就绪"
		state_label.add_theme_color_override("font_color", READY_COLOR)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_last_attack_damage = attack_damage
		tooltip_text = "%s · %s\n%s\n点击立即向稻草人施放" % [action.display_name, action.category_label(), desc_label.text]
	elif passive != null:
		name_label.text = passive.display_name
		meta_label.text = "被动 · 自动生效"
		desc_label.text = passive.detail_text()
		state_label.text = "已生效"
		state_label.add_theme_color_override("font_color", PASSIVE_COLOR)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = "%s · 被动\n%s" % [passive.display_name, desc_label.text]
	else:
		name_label.text = "待实装"
		meta_label.text = "主动 %d · 未配置" % (planned_index + 1)
		desc_label.text = "该技能仍在技能名册中规划，尚未配置动作资源。"
		state_label.text = "待实装"
		state_label.add_theme_color_override("font_color", MUTED_COLOR)
		disabled = true
		modulate = Color(1.0, 1.0, 1.0, 0.55)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = "该英雄的第 %d 个主动技能尚未实装" % (planned_index + 1)


## buff/debuff 改变攻击力时，技能卡里的伤害数字同步使用当前攻击力。
func refresh_damage(attack_damage: float) -> void:
	if action == null or is_equal_approx(attack_damage, _last_attack_damage):
		return
	_last_attack_damage = attack_damage
	desc_label.text = action.detail_text(attack_damage)
	tooltip_text = "%s · %s\n%s\n点击立即向稻草人施放" % [action.display_name, action.category_label(), desc_label.text]


func set_live_state(text: String, color: Color) -> void:
	if state_label == null:
		return
	state_label.text = text
	state_label.add_theme_color_override("font_color", color)


func _on_pressed() -> void:
	if action != null:
		cast_requested.emit(action)
