class_name ArenaSetup
extends Control

## 同一座战场上的准备界面，负责英雄名册、阵容和静态详情。

const CARD_SCENE := preload("res://scenes/setup/unit_card.tscn")
const LAB_SCENE := "res://scenes/debug/hero_lab.tscn"

const DRAWER_HEIGHT := 291.0
const DRAWER_CLOSED_TOP := -60.0
const DRAWER_OPEN_TOP := DRAWER_CLOSED_TOP - DRAWER_HEIGHT
const OPEN_VIEW_OFFSET := 154.0
const LINEUP_OPEN_TOP := 76.0

var selected_definition: UnitDefinition
var cards: Array[UnitCard] = []

@onready var field: Control = $UI/Root/Field
@onready var roster_grid: GridContainer = $UI/Root/Drawer/Panel/Split/Roster/RosterScroll/RosterGrid
@onready var roster_count: Label = $UI/Root/Drawer/Panel/Split/Roster/RosterHeader/RosterCount
@onready var blue_panel: LineupPanel = $UI/Root/BluePanel
@onready var red_panel: LineupPanel = $UI/Root/RedPanel
@onready var detail_portrait: TextureRect = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Header/Portrait
@onready var detail_name: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Header/Identity/Name
@onready var detail_title: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Header/Identity/Title
@onready var detail_meta: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Header/Identity/Meta
@onready var detail_desc: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Scroll/Desc
@onready var stat_hp: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/HpCell/Value
@onready var stat_atk: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/AtkCell/Value
@onready var stat_aspd: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/AspdCell/Value
@onready var stat_range: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/RangeCell/Value
@onready var stat_armor: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/ArmorCell/Value
@onready var stat_move: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Stats/MoveCell/Value
@onready var random_button: Button = $UI/Root/Footer/Row/Actions/RandomButton
@onready var clear_button: Button = $UI/Root/Footer/Row/Actions/ClearButton
@onready var mode_select: OptionButton = $UI/Root/Header/HeaderRight/ModeSelect
@onready var lab_button: Button = $UI/Root/Header/HeaderRight/LabButton
@onready var save_match_button: Button = $UI/Root/Header/HeaderRight/SaveMatchButton
@onready var save_match_dialog: FileDialog = $SaveMatchDialog
@onready var start_button: Button = $UI/Root/Header/HeaderRight/StartButton
@onready var all_filter: Button = $UI/Root/Drawer/Panel/Split/Roster/RosterHeader/Filters/AllFilter
@onready var human_filter: Button = $UI/Root/Drawer/Panel/Split/Roster/RosterHeader/Filters/HumanFilter
@onready var wilderness_filter: Button = $UI/Root/Drawer/Panel/Split/Roster/RosterHeader/Filters/WildernessFilter
@onready var monster_filter: Button = $UI/Root/Drawer/Panel/Split/Roster/RosterHeader/Filters/MonsterFilter
@onready var toast_box: PanelContainer = $UI/Root/ToastBox
@onready var toast_label: Label = $UI/Root/ToastBox/ToastLabel

@onready var battle: Battle = $Battle
@onready var editor: Control = $UI/Root
@onready var drawer: Control = $UI/Root/Drawer
@onready var drawer_toggle: Button = $UI/Root/Footer/Row/Toggle
@onready var drawer_panel: PanelContainer = $UI/Root/Drawer/Panel
@onready var roster_scroll: ScrollContainer = $UI/Root/Drawer/Panel/Split/Roster/RosterScroll
@onready var detail_panel: VBoxContainer = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details
@onready var detail_empty: Label = $UI/Root/Drawer/Panel/Split/DetailPanel/Empty
@onready var detail_scroll: ScrollContainer = $UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Scroll

var _toast_tween: Tween
var _drawer_tween: Tween
var _drawer_open := true
var _camera_tween: Tween
var _camera_offset := 0.0


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
	blue_panel.preset_changed.connect(_refresh_panels)
	red_panel.preset_changed.connect(_refresh_panels)
	battle.deployment_changed.connect(_on_deployment_changed)
	drawer_toggle.pressed.connect(_toggle_drawer)
	$UI/Root/Drawer/Panel/Split/DetailPanel/Margin/Details/Header/Close.pressed.connect(close_details)
	random_button.pressed.connect(_on_random_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	mode_select.add_item("歼灭模式", GameState.BattleMode.ELIMINATION)
	mode_select.add_item("攻坚模式", GameState.BattleMode.SIEGE)
	mode_select.select(mode_select.get_item_index(GameState.battle_mode))
	mode_select.item_selected.connect(_on_mode_selected)
	_on_mode_selected(mode_select.selected)
	$UI/Root/Header/HeaderRight/AudioButton.pressed.connect(AudioMix.open_settings)
	lab_button.pressed.connect(_on_lab_pressed)
	save_match_button.pressed.connect(_on_save_match_pressed)
	save_match_dialog.file_selected.connect(_save_match)
	start_button.pressed.connect(_on_start_pressed)
	all_filter.pressed.connect(_set_filter.bind(-1))
	human_filter.pressed.connect(_set_filter.bind(UnitDefinition.Faction.HUMAN))
	wilderness_filter.pressed.connect(_set_filter.bind(UnitDefinition.Faction.WILDERNESS))
	monster_filter.pressed.connect(_set_filter.bind(UnitDefinition.Faction.MONSTER))
	toast_box.visible = false
	_animate_drawer_top(DRAWER_OPEN_TOP)
	_build_roster()
	_refresh_panels()
	editor.resized.connect(_layout_lineup_panels)
	roster_scroll.resized.connect(_update_roster_columns)
	call_deferred("_update_roster_columns")
	if BattleTransition.is_loading():
		await BattleTransition.finished
		_on_start_pressed()


func _build_roster() -> void:
	for definition in UnitCatalog.all():
		var card: UnitCard = CARD_SCENE.instantiate()
		roster_grid.add_child(card)
		card.setup(definition)
		card.card_selected.connect(_on_card_selected)
		cards.append(card)
	roster_count.text = "%d 名" % cards.size()


func _on_card_selected(definition: UnitDefinition) -> void:
	battle.select_unit(null)
	_select_definition(definition)


func _select_definition(definition: UnitDefinition) -> void:
	selected_definition = definition
	detail_panel.show()
	detail_empty.hide()
	if not _drawer_open:
		_toggle_drawer()
	detail_scroll.scroll_vertical = 0
	for card in cards:
		card.set_selected(card.definition.unit_id == definition.unit_id)
	detail_portrait.texture = definition.portrait
	detail_name.text = definition.display_name
	detail_title.text = "「%s」" % definition.title
	detail_meta.text = "%s · %s" % [definition.faction_label(), definition.role]
	detail_meta.add_theme_color_override("font_color", definition.accent_color)
	detail_desc.text = "%s\n%s" % [definition.description, definition.skill_description_text()]
	stat_hp.text = "%d" % roundi(definition.max_hp)
	stat_atk.text = "%d" % roundi(definition.attack_damage)
	stat_aspd.text = "%.2f" % definition.attack_speed
	stat_range.text = "%d" % roundi(definition.attack_range)
	stat_armor.text = "%d%%" % roundi(definition.armor * 100.0)
	stat_move.text = "%d" % roundi(definition.move_speed)


func _update_roster_columns() -> void:
	if roster_scroll.size.x <= 1.0:
		return
	var columns := clampi(int((roster_scroll.size.x - 14.0) / 134.0), 1, 12)
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
	var unit := battle.unit_in_slot(team, slot)
	if unit == null:
		_toast("将名册中的英雄拖到空槽位")
		return
	select_field_unit(unit)


func _on_hero_dropped(team: int, slot: int, unit_id: StringName) -> void:
	_deploy_hero(team, slot, unit_id)


func _deploy_hero(team: int, slot: int, unit_id: StringName, point: Variant = null) -> void:
	var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
	if definition == null:
		return
	var previous: Variant = GameState.get_slot(team, slot)
	if previous == unit_id and point == null:
		_toast("该英雄已在此槽位")
		return
	if not GameState.set_slot(team, slot, unit_id):
		return
	if point != null:
		battle.set_deployment_position(team, slot, point)
	_refresh_panels()
	if previous == null:
		_toast("已部署 %s → %s 第 %d 位" % [
			definition.display_name, GameState.team_name(team), slot + 1,
		])
	else:
		_toast("已将第 %d 位替换为 %s" % [slot + 1, definition.display_name])


func move_deployed_unit(team: int, slot: int, point: Vector2) -> void:
	battle.set_deployment_position(team, slot, point)
	_refresh_panels()


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
	if target_id == null:
		_toast("已移动 %s 到第 %d 位" % [definition.display_name if definition else "英雄", target_slot + 1])
	else:
		_toast("已交换两名英雄")


func _on_remove_requested(team: int, slot: int) -> void:
	var unit_id: Variant = GameState.get_slot(team, slot)
	if unit_id == null:
		return
	var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
	if battle.selected_unit == battle.unit_in_slot(team, slot):
		close_details()
	GameState.remove_slot(team, slot)
	_refresh_panels()
	_toast("已移除 %s" % (definition.display_name if definition != null else "英雄"))


func select_field_unit(unit: Unit) -> void:
	if unit == null:
		close_details()
	else:
		battle.select_unit(unit)
		_select_definition(unit.definition)


func close_details() -> void:
	selected_definition = null
	for card in cards:
		card.set_selected(false)
	detail_panel.hide()
	detail_empty.show()
	battle.select_unit(null)


func _toggle_drawer() -> void:
	_drawer_open = not _drawer_open
	drawer_toggle.text = "收起英雄名册  ▾" if _drawer_open else "展开英雄名册  ▴"
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	drawer_panel.show()
	var target := DRAWER_OPEN_TOP if _drawer_open else DRAWER_CLOSED_TOP
	_drawer_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_method(_animate_drawer_top, drawer.offset_top, target, 0.22)
	if not _drawer_open:
		_drawer_tween.tween_callback(drawer_panel.hide)


func _set_drawer_top(top: float) -> void:
	drawer.offset_top = top
	drawer.offset_bottom = top + DRAWER_HEIGHT


func _animate_drawer_top(top: float) -> void:
	_set_drawer_top(top)
	_set_camera_offset(_drawer_view_offset())


func _drawer_view_offset() -> float:
	return clampf((DRAWER_CLOSED_TOP - drawer.offset_top) / DRAWER_HEIGHT, 0.0, 1.0) * OPEN_VIEW_OFFSET


func _set_camera_offset(pixels: float) -> void:
	_camera_offset = pixels
	battle.set_deployment_view_offset(pixels)
	_layout_lineup_panels()


func _layout_lineup_panels() -> void:
	var extra_height := maxf(0.0, editor.size.y - Battle.BASE_SIZE.y)
	var lineup_top := LINEUP_OPEN_TOP + extra_height * 0.5 + OPEN_VIEW_OFFSET - _camera_offset
	blue_panel.position.y = lineup_top
	red_panel.position.y = lineup_top


func _on_deployment_changed(active: bool) -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
		_set_drawer_top(DRAWER_OPEN_TOP if _drawer_open else DRAWER_CLOSED_TOP)
		drawer_panel.visible = _drawer_open
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_method(_set_camera_offset, _camera_offset, _drawer_view_offset() if active else 0.0, 0.22)
	editor.visible = active
	close_details()
	toast_box.hide()
	if active:
		_refresh_panels()


func _refresh_panels() -> void:
	var previous := battle.selected_unit
	battle.refresh_deployment()
	if previous != null and battle.selected_unit == null:
		close_details()
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


func _on_mode_selected(index: int) -> void:
	GameState.battle_mode = mode_select.get_item_id(index) as GameState.BattleMode
	mode_select.tooltip_text = "摧毁敌方主基地。英雄阵亡后会复活。" if GameState.battle_mode == GameState.BattleMode.SIEGE else "歼灭敌方所有作战单位。"
	battle.refresh_deployment()


func _on_start_pressed() -> void:
	if not GameState.lineup_ready():
		_toast("双方至少各部署 1 名英雄")
		return
	battle.start_deployed_battle()


func _on_save_match_pressed() -> void:
	if not GameState.lineup_ready():
		_toast("双方至少各部署 1 名英雄")
		return
	save_match_dialog.current_file = "arena-match.json"
	save_match_dialog.popup_centered_ratio(0.7)


func _save_match(path: String) -> void:
	var config := BattleReplayConfig.from_setup()
	var error := config.save(path)
	_toast("已保存对阵 · 种子 %d" % config.seed if error == OK else "保存对阵失败 · %s" % error_string(error))


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
