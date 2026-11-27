class_name BattleRosterCard
extends Button

## 正式对战的出场单位卡。即使单位在死亡动画后释放，头像仍留在原槽位。
const STATUS_SLOTS := 5
const MUTED := Color("#b2a4b5")
const ACTIVE := Color("#a9d39d")

var unit: Unit
var team: int
var slot: int
var _margin: MarginContainer
var _rows: VBoxContainer
var _portrait: TextureRect
var _health: ProgressBar
var _mana: ProgressBar
var _state: Label
var _status_row: HBoxContainer
var _status_icons: Array[TextureRect] = []
var _status_marks: Array[Label] = []
var _overflow: Label
var _skill_timers: Array[Label] = []
var _skills: Array[CombatActionDefinition] = []
var _normal_style: StyleBox
var _selected_style: StyleBox


func bind(fighter: Unit) -> void:
	unit = fighter
	team = fighter.team
	slot = fighter.slot
	var team_color := GameState.team_color(fighter.team)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	theme_type_variation = &"PixelCard"
	_normal_style = get_theme_stylebox("normal")
	_selected_style = get_theme_stylebox("pressed")

	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 8)
	_margin.add_theme_constant_override("margin_right", 8)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_rows)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	_rows.add_child(header)
	var portrait_frame := PanelContainer.new()
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.theme_type_variation = &"PixelInset"
	header.add_child(portrait_frame)
	_portrait = _icon(Vector2(52, 48))
	_portrait.texture = _fit_portrait(fighter.definition.portrait)
	portrait_frame.add_child(_portrait)
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.add_theme_constant_override("separation", 4)
	header.add_child(vitals)
	var name_label := _label(fighter.definition.display_name, 16, team_color.lightened(0.24))
	vitals.add_child(name_label)
	_health = _bar(team_color, 8)
	_mana = _bar(Color("#91bfcc"), 4)
	vitals.add_child(_health)
	vitals.add_child(_mana)

	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_status_row.add_theme_constant_override("separation", 4)
	_rows.add_child(_status_row)
	_state = _label("", 12, MUTED)
	_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.add_child(_state)
	for index in STATUS_SLOTS:
		var icon := _icon(Vector2(16, 16))
		var mark := _label("", 12, Color("#f0c982"))
		mark.custom_minimum_size = Vector2(16, 16)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_row.add_child(icon)
		_status_row.add_child(mark)
		_status_icons.append(icon)
		_status_marks.append(mark)
	_overflow = _label("", 12, MUTED)
	_status_row.add_child(_overflow)

	var skills := HBoxContainer.new()
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_theme_constant_override("separation", 4)
	_rows.add_child(skills)
	for action in fighter.actions:
		if action == null or action.category == CombatActionDefinition.Category.BASIC:
			continue
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.theme_type_variation = &"PixelInset"
		slot.tooltip_text = action.display_name
		skills.add_child(slot)
		var detail := VBoxContainer.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_theme_constant_override("separation", 0)
		slot.add_child(detail)
		var title := _label(action.display_name, 12, Color("#eed9b8"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var timer := _label("", 12, ACTIVE)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_child(title)
		detail.add_child(timer)
		_skills.append(action)
		_skill_timers.append(timer)
	refresh(false)


func set_compact(compact: bool) -> void:
	var padding := 4 if compact else 8
	_margin.add_theme_constant_override("margin_top", padding)
	_margin.add_theme_constant_override("margin_bottom", padding)
	_rows.add_theme_constant_override("separation", 2 if compact else 4)
	_portrait.custom_minimum_size = Vector2(40, 32) if compact else Vector2(52, 48)
	custom_minimum_size.y = maxf(100.0 if compact else 124.0, _margin.get_combined_minimum_size().y)


func refresh(selected: bool, respawn_seconds := 0.0) -> void:
	var active := is_instance_valid(unit) and unit.alive
	var defeated_text := "复活 %d 秒" % ceili(respawn_seconds) if respawn_seconds > 0.0 else "阵亡"
	if disabled and not active:
		_state.text = defeated_text
		tooltip_text = defeated_text
		return
	disabled = not active
	var card_face := _selected_style if selected else _normal_style
	if get_theme_stylebox("normal") != card_face:
		add_theme_stylebox_override("normal", card_face)
	_portrait.modulate = Color.WHITE if active else Color("#697483")
	_health.value = unit.hp_ratio() if active else 0.0
	_mana.value = clampf(unit.mana / maxf(1.0, unit.max_mana), 0.0, 1.0) if active else 0.0
	_state.text = unit.state_machine.display_name() if active else defeated_text
	if active:
		tooltip_text = "生命 %.0f / %.0f · 蓝量 %.0f / %.0f" % [unit.hp, unit.max_hp, unit.mana, unit.max_mana]
	else:
		tooltip_text = defeated_text
	_refresh_statuses(unit.status_controller.snapshot() if active else [])
	for index in _skills.size():
		var action := _skills[index]
		var timer := _skill_timers[index]
		var remaining := unit.action_cooldown(action) if active else 0.0
		var ready := active and remaining <= 0.01 and unit.has_mana(action) and unit.can_use_skill()
		timer.add_theme_color_override("font_color", ACTIVE if ready else MUTED)
		if not active:
			timer.text = "—"
		elif remaining > 0.01:
			timer.text = "%.1f s" % remaining
		elif not unit.has_mana(action):
			timer.text = "缺蓝"
		else:
			timer.text = "就绪" if ready else "受控"


func _refresh_statuses(statuses: Array) -> void:
	var names := PackedStringArray()
	var shown := 0
	for status: Dictionary in statuses:
		var name_text: String = status.get("display_name", "状态")
		var stacks: int = status.get("stacks", 1)
		if stacks > 1:
			name_text += " ×%d" % stacks
		names.append(name_text)
		var texture: Texture2D = status.get("icon")
		if shown < STATUS_SLOTS:
			_status_icons[shown].texture = texture
			_status_marks[shown].text = name_text.left(1)
			shown += 1
	for index in STATUS_SLOTS:
		var has_icon := _status_icons[index].texture != null
		_status_icons[index].visible = index < shown and has_icon
		_status_marks[index].visible = index < shown and not has_icon
	_overflow.visible = statuses.size() > shown
	_overflow.text = "+%d" % (statuses.size() - shown)
	_status_row.tooltip_text = " · ".join(names)


func _label(text_value: String, text_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text = text_value
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(minimum: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.custom_minimum_size = minimum
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _fit_portrait(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used := image.get_used_rect()
	if not used.has_area():
		return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = used.grow(6).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return cropped


func _bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = height
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _meter_style(Color("#1a182a")))
	bar.add_theme_stylebox_override("fill", _meter_style(color))
	return bar


func _meter_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
