class_name BattleHUD
extends CanvasLayer

## 战斗 HUD：双方总血量、倒计时、暂停/倍速、OODA 观察镜与结算面板。

var battle: Battle
var selected_unit: Unit
var _refresh_accum := 0.0
var debug_panel: PanelContainer
var debug_fields: Dictionary = {}
const DEBUG_FIELD_DEFS := [
	["max_hp", "生命上限", 100.0, 5000.0, 10.0],
	["attack_damage", "攻击力", 1.0, 1000.0, 1.0],
	["attack_speed", "攻速/秒", 0.05, 10.0, 0.05],
	["attack_range", "攻击距离", 10.0, 2000.0, 5.0],
	["armor", "护甲 %", 0.0, 80.0, 1.0],
	["move_speed", "移动速度", 10.0, 800.0, 5.0],
	["mana_regen", "每秒回蓝", 0.0, 50.0, 1.0],
]

@onready var blue_name: Label = $Root/TopBar/Margin/Row/BlueTeam/BlueHeader/BlueName
@onready var blue_alive: Label = $Root/TopBar/Margin/Row/BlueTeam/BlueHeader/BlueAlive
@onready var red_name: Label = $Root/TopBar/Margin/Row/RedTeam/RedHeader/RedName
@onready var red_alive: Label = $Root/TopBar/Margin/Row/RedTeam/RedHeader/RedAlive
@onready var timer_label: Label = $Root/TopBar/Margin/Row/Center/TimerLabel
@onready var phase_label: Label = $Root/TopBar/Margin/Row/Center/PhaseLabel
@onready var speed_button: Button = $Root/Controls/SpeedButton
@onready var pause_button: Button = $Root/Controls/PauseButton
@onready var range_button: Button = $Root/Controls/RangeButton
@onready var exit_button: Button = $Root/Controls/ExitButton
@onready var countdown_label: Label = $Root/Countdown
@onready var hint_label: Label = $Root/Hint
@onready var inspector: PanelContainer = $Root/Inspector
@onready var inspector_state: Label = $Root/Inspector/Margin/VBox/Header/InspectorState
@onready var inspector_name: Label = $Root/Inspector/Margin/VBox/InspectorName
@onready var inspector_hp: Label = $Root/Inspector/Margin/VBox/InspectorHp
@onready var skill_status: Label = $Root/Inspector/Margin/VBox/SkillStatus
@onready var observe_text: Label = $Root/Inspector/Margin/VBox/ObserveRow/ObserveText
@onready var judge_text: Label = $Root/Inspector/Margin/VBox/JudgeRow/JudgeText
@onready var decide_text: Label = $Root/Inspector/Margin/VBox/DecideRow/DecideText
@onready var action_text: Label = $Root/Inspector/Margin/VBox/ActionRow/ActionText
@onready var result_root: Control = $Root/Result
@onready var result_title: Label = $Root/Result/CenterBox/Panel/Margin/VBox/ResultTitle
@onready var result_sub: Label = $Root/Result/CenterBox/Panel/Margin/VBox/ResultSub
@onready var time_value: Label = $Root/Result/CenterBox/Panel/Margin/VBox/Stats/TimeValue
@onready var alive_value: Label = $Root/Result/CenterBox/Panel/Margin/VBox/Stats/AliveValue
@onready var damage_value: Label = $Root/Result/CenterBox/Panel/Margin/VBox/Stats/DamageValue
@onready var kill_value: Label = $Root/Result/CenterBox/Panel/Margin/VBox/Stats/KillValue
@onready var mvp_value: Label = $Root/Result/CenterBox/Panel/Margin/VBox/Stats/MvpValue
@onready var rematch_button: Button = $Root/Result/CenterBox/Panel/Margin/VBox/Buttons/RematchButton
@onready var back_button: Button = $Root/Result/CenterBox/Panel/Margin/VBox/Buttons/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	result_root.visible = false
	countdown_label.visible = false
	inspector.visible = false
	hint_label.visible = true
	blue_name.text = GameState.team_name(0)
	red_name.text = GameState.team_name(1)
	blue_name.add_theme_color_override("font_color", GameState.team_color(0))
	red_name.add_theme_color_override("font_color", GameState.team_color(1))
	speed_button.pressed.connect(_on_speed_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	range_button.toggled.connect(_on_range_toggled)
	exit_button.pressed.connect(_on_exit_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_debug_panel()
	refresh_controls()


func bind(p_battle: Battle) -> void:
	battle = p_battle
	refresh_controls()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if battle == null:
		return
	# Battle 节点在暂停时会停止输入处理；由 HUD 转发暂停期间的点击选人。
	if get_tree().paused and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var world_point := battle.get_global_transform_with_canvas().affine_inverse() * mouse.position
			battle._select_at(world_point)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F2:
			debug_panel.visible = not debug_panel.visible
			if debug_panel.visible:
				_sync_debug_panel()
			get_viewport().set_input_as_handled()
			return
	if debug_panel.visible and event.is_action_pressed("ui_cancel"):
		debug_panel.visible = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		battle.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speed_toggle"):
		battle.toggle_speed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("range_toggle"):
		battle.toggle_range_overlay()
		range_button.set_pressed_no_signal(battle.show_combat_ranges)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		battle.restart_battle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		battle.back_to_setup()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if battle == null:
		return
	if selected_unit != null and not is_instance_valid(selected_unit):
		set_selected_unit(null)
	_refresh_accum += delta
	if _refresh_accum >= 0.08:
		_refresh_accum = 0.0
		_refresh()
		_update_inspector()


func _refresh() -> void:
	if battle == null:
		return
	timer_label.text = _format_time(battle.elapsed)
	blue_alive.text = "%d/%d" % [battle.team_alive(0), battle.team_sizes[0]]
	red_alive.text = "%d/%d" % [battle.team_alive(1), battle.team_sizes[1]]
	if get_tree().paused:
		phase_label.text = "已暂停"
	elif battle.finished:
		phase_label.text = "战斗结束"
	elif battle.battle_active:
		phase_label.text = "交战中"
	else:
		phase_label.text = "备战中"



func refresh_controls() -> void:
	if battle == null:
		return
	speed_button.text = "×0.5" if battle.speed_multiplier < 0.75 else "×%d" % int(battle.speed_multiplier)
	pause_button.text = "继续" if get_tree().paused else "暂停"
	range_button.set_pressed_no_signal(battle.show_combat_ranges)


func set_paused(paused: bool) -> void:
	pause_button.text = "继续" if paused else "暂停"


func _on_range_toggled(pressed: bool) -> void:
	if battle != null:
		battle.set_range_overlay(pressed)


func show_countdown(text: String) -> void:
	countdown_label.visible = true
	countdown_label.text = text
	var highlight := text == "开战！"
	countdown_label.add_theme_color_override(
		"font_color",
		Color("#e7c46b") if highlight else Color("#eef2f8")
	)
	countdown_label.pivot_offset = countdown_label.size / 2.0
	countdown_label.scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	countdown_label.visible = false


func set_selected_unit(unit: Unit) -> void:
	selected_unit = unit
	inspector.visible = unit != null
	hint_label.visible = unit == null
	if unit != null:
		_update_inspector()
	if debug_panel != null and debug_panel.visible:
		_sync_debug_panel()


func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "StatDebugPanel"
	debug_panel.visible = false
	debug_panel.z_index = 100
	debug_panel.anchor_left = 1.0
	debug_panel.anchor_right = 1.0
	debug_panel.offset_left = -356.0
	debug_panel.offset_right = -16.0
	debug_panel.offset_top = 92.0
	debug_panel.offset_bottom = 470.0
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(debug_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	debug_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "属性调试（F2 关闭）"
	title.add_theme_color_override("font_color", Color("#e7c46b"))
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "仅修改当前场上单位，点应用立即生效"
	hint.add_theme_color_override("font_color", Color("#93a0b4"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)
	for def in DEBUG_FIELD_DEFS:
		var caption := Label.new()
		caption.text = def[1]
		grid.add_child(caption)
		var spin := SpinBox.new()
		spin.min_value = def[2]
		spin.max_value = def[3]
		spin.step = def[4]
		spin.allow_greater = true
		spin.custom_minimum_size = Vector2(132, 0)
		grid.add_child(spin)
		debug_fields[def[0]] = spin

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)
	var apply_button := Button.new()
	apply_button.text = "应用"
	apply_button.pressed.connect(_on_debug_apply)
	buttons.add_child(apply_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(func() -> void: debug_panel.visible = false)
	buttons.add_child(close_button)


func _sync_debug_panel() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	debug_fields["max_hp"].value = selected_unit.max_hp
	debug_fields["attack_damage"].value = selected_unit.attack_damage
	debug_fields["attack_speed"].value = 1.0 / maxf(selected_unit.attack_interval, 0.001)
	debug_fields["attack_range"].value = selected_unit.attack_range
	debug_fields["armor"].value = selected_unit.armor * 100.0
	debug_fields["move_speed"].value = selected_unit.move_speed
	debug_fields["mana_regen"].value = selected_unit.mana_regen


func _on_debug_apply() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	selected_unit.apply_debug_stats({
		"max_hp": debug_fields["max_hp"].value,
		"attack_damage": debug_fields["attack_damage"].value,
		"attack_speed": debug_fields["attack_speed"].value,
		"attack_range": debug_fields["attack_range"].value,
		"armor": debug_fields["armor"].value / 100.0,
		"move_speed": debug_fields["move_speed"].value,
		"mana_regen": debug_fields["mana_regen"].value,
	})
	_update_inspector()


func _update_inspector() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	var snapshot: Dictionary = selected_unit.ai_snapshot()
	var definition: UnitDefinition = selected_unit.definition
	inspector_name.text = "%s · %s · %s" % [
		snapshot.name,
		GameState.team_short_name(snapshot.team),
		definition.role,
	]
	inspector_name.add_theme_color_override("font_color", GameState.team_color(snapshot.team))
	inspector_hp.text = "生命 %s · 护盾 %s（%.1f秒） · 目标 %s\n蓝量 %s · 攻击范围 %s · 技能范围 %s" % [
		snapshot.hp, snapshot.shield, float(snapshot.shield_time), snapshot.target,
		snapshot.mana, snapshot.attack_range, snapshot.skill_range,
	]
	var skill_lines: Array[String] = []
	for action in selected_unit.actions:
		if action == null or action.category == CombatActionDefinition.Category.BASIC:
			continue
		var remaining := selected_unit.action_cooldown(action)
		var state := "CD %.1fs" % remaining if remaining > 0.01 else ("缺蓝" if not selected_unit.has_mana(action) else "可释放")
		skill_lines.append("%s · %s · 蓝 %.0f/%.0f · %s" % [
			action.display_name, state, selected_unit.mana, action.mana_cost,
			"满蓝" if action.mana_cost >= selected_unit.max_mana - 0.001 else "技能",
		])
	skill_status.text = "\n".join(PackedStringArray(skill_lines))
	inspector_state.text = snapshot.state
	if snapshot.state_key == "action" and snapshot.get("action_name", "—") != "—":
		inspector_state.text = "%s · %s" % [snapshot.state, snapshot.action_name]
	inspector_state.add_theme_color_override("font_color", _state_color(snapshot.state_key))
	observe_text.text = snapshot.observe
	judge_text.text = snapshot.judge
	decide_text.text = snapshot.decide
	action_text.text = snapshot.action


func _state_color(state_key: String) -> Color:
	match state_key:
		"action":
			return Color("#e7c46b")
		"hurt":
			return Color("#ff9a8a")
		"death":
			return Color("#8b96a5")
		"move":
			return Color("#8fd7ff")
		_:
			return Color("#a9c4e2")


func show_result(result: Dictionary) -> void:
	result_root.visible = true
	hint_label.visible = false
	inspector.visible = false
	var winner: int = result.get("winner", -1)
	if winner == 0 or winner == 1:
		var color := GameState.team_color(winner)
		result_title.text = "%s 获胜" % GameState.team_name(winner)
		result_title.add_theme_color_override("font_color", color)
		var loser := 1 - winner
		result_sub.text = "%s全员阵亡" % GameState.team_name(loser)
	else:
		result_title.text = "同归于尽"
		result_title.add_theme_color_override("font_color", Color("#e7c46b"))
		result_sub.text = "双方英雄全部阵亡 · 平局"

	time_value.text = _format_time(result.get("elapsed", 0.0))
	var alive: Array = result.get("alive", [0, 0])
	var size: Array = result.get("size", [0, 0])
	alive_value.text = "蓝 %d/%d · 红 %d/%d" % [alive[0], size[0], alive[1], size[1]]
	var damage: Array = result.get("damage", [0.0, 0.0])
	damage_value.text = "蓝 %d · 红 %d" % [roundi(damage[0]), roundi(damage[1])]
	var kills: Array = result.get("kills", [0, 0])
	kill_value.text = "蓝 %d · 红 %d" % [kills[0], kills[1]]
	var mvp: Dictionary = result.get("mvp", {})
	var mvp_name: String = str(mvp.get("name", "无"))
	var mvp_team: int = int(mvp.get("team", -1))
	if mvp_team == 0 or mvp_team == 1:
		mvp_value.text = "%s · %s · %d 伤害" % [
			GameState.team_short_name(mvp_team), mvp_name, roundi(float(mvp.get("damage", 0.0))),
		]
	else:
		mvp_value.text = "无"


func _on_speed_pressed() -> void:
	if battle != null:
		battle.toggle_speed()


func _on_pause_pressed() -> void:
	if battle != null:
		battle.toggle_pause()


func _on_exit_pressed() -> void:
	if battle != null:
		battle.back_to_setup()


func _on_rematch_pressed() -> void:
	if battle != null:
		battle.restart_battle()


func _on_back_pressed() -> void:
	if battle != null:
		battle.back_to_setup()


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]
