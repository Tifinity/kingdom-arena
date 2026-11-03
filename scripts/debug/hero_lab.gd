extends Node2D

## 单英雄调试场：选中任意英雄，预览全部动作，或直接进入 1v1 实战。
##
## 预览模式不运行 Brain/FSM，只手动播放 AnimatedSprite2D 上的动画；
## 1v1 模式会切到真实 Battle 场景，便于结合 OODA 观察镜调试决策与状态机。

const UNIT_SCENE := preload("res://scenes/battle/unit.tscn")
const CARD_SCENE := preload("res://scenes/setup/unit_card.tscn")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SETUP_SCENE := "res://scenes/setup/setup_screen.tscn"

const ANIM_ORDER: Array[StringName] = [
	&"idle", &"move", &"attack_01", &"attack_02", &"attack_03",
	&"hurt", &"death", &"block", &"summon", &"heal", &"fly", &"move_02",
]

const ANIM_LABELS := {
	&"idle": "待机",
	&"move": "移动",
	&"move_02": "移动2",
	&"attack_01": "普攻1",
	&"attack_02": "普攻2",
	&"attack_03": "普攻3",
	&"hurt": "受击",
	&"death": "死亡",
	&"block": "格挡",
	&"summon": "召唤",
	&"heal": "治疗",
	&"fly": "飞行",
}

var selected_definition: UnitDefinition
var preview_unit: Unit
var _cards: Array[UnitCard] = []
var _opponents: Array[UnitDefinition] = []

@onready var stage: Node2D = $Stage
@onready var hero_grid: GridContainer = $HUD/Root/LeftPanel/VBox/Scroll/HeroGrid
@onready var hero_scroll: ScrollContainer = $HUD/Root/LeftPanel/VBox/Scroll
@onready var hero_count: Label = $HUD/Root/LeftPanel/VBox/Header/HeroCount
@onready var detail_name: Label = $HUD/Root/RightPanel/VBox/NameRow/Name
@onready var detail_title: Label = $HUD/Root/RightPanel/VBox/NameRow/Title
@onready var detail_meta: Label = $HUD/Root/RightPanel/VBox/Meta
@onready var detail_desc: Label = $HUD/Root/RightPanel/VBox/Desc
@onready var stat_hp: Label = $HUD/Root/RightPanel/VBox/Stats/HpValue
@onready var stat_atk: Label = $HUD/Root/RightPanel/VBox/Stats/AtkValue
@onready var stat_aspd: Label = $HUD/Root/RightPanel/VBox/Stats/AspdValue
@onready var stat_range: Label = $HUD/Root/RightPanel/VBox/Stats/RangeValue
@onready var stat_armor: Label = $HUD/Root/RightPanel/VBox/Stats/ArmorValue
@onready var stat_speed: Label = $HUD/Root/RightPanel/VBox/Stats/SpeedValue
@onready var opponent_option: OptionButton = $HUD/Root/RightPanel/VBox/OpponentRow/OpponentOption
@onready var start_button: Button = $HUD/Root/RightPanel/VBox/StartButton
@onready var back_button: Button = $HUD/Root/TopBar/HBox/BackButton
@onready var animation_buttons: HFlowContainer = $HUD/Root/AnimPanel/VBox/Buttons
@onready var current_anim: Label = $HUD/Root/AnimPanel/VBox/Header/CurrentAnim


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	back_button.pressed.connect(_go_setup)
	start_button.pressed.connect(_start_1v1)
	get_viewport().size_changed.connect(_reposition_preview)
	_build_cards()
	_populate_opponents()
	if not _cards.is_empty():
		_select_definition(_cards[0].definition)
	call_deferred("_reposition_preview")


func _build_cards() -> void:
	for definition in UnitCatalog.all():
		var card: UnitCard = CARD_SCENE.instantiate()
		hero_grid.add_child(card)
		card.setup(definition)
		card.card_selected.connect(_select_definition)
		_cards.append(card)
	hero_count.text = "%d" % _cards.size()


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


func _select_definition(definition: UnitDefinition) -> void:
	selected_definition = definition
	for card in _cards:
		var selected := card.definition.unit_id == definition.unit_id
		card.set_selected(selected)
		if selected:
			hero_scroll.call_deferred("ensure_control_visible", card)
	_update_details(definition)
	_spawn_preview(definition)
	_rebuild_animation_buttons()


func _update_details(definition: UnitDefinition) -> void:
	detail_name.text = definition.display_name
	detail_title.text = "「%s」" % definition.title
	detail_meta.text = "%s · %s · 蓝量 %d" % [definition.faction_label(), definition.role, roundi(definition.max_mana)]
	detail_meta.add_theme_color_override("font_color", definition.accent_color)
	detail_desc.text = definition.description
	stat_hp.text = "%d" % roundi(definition.max_hp)
	stat_atk.text = "%d" % roundi(definition.attack_damage)
	stat_aspd.text = "%.2f" % definition.attack_speed
	stat_range.text = "%d" % roundi(definition.attack_range)
	stat_armor.text = "%d%%" % roundi(definition.armor * 100.0)
	stat_speed.text = "%d" % roundi(definition.move_speed)


func _spawn_preview(definition: UnitDefinition) -> void:
	if is_instance_valid(preview_unit):
		preview_unit.queue_free()
	var unit_scene: PackedScene = definition.unit_scene if definition.unit_scene != null else UNIT_SCENE
	preview_unit = unit_scene.instantiate()
	stage.add_child(preview_unit)
	preview_unit.setup_preview(definition)
	preview_unit.face_direction(1.0)
	_reposition_preview()


func _reposition_preview() -> void:
	if not is_instance_valid(preview_unit):
		return
	var size := get_viewport().get_visible_rect().size
	preview_unit.position = Vector2(size.x * 0.5, size.y * 0.60)


func _rebuild_animation_buttons() -> void:
	for child in animation_buttons.get_children():
		child.queue_free()
	if selected_definition == null or selected_definition.sprite_frames == null:
		return
	for animation in _sorted_animations():
		var button := Button.new()
		button.text = _animation_label(animation)
		button.custom_minimum_size = Vector2(68, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "%s · %d 帧" % [
			_animation_label(animation),
			selected_definition.sprite_frames.get_frame_count(animation),
		]
		button.pressed.connect(_play_animation.bind(StringName(animation)))
		animation_buttons.add_child(button)
	_play_animation(&"idle")


func _play_animation(animation: StringName) -> void:
	if not is_instance_valid(preview_unit) or selected_definition == null:
		return
	preview_unit.play_preview_animation(animation)
	var frames := selected_definition.sprite_frames.get_frame_count(animation)
	var speed := selected_definition.sprite_frames.get_animation_speed(animation)
	current_anim.text = "%s · %d 帧 · %.0f FPS" % [_animation_label(animation), frames, speed]


func _sorted_animations() -> Array:
	var names: Array = selected_definition.sprite_frames.get_animation_names()
	var ordered: Array = []
	for animation in ANIM_ORDER:
		if names.has(animation):
			ordered.append(animation)
	for animation in names:
		if not ordered.has(animation):
			ordered.append(animation)
	return ordered


func _animation_label(animation: StringName) -> String:
	return ANIM_LABELS.get(animation, String(animation))


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
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _go_setup() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(SETUP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_setup()
		get_viewport().set_input_as_handled()
