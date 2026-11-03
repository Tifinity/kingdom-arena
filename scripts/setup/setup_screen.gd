extends Control

## 布阵界面：英雄名册 + 左右各 5 个槽位。
## 所有配置写入 GameState，开战后由 Battle 场景读取。

const CARD_SCENE := preload("res://scenes/setup/unit_card.tscn")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const LAB_SCENE := "res://scenes/debug/hero_lab.tscn"

var selected_definition: UnitDefinition
var cards: Array[UnitCard] = []

@onready var roster_grid: GridContainer = $Root/VBox/Content/Center/RosterScroll/RosterGrid
@onready var roster_count: Label = $Root/VBox/Content/Center/RosterHeader/RosterCount
@onready var blue_panel: LineupPanel = $Root/VBox/Content/BluePanel
@onready var red_panel: LineupPanel = $Root/VBox/Content/RedPanel
@onready var detail_portrait: TextureRect = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/PortraitFrame/Portrait
@onready var detail_name: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Info/NameRow/Name
@onready var detail_title: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Info/NameRow/Title
@onready var detail_meta: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Info/Meta
@onready var detail_desc: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Info/Desc
@onready var stat_hp: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/HpCell/Value
@onready var stat_atk: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/AtkCell/Value
@onready var stat_aspd: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/AspdCell/Value
@onready var stat_range: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/RangeCell/Value
@onready var stat_armor: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/ArmorCell/Value
@onready var stat_move: Label = $Root/VBox/Content/Center/DetailPanel/Margin/HBox/Stats/MoveCell/Value
@onready var random_button: Button = $Root/VBox/Header/HeaderRight/RandomButton
@onready var clear_button: Button = $Root/VBox/Header/HeaderRight/ClearButton
@onready var lab_button: Button = $Root/VBox/Header/HeaderRight/LabButton
@onready var start_button: Button = $Root/VBox/Header/HeaderRight/StartButton
@onready var all_filter: Button = $Root/VBox/Content/Center/RosterHeader/Filters/AllFilter
@onready var kingdom_filter: Button = $Root/VBox/Content/Center/RosterHeader/Filters/KingdomFilter
@onready var legion_filter: Button = $Root/VBox/Content/Center/RosterHeader/Filters/LegionFilter
@onready var toast_box: PanelContainer = $ToastBox
@onready var toast_label: Label = $ToastBox/ToastLabel

var _toast_tween: Tween


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	blue_panel.slot_pressed.connect(_on_slot_pressed)
	blue_panel.remove_requested.connect(_on_remove_requested)
	blue_panel.hero_dropped.connect(_on_hero_dropped)
	blue_panel.slot_dropped.connect(_on_slot_dropped)
	red_panel.slot_pressed.connect(_on_slot_pressed)
	red_panel.remove_requested.connect(_on_remove_requested)
	red_panel.hero_dropped.connect(_on_hero_dropped)
	red_panel.slot_dropped.connect(_on_slot_dropped)
	random_button.pressed.connect(_on_random_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	lab_button.pressed.connect(_on_lab_pressed)
	start_button.pressed.connect(_on_start_pressed)
	all_filter.pressed.connect(_set_filter.bind(-1))
	kingdom_filter.pressed.connect(_set_filter.bind(UnitDefinition.Faction.KINGDOM))
	legion_filter.pressed.connect(_set_filter.bind(UnitDefinition.Faction.LEGION))
	toast_box.visible = false
	_build_roster()
	_refresh_panels()
	roster_grid.resized.connect(_update_roster_columns)
	call_deferred("_update_roster_columns")
	if not cards.is_empty():
		_select_definition(cards[0].definition)


func _build_roster() -> void:
	for definition in UnitCatalog.all():
		var card: UnitCard = CARD_SCENE.instantiate()
		roster_grid.add_child(card)
		card.setup(definition)
		card.card_selected.connect(_select_definition)
		cards.append(card)
	roster_count.text = "%d 名" % cards.size()


func _select_definition(definition: UnitDefinition) -> void:
	selected_definition = definition
	for card in cards:
		card.set_selected(card.definition.unit_id == definition.unit_id)
	detail_portrait.texture = definition.portrait
	detail_name.text = definition.display_name
	detail_title.text = "「%s」" % definition.title
	detail_meta.text = "%s · %s" % [definition.faction_label(), definition.role]
	detail_meta.add_theme_color_override("font_color", definition.accent_color)
	detail_desc.text = definition.description
	stat_hp.text = "%d" % roundi(definition.max_hp)
	stat_atk.text = "%d" % roundi(definition.attack_damage)
	stat_aspd.text = "%.2f" % definition.attack_speed
	stat_range.text = "%d" % roundi(definition.attack_range)
	stat_armor.text = "%d%%" % roundi(definition.armor * 100.0)
	stat_move.text = "%d" % roundi(definition.move_speed)


## 窗口变宽时增加名册列数，避免卡片被拉得过宽；窗口变窄时回到 6 列。
func _update_roster_columns() -> void:
	if roster_grid.size.x <= 1.0:
		return
	var columns := clampi(int(roster_grid.size.x / 148.0), 6, 12)
	if roster_grid.columns != columns:
		roster_grid.columns = columns


func _set_filter(faction: int) -> void:
	var visible_count := 0
	for card in cards:
		var show_card := faction < 0 or card.definition.faction == faction
		card.visible = show_card
		if show_card:
			visible_count += 1
	roster_count.text = "显示 %d / %d" % [visible_count, cards.size()]


func _on_slot_pressed(team: int, slot: int) -> void:
	var unit_id: Variant = GameState.get_slot(team, slot)
	if unit_id == null:
		_toast("将名册中的英雄拖到空槽位")
		return
	var definition: UnitDefinition = UnitCatalog.get_definition(StringName(unit_id))
	if definition != null:
		_select_definition(definition)


func _on_hero_dropped(team: int, slot: int, unit_id: StringName) -> void:
	var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
	if definition == null:
		return
	var previous: Variant = GameState.get_slot(team, slot)
	if previous == unit_id:
		_toast("该英雄已在此槽位")
		return
	if not GameState.set_slot(team, slot, unit_id):
		return
	_select_definition(definition)
	_refresh_panels()
	if previous == null:
		_toast("已部署 %s → %s 第 %d 位" % [
			definition.display_name, GameState.team_name(team), slot + 1,
		])
	else:
		_toast("已将第 %d 位替换为 %s" % [slot + 1, definition.display_name])


func _on_slot_dropped(source_team: int, source_slot: int, target_team: int, target_slot: int) -> void:
	if source_team == target_team and source_slot == target_slot:
		return
	var source_id: Variant = GameState.get_slot(source_team, source_slot)
	if source_id == null:
		return
	var target_id: Variant = GameState.get_slot(target_team, target_slot)
	GameState.set_slot(target_team, target_slot, source_id)
	GameState.set_slot(source_team, source_slot, target_id)
	_refresh_panels()
	var definition: UnitDefinition = UnitCatalog.get_definition(StringName(source_id))
	if definition != null:
		_select_definition(definition)
	if target_id == null:
		_toast("已移动 %s 到第 %d 位" % [definition.display_name if definition else "英雄", target_slot + 1])
	else:
		_toast("已交换两名英雄")


func _on_remove_requested(team: int, slot: int) -> void:
	var unit_id: Variant = GameState.get_slot(team, slot)
	if unit_id == null:
		return
	var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
	GameState.remove_slot(team, slot)
	_refresh_panels()
	_toast("已移除 %s" % (definition.display_name if definition != null else "英雄"))


func _refresh_panels() -> void:
	blue_panel.refresh()
	red_panel.refresh()


func _on_random_pressed() -> void:
	for team in 2:
		GameState.clear_lineup(team)
		var pool: Array = UnitCatalog.all().duplicate()
		pool.shuffle()
		for slot in mini(GameState.TEAM_SIZE, pool.size()):
			GameState.set_slot(team, slot, pool[slot].unit_id)
	_refresh_panels()
	_toast("双方随机阵容已生成")


func _on_clear_pressed() -> void:
	GameState.clear_lineup(0)
	GameState.clear_lineup(1)
	_refresh_panels()
	_toast("已清空双方阵容")


func _on_lab_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(LAB_SCENE)


func _on_start_pressed() -> void:
	if not GameState.lineup_ready():
		_toast("双方至少各部署 1 名英雄")
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _toast(message: String) -> void:
	toast_label.text = message
	toast_box.visible = true
	toast_box.modulate = Color(1, 1, 1, 0)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_box, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.32)
	_toast_tween.tween_callback(func() -> void: toast_box.visible = false)
