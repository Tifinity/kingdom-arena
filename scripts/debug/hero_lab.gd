extends Node2D

## 英雄试炼场 v2：真实战斗 + 稻草人靶 + 四技能演示。
##
## 进入场景即在竞技场里生成当前英雄与一只不会移动、不会死亡、不会掉血的稻草人。
## 英雄复用真实 AI/FSM/技能；底部四张技能卡展示 3 个主动 + 1 个被动，
## 点击主动技能会把英雄调整到合适距离并立即向稻草人施放。
## 右侧保留数值编辑与「进入 1v1 实战」，需要 OODA 观察镜时再切到真实战斗。

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const CARD_SCENE := preload("res://scenes/setup/unit_card.tscn")
const SKILL_CARD_SCENE := preload("res://scenes/debug/skill_card.tscn")
const SETUP_SCENE := "res://scenes/setup/setup_screen.tscn"

const ACTIVE_SLOT_COUNT := 3
const PASSIVE_SLOT_INDEX := 3
const REFRESH_INTERVAL := 0.1

var selected_definition: UnitDefinition
var battle: Battle
var hero: Unit
var dummy: Unit
var skill_cards: Array[TrainingSkillCard] = []

var _cards: Array[UnitCard] = []
var _opponents: Array[UnitDefinition] = []
var _refresh_accum := 0.0
var _toast_serial := 0

@onready var battle_host: Node2D = $BattleHost
@onready var hero_grid: GridContainer = $HUD/Root/LeftPanel/VBox/Scroll/HeroGrid
@onready var hero_scroll: ScrollContainer = $HUD/Root/LeftPanel/VBox/Scroll
@onready var hero_count: Label = $HUD/Root/LeftPanel/VBox/Header/HeroCount
@onready var detail_name: Label = $HUD/Root/RightPanel/VBox/NameRow/Name
@onready var detail_title: Label = $HUD/Root/RightPanel/VBox/NameRow/Title
@onready var detail_meta: Label = $HUD/Root/RightPanel/VBox/Meta
@onready var detail_desc: Label = $HUD/Root/RightPanel/VBox/Desc
@onready var live_label: Label = $HUD/Root/RightPanel/VBox/Live
@onready var stat_hp: SpinBox = $HUD/Root/RightPanel/VBox/Stats/HpValue
@onready var stat_atk: SpinBox = $HUD/Root/RightPanel/VBox/Stats/AtkValue
@onready var stat_aspd: SpinBox = $HUD/Root/RightPanel/VBox/Stats/AspdValue
@onready var stat_range: SpinBox = $HUD/Root/RightPanel/VBox/Stats/RangeValue
@onready var stat_armor: SpinBox = $HUD/Root/RightPanel/VBox/Stats/ArmorValue
@onready var stat_speed: SpinBox = $HUD/Root/RightPanel/VBox/Stats/SpeedValue
@onready var stat_max_mana: SpinBox = $HUD/Root/RightPanel/VBox/Stats/MaxManaValue
@onready var stat_starting_mana: SpinBox = $HUD/Root/RightPanel/VBox/Stats/StartManaValue
@onready var stat_regen: SpinBox = $HUD/Root/RightPanel/VBox/Stats/RegenValue
@onready var stat_hp_current: Label = $HUD/Root/RightPanel/VBox/Stats/HpCurrent
@onready var stat_atk_current: Label = $HUD/Root/RightPanel/VBox/Stats/AtkCurrent
@onready var stat_aspd_current: Label = $HUD/Root/RightPanel/VBox/Stats/AspdCurrent
@onready var stat_range_current: Label = $HUD/Root/RightPanel/VBox/Stats/RangeCurrent
@onready var stat_armor_current: Label = $HUD/Root/RightPanel/VBox/Stats/ArmorCurrent
@onready var stat_speed_current: Label = $HUD/Root/RightPanel/VBox/Stats/SpeedCurrent
@onready var stat_max_mana_current: Label = $HUD/Root/RightPanel/VBox/Stats/MaxManaCurrent
@onready var stat_starting_mana_current: Label = $HUD/Root/RightPanel/VBox/Stats/StartManaCurrent
@onready var stat_regen_current: Label = $HUD/Root/RightPanel/VBox/Stats/RegenCurrent
@onready var buffs_label: Label = $HUD/Root/RightPanel/VBox/Buffs
@onready var opponent_option: OptionButton = $HUD/Root/RightPanel/VBox/OpponentRow/OpponentOption
@onready var start_button: Button = $HUD/Root/RightPanel/VBox/StartButton
@onready var back_button: Button = $HUD/Root/TopBar/HBox/BackButton
@onready var top_live: Label = $HUD/Root/TopBar/HBox/TopLive
@onready var skill_slots: HBoxContainer = $HUD/Root/SkillPanel/VBox/Slots
@onready var skill_status: Label = $HUD/Root/SkillPanel/VBox/Header/SkillStatus
@onready var pause_button: Button = $HUD/Root/SkillPanel/VBox/Controls/PauseButton
@onready var speed_button: Button = $HUD/Root/SkillPanel/VBox/Controls/SpeedButton
@onready var mana_button: Button = $HUD/Root/SkillPanel/VBox/Controls/ManaButton
@onready var wound_button: Button = $HUD/Root/SkillPanel/VBox/Controls/WoundButton
@onready var reset_button: Button = $HUD/Root/SkillPanel/VBox/Controls/ResetButton
@onready var toast_label: Label = $HUD/Root/Toast
@onready var stat_save_status: Label = $HUD/Root/RightPanel/VBox/StatSaveStatus


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	# 试炼场 UI 必须在暂停时继续响应；Battle 子节点单独设为 PAUSABLE。
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(_go_setup)
	start_button.pressed.connect(_start_1v1)
	pause_button.pressed.connect(_toggle_pause)
	speed_button.pressed.connect(_cycle_speed)
	mana_button.pressed.connect(_fill_mana)
	wound_button.pressed.connect(_apply_wound)
	reset_button.pressed.connect(_reset_demo)
	get_viewport().size_changed.connect(_refresh_live)
	_build_cards()
	_populate_opponents()
	_wire_stat_inputs()
	_build_skill_cards()
	if not _cards.is_empty():
		_select_definition(_cards[0].definition)
	_create_training_battle(selected_definition)
	_refresh_live()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _build_cards() -> void:
	for definition in UnitCatalog.all():
		var card: UnitCard = CARD_SCENE.instantiate()
		hero_grid.add_child(card)
		card.setup(definition)
		card.card_selected.connect(_select_definition)
		_cards.append(card)
	hero_count.text = "%d" % _cards.size()


func _build_skill_cards() -> void:
	for index in ACTIVE_SLOT_COUNT + 1:
		var card: TrainingSkillCard = SKILL_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_slots.add_child(card)
		card.cast_requested.connect(_on_skill_cast_requested)
		skill_cards.append(card)


func _populate_opponents() -> void:
	opponent_option.clear()
	_opponents = UnitCatalog.all()
	var default_index := 0
	for index in _opponents.size():
		var definition := _opponents[index]
		opponent_option.add_item(definition.display_name, index)
		if definition.unit_id == &"armored_orc":
			default_index = index
	opponent_option.select(default_index)


func _create_training_battle(definition: UnitDefinition) -> void:
	if definition == null:
		return
	battle = BATTLE_SCENE.instantiate()
	battle.training_mode = true
	battle.training_definition = definition
	battle.process_mode = Node.PROCESS_MODE_PAUSABLE
	battle_host.add_child(battle)
	# 试炼场使用自己的技能栏，嵌套 Battle 的 HUD 只负责战斗内部逻辑，不显示也不接收输入。
	battle.hud.visible = false
	battle.hud.process_mode = Node.PROCESS_MODE_DISABLED
	hero = battle.training_hero
	dummy = battle.training_dummy
	_refresh_controls()


func _select_definition(definition: UnitDefinition) -> void:
	if definition == null:
		return
	selected_definition = definition
	for card in _cards:
		var selected := card.definition.unit_id == definition.unit_id
		card.set_selected(selected)
		if selected:
			hero_scroll.call_deferred("ensure_control_visible", card)
	_update_details(definition)
	_refresh_skill_slots(definition)
	if battle != null:
		_set_paused(false)
		battle.start_training(definition)
		hero = battle.training_hero
		dummy = battle.training_dummy
		_refresh_controls()
	_refresh_live()


func _update_details(definition: UnitDefinition) -> void:
	detail_name.text = definition.display_name
	detail_title.text = "「%s」" % definition.title
	detail_meta.text = "%s · %s · 蓝量 %d" % [definition.faction_label(), definition.role, roundi(definition.max_mana)]
	detail_meta.add_theme_color_override("font_color", definition.accent_color)
	detail_desc.text = definition.description
	stat_hp.set_value_no_signal(definition.max_hp)
	stat_atk.set_value_no_signal(definition.attack_damage)
	stat_aspd.set_value_no_signal(definition.attack_speed)
	stat_range.set_value_no_signal(definition.attack_range)
	# armor 内部是 0.00~0.80 的减伤比例；属性面板按 0~80 的百分数显示和编辑。
	stat_armor.set_value_no_signal(definition.armor * 100.0)
	stat_speed.set_value_no_signal(definition.move_speed)
	stat_max_mana.set_value_no_signal(definition.max_mana)
	stat_starting_mana.set_value_no_signal(definition.starting_mana)
	stat_regen.set_value_no_signal(definition.mana_regen)


## 技能槽固定 3 主动 + 1 被动，和 docs/SKILL_ROSTER.md 的技能设计口径一致。
func _active_actions(definition: UnitDefinition) -> Array[CombatActionDefinition]:
	var regular: Array[CombatActionDefinition] = []
	var ultimates: Array[CombatActionDefinition] = []
	for action in definition.actions:
		if action == null or action.category == CombatActionDefinition.Category.BASIC:
			continue
		var is_ultimate := definition.max_mana > 0.0 and action.mana_cost >= definition.max_mana - 0.001
		if is_ultimate:
			ultimates.append(action)
		else:
			regular.append(action)
	regular.append_array(ultimates)
	return regular


func _refresh_skill_slots(definition: UnitDefinition) -> void:
	if definition == null:
		return
	var actives := _active_actions(definition)
	for index in ACTIVE_SLOT_COUNT:
		var action: CombatActionDefinition = actives[index] if index < actives.size() else null
		skill_cards[index].setup_slot("主动 %d" % (index + 1), action, null,
			definition.attack_damage, definition.max_mana, index)
	skill_cards[PASSIVE_SLOT_INDEX].setup_slot("被动", null, definition.passive,
		definition.attack_damage, definition.max_mana, PASSIVE_SLOT_INDEX)


func _wire_stat_inputs() -> void:
	for spin in [stat_hp, stat_atk, stat_aspd, stat_range, stat_armor, stat_speed,
			stat_max_mana, stat_starting_mana, stat_regen]:
		spin.value_changed.connect(_on_stat_value_changed)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < REFRESH_INTERVAL:
		return
	_refresh_accum = 0.0
	_refresh_live()


func _refresh_live() -> void:
	if not is_instance_valid(battle):
		top_live.text = "稻草人靶 · 准备中"
		return
	if not is_instance_valid(hero):
		top_live.text = "稻草人靶 · 等待英雄"
		live_label.text = "未能生成训练单位。"
		return
	var damage := battle.training_damage()
	var elapsed := maxf(battle.elapsed, 0.1)
	var dps := damage / elapsed
	var state_text := "已暂停" if get_tree().paused else ("交战中" if battle.battle_active else "待机")
	var current := _current_action_text()
	top_live.text = "稻草人靶 · 累计伤害 %d · DPS %.1f · %s" % [roundi(damage), dps, state_text]
	live_label.text = "生命 %d / %d · 蓝量 %d / %d\n对稻草人累计 %d · DPS %.1f\n%s%s" % [
		roundi(hero.hp), roundi(hero.max_hp), roundi(hero.mana), roundi(hero.max_mana),
		roundi(damage), dps, state_text, (" · " + current) if not current.is_empty() else "",
	]
	skill_status.text = "自动交战中 · 点击技能卡立即施放" if not get_tree().paused else "已暂停 · 点击技能卡会继续演示"
	_refresh_skill_states()
	_refresh_stat_comparison()
	_refresh_status_list()


## 右侧属性面板同时展示基础值与当前值；buff/debuff 改变当前值时用颜色和差值标出。
func _refresh_stat_comparison() -> void:
	if selected_definition == null or not is_instance_valid(hero):
		return
	_set_current_stat(stat_hp_current, selected_definition.max_hp, hero.max_hp, "", 0, true)
	_set_current_stat(stat_atk_current, selected_definition.attack_damage, hero.current_attack_damage(), "", 1, true)
	_set_current_stat(stat_aspd_current, selected_definition.attack_speed,
		hero.current_attack_speed(), "", 2, true)
	_set_current_stat(stat_range_current, selected_definition.attack_range, hero.attack_range, "", 0, true)
	_set_current_stat(stat_armor_current, selected_definition.armor * 100.0, hero.current_armor() * 100.0, "%", 1, true)
	var current_speed := hero.move_speed
	if hero.status_controller != null:
		current_speed = hero.status_controller.modify_stat(&"move_speed", hero.move_speed)
	_set_current_stat(stat_speed_current, selected_definition.move_speed, current_speed, "", 0, true)
	_set_current_stat(stat_max_mana_current, selected_definition.max_mana, hero.max_mana, "", 0, true)
	# 入场蓝量是生成时的配置，不会被 buff/debuff 修改。
	stat_starting_mana_current.text = "—"
	stat_starting_mana_current.add_theme_color_override("font_color", Color("#6b7787"))
	_set_current_stat(stat_regen_current, selected_definition.mana_regen, hero.mana_regen, "", 1, true)


func _set_current_stat(label: Label, base: float, current: float, suffix: String, decimals: int, higher_is_better: bool) -> void:
	if label == null:
		return
	var current_text := _num_text(current, decimals)
	if is_equal_approx(base, current):
		label.text = current_text + suffix
		label.add_theme_color_override("font_color", Color("#93a0b4"))
		return
	var delta := current - base
	var improved := delta > 0.0 if higher_is_better else delta < 0.0
	var sign_text := "+" if delta > 0.0 else "-"
	label.text = "%s%s (%s%s%s)" % [current_text, suffix, sign_text, _num_text(absf(delta), decimals), suffix]
	label.add_theme_color_override("font_color", Color("#8fe3a8") if improved else Color("#ff9a8a"))


func _refresh_status_list() -> void:
	if not is_instance_valid(hero):
		return
	var statuses := hero.status_controller.snapshot()
	if statuses.is_empty():
		buffs_label.text = "状态：无"
		buffs_label.add_theme_color_override("font_color", Color("#4a5261"))
		return
	var parts: Array[String] = []
	var has_debuff := false
	for status in statuses:
		var tags: Array = status.get("tags", [])
		if tags.has(&"debuff") or tags.has(&"control") or tags.has(&"dot"):
			has_debuff = true
		var stacks := int(status.get("stacks", 1))
		var stack_text := " ×%d" % stacks if stacks > 1 else ""
		var duration_text := "常驻" if bool(status.get("persistent", false)) else "%.1fs" % float(status.get("remaining", 0.0))
		parts.append("%s %s%s" % [str(status.get("display_name", "状态")), duration_text, stack_text])
	buffs_label.text = "状态：" + " · ".join(PackedStringArray(parts))
	buffs_label.add_theme_color_override("font_color", Color("#ff9a8a") if has_debuff else Color("#d8b877"))


func _num_text(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(roundi(value))
	var text := String.num(value, decimals)
	while text.contains(".") and text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text


func _current_action_text() -> String:
	if not is_instance_valid(hero) or not is_instance_valid(hero.state_machine):
		return ""
	if hero.state_machine.current_name == &"action" and hero.planned_action != null:
		return hero.planned_action.display_name
	if hero.state_machine.current_name == &"move":
		return "移动"
	if hero.state_machine.current_name == &"hurt":
		return "受击"
	return "待机"


func _refresh_skill_states() -> void:
	if not is_instance_valid(hero):
		return
	var casting := hero.state_machine.current_name == &"action" and hero.planned_action != null
	for index in ACTIVE_SLOT_COUNT:
		var card := skill_cards[index]
		var action := card.action
		if action == null:
			continue
		if casting and hero.planned_action == action:
			card.set_live_state("施放中", TrainingSkillCard.CAST_COLOR)
		elif hero.action_cooldown(action) > 0.05:
			card.set_live_state("冷却 %.1fs" % hero.action_cooldown(action), TrainingSkillCard.COOLDOWN_COLOR)
		elif not hero.has_mana(action):
			card.set_live_state("蓝量不足", TrainingSkillCard.MANA_COLOR)
		else:
			card.set_live_state("就绪", TrainingSkillCard.READY_COLOR)
	var current_attack := hero.current_attack_damage()
	for index in ACTIVE_SLOT_COUNT:
		skill_cards[index].refresh_damage(current_attack)
	var passive_card := skill_cards[PASSIVE_SLOT_INDEX]
	if passive_card.passive != null:
		var stacks_status := passive_card.passive.skill_hit_stacks_status
		if stacks_status != null:
			var stacks := hero.status_controller.stacks(stacks_status.id)
			if stacks > 0:
				passive_card.set_live_state("热诚 %d/%d · %.1fs" % [
					stacks, stacks_status.max_stacks, hero.status_controller.remaining(stacks_status.id),
				], TrainingSkillCard.PASSIVE_COLOR)
			else:
				passive_card.set_live_state("热诚 0/%d" % stacks_status.max_stacks,
					TrainingSkillCard.COOLDOWN_COLOR)
		elif passive_card.passive.hp_threshold_status != null:
			var active := passive_card.passive.threshold_active(hero.status_controller)
			passive_card.set_live_state("生效中" if active else "未生效",
				TrainingSkillCard.PASSIVE_COLOR if active else TrainingSkillCard.COOLDOWN_COLOR)
		elif passive_card.passive.remaining(hero.status_controller) > 0.0:
			passive_card.set_live_state("生效中 %.1fs" % passive_card.passive.remaining(hero.status_controller),
				TrainingSkillCard.PASSIVE_COLOR)
		else:
			passive_card.set_live_state("已生效", TrainingSkillCard.PASSIVE_COLOR)


func _on_skill_cast_requested(action: CombatActionDefinition) -> void:
	_cast_action(action)


## 手动演示：补足蓝量与冷却、按动作类型选择稻草人/自身为目标，
## 必要时把英雄移动到技能有效距离，然后强制进入真实 Action 状态。
func _cast_action(action: CombatActionDefinition) -> void:
	if action == null or not is_instance_valid(battle):
		return
	if get_tree().paused:
		_set_paused(false)
	if not is_instance_valid(hero) or not hero.alive:
		_reset_demo()
		return
	if not is_instance_valid(dummy):
		return

	if hero.state_machine.current_name != &"idle":
		hero.state_machine.transition_to(&"idle", true)
	_prepare_hero_for_cast(action)

	var cast_target: Unit = dummy
	match action.target_mode:
		CombatActionDefinition.TargetMode.ALLY, CombatActionDefinition.TargetMode.SELF:
			cast_target = hero
		CombatActionDefinition.TargetMode.POINT, CombatActionDefinition.TargetMode.DIRECTION:
			cast_target = dummy

	hero.target = dummy
	hero.planned_action = action
	hero.planned_target = cast_target
	hero.planned_direction = (dummy.global_position - hero.global_position).normalized()
	if hero.planned_direction.length_squared() < 0.001:
		hero.planned_direction = Vector2.RIGHT
	hero.planned_point = dummy.global_position
	hero.planned_has_point = action.target_mode == CombatActionDefinition.TargetMode.POINT

	_position_hero_for_demo(action, cast_target)
	# 移动后重新计算朝向与落点。
	hero.planned_direction = (dummy.global_position - hero.global_position).normalized()
	if hero.planned_direction.length_squared() < 0.001:
		hero.planned_direction = Vector2.RIGHT
	hero.planned_point = dummy.global_position
	hero.target = dummy

	var activation_target := hero.action_target(action)
	var reason := ActionActivation.reason(hero, action, activation_target, hero.planned_direction,
		hero.planned_point, hero.planned_has_point)
	if not reason.is_empty():
		_show_toast("无法施放「%s」：%s" % [action.display_name, reason])
		return
	hero.face_direction(hero.planned_direction.x)
	if not hero.state_machine.transition_to(&"action", true):
		_show_toast("「%s」未能进入施放状态" % action.display_name)
		return
	_show_toast("演示：%s → 稻草人" % action.display_name)
	_refresh_live()


func _prepare_hero_for_cast(action: CombatActionDefinition) -> void:
	hero.mana = maxf(hero.mana, action.mana_cost)
	hero.action_cooldowns[action.action_id] = 0.0
	# 治疗/防御技能需要受伤目标或低血量条件；演示前把英雄调整到满足条件的状态。
	if action.requires_wounded_ally and not _has_wounded_ally():
		hero.hp = maxf(1.0, hero.max_hp * 0.45)
	if hero.hp_ratio() > action.max_self_hp_ratio:
		hero.hp = maxf(1.0, hero.max_hp * maxf(action.max_self_hp_ratio - 0.02, 0.05))
	if hero.hp_ratio() < action.min_self_hp_ratio:
		hero.hp = minf(hero.max_hp, hero.max_hp * (action.min_self_hp_ratio + 0.02))
	hero.health_bar.set_ratio(hero.hp / hero.max_hp)
	hero.sync_conditional_passives()


func _has_wounded_ally() -> bool:
	for unit in battle.living_units(hero.team):
		if unit.hp < unit.max_hp - 0.5:
			return true
	return false


## 让主动技能一定落在可见范围内：只在当前距离无法施放时短距离挪动英雄。
func _position_hero_for_demo(action: CombatActionDefinition, _cast_target: Unit) -> void:
	if not is_instance_valid(dummy) or not is_instance_valid(hero):
		return
	var distance := hero.global_position.distance_to(dummy.global_position)
	var desired := 0.0
	match action.target_mode:
		CombatActionDefinition.TargetMode.ENEMY:
			if action.movement_kind() == ActionMovementDefinition.Kind.CHARGE:
				desired = 300.0
			elif not hero.is_target_in_action_range(action, 8.0):
				desired = _desired_cast_distance(action)
		CombatActionDefinition.TargetMode.DIRECTION:
			var reach := maxf(hero.action_aoe_reach(action), _largest_effect_radius(action))
			desired = clampf(reach * 0.62, 60.0, 240.0) if reach > 0.0 else 140.0
		CombatActionDefinition.TargetMode.POINT:
			if distance > action.action_range - 8.0 or distance < action.min_range + 4.0:
				desired = clampf(action.action_range * 0.58, 90.0, 340.0)
		CombatActionDefinition.TargetMode.SELF:
			if _action_has_damage(action):
				var radius := _largest_effect_radius(action)
				if radius > 0.0 and distance > radius + dummy.body_radius * 0.5:
					desired = clampf(radius * 0.55, 55.0, 150.0)
		_:
			desired = 0.0
	if desired <= 0.0:
		return
	# 冲锋技能给一点助跑距离；其余动作站在稻草人左侧。
	var move_to := dummy.global_position + Vector2(-desired, 0.0)
	hero.position = battle.clamp_unit_position(move_to)
	hero.face_direction(1.0)


func _desired_cast_distance(action: CombatActionDefinition) -> float:
	var reach := hero.action_aoe_reach(action)
	if reach > 0.0:
		return clampf(reach * 0.62, 50.0, 300.0)
	var distance := clampf(action.action_range * 0.7, 46.0, 300.0)
	# 有最小施放距离的突进技能（例如追击步）不能把演示站位放得太近。
	if action.min_range > 0.0:
		distance = maxf(distance, action.min_range + 20.0)
	return distance


func _largest_effect_radius(action: CombatActionDefinition) -> float:
	var radius := 0.0
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.STATUS:
			if effect.shape == ActionEffectDefinition.Shape.CIRCLE or effect.shape == ActionEffectDefinition.Shape.CONE:
				radius = maxf(radius, effect.radius)
	return radius


func _action_has_damage(action: CombatActionDefinition) -> bool:
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.PROJECTILE:
			return true
	return false


func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_refresh_controls()


func _cycle_speed() -> void:
	if not is_instance_valid(battle):
		return
	battle.toggle_speed()
	_refresh_controls()


func _refresh_controls() -> void:
	if pause_button == null:
		return
	pause_button.text = "继续" if get_tree().paused else "暂停"
	if is_instance_valid(battle):
		speed_button.text = "×0.5" if battle.speed_multiplier < 0.75 else "×%d" % int(battle.speed_multiplier)


func _fill_mana() -> void:
	if not is_instance_valid(hero):
		return
	hero.mana = hero.max_mana
	_show_toast("蓝量已充满")
	_refresh_live()


func _apply_wound() -> void:
	if not is_instance_valid(hero):
		return
	hero.hp = maxf(1.0, hero.max_hp * 0.45)
	hero.health_bar.set_ratio(hero.hp / hero.max_hp)
	hero.sync_conditional_passives()
	_show_toast("英雄生命降至 45%，可演示低血量被动、治疗与防御技能")
	_refresh_live()


func _reset_demo() -> void:
	if not is_instance_valid(battle) or selected_definition == null:
		return
	_set_paused(false)
	battle.start_training(selected_definition)
	hero = battle.training_hero
	dummy = battle.training_dummy
	_refresh_controls()
	_refresh_live()
	_show_toast("演示已重置")


func _show_toast(message: String) -> void:
	if toast_label == null:
		return
	_toast_serial += 1
	var serial := _toast_serial
	toast_label.text = message
	toast_label.visible = true
	toast_label.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_interval(1.25)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		if serial == _toast_serial:
			toast_label.visible = false
			toast_label.modulate.a = 1.0
	)


func _on_stat_value_changed(_value: float) -> void:
	if selected_definition == null:
		return
	var previous_starting_mana := selected_definition.starting_mana
	var stats := {
		"max_hp": stat_hp.value,
		"attack_damage": stat_atk.value,
		"attack_speed": stat_aspd.value,
		"attack_range": stat_range.value,
		"armor": stat_armor.value / 100.0,
		"move_speed": stat_speed.value,
		"max_mana": stat_max_mana.value,
		"starting_mana": stat_starting_mana.value,
		"mana_regen": stat_regen.value,
	}
	selected_definition.apply_stat_override(stats)
	if is_instance_valid(hero):
		hero.apply_debug_stats(stats)
		if not is_equal_approx(previous_starting_mana, selected_definition.starting_mana):
			hero.mana = selected_definition.starting_mana
	_update_details(selected_definition)
	_refresh_skill_slots(selected_definition)
	_refresh_live()
	var save_error := UnitCatalog.save_stat_override(selected_definition.unit_id, stats)
	if save_error == OK:
		stat_save_status.text = "已保存 · 重启游戏后仍生效"
		stat_save_status.add_theme_color_override("font_color", Color("#8fe3a8"))
	elif save_error == ERR_UNAVAILABLE:
		stat_save_status.text = "当前为无界面测试模式，未写入用户配置"
		stat_save_status.add_theme_color_override("font_color", Color("#93a0b4"))
	else:
		stat_save_status.text = "保存失败：%s" % error_string(save_error)
		stat_save_status.add_theme_color_override("font_color", Color("#ff9a8a"))


func _start_1v1() -> void:
	if selected_definition == null or _opponents.is_empty():
		return
	var opponent_index := opponent_option.selected
	if opponent_index < 0 or opponent_index >= _opponents.size():
		opponent_index = 0
	var opponent := _opponents[opponent_index]
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	GameState.set_slot(0, 0, selected_definition.unit_id)
	GameState.set_slot(1, 0, opponent.unit_id)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _go_setup() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(SETUP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speed_toggle"):
		_cycle_speed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_go_setup()
		get_viewport().set_input_as_handled()
