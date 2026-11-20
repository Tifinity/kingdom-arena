class_name BattleRosterCard
extends Button

## 正式对战的出场单位卡。即使单位在死亡动画后释放，头像仍留在原槽位。
const STATUS_SLOTS := 5
const MUTED := Color("#8fa3ba")
const ACTIVE := Color("#96cfaa")

var unit: Unit
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
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func bind(fighter: Unit) -> void:
	unit = fighter
	var team_color := GameState.team_color(fighter.team)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_normal_style = _panel(Color("#121d2b"), team_color.darkened(0.63))
	_selected_style = _panel(Color("#1b2c40"), team_color)
	add_theme_stylebox_override("normal", _normal_style)
	add_theme_stylebox_override("hover", _panel(Color("#19283a"), team_color.darkened(0.3)))
	add_theme_stylebox_override("pressed", _selected_style)
	add_theme_stylebox_override("disabled", _panel(Color("#101823"), Color("#283849")))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 7)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	rows.add_child(header)
	var portrait_frame := PanelContainer.new()
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _panel(Color("#0a131e"), team_color.darkened(0.65)))
	header.add_child(portrait_frame)
	_portrait = _icon(Vector2(52, 48))
	_portrait.texture = _fit_portrait(fighter.definition.portrait)
	portrait_frame.add_child(_portrait)
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.add_theme_constant_override("separation", 3)
	header.add_child(vitals)
	var name_label := _label(fighter.definition.display_name, 17, Color("#ebf1fa"))
	vitals.add_child(name_label)
	_health = _bar(team_color, 6)
	_mana = _bar(Color("#56c3d7"), 4)
	vitals.add_child(_health)
	vitals.add_child(_mana)

	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_status_row.add_theme_constant_override("separation", 3)
	rows.add_child(_status_row)
	_state = _label("", 13, MUTED)
	_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.add_child(_state)
	for index in STATUS_SLOTS:
		var icon := _icon(Vector2(16, 16))
		var mark := _label("", 13, Color("#e7c46b"))
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
	rows.add_child(skills)
	for action in fighter.actions:
		if action == null or action.category == CombatActionDefinition.Category.BASIC:
			continue
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", _panel(Color("#0a131e"), Color("#273648")))
		slot.tooltip_text = action.display_name
		skills.add_child(slot)
		var detail := VBoxContainer.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_theme_constant_override("separation", 0)
		slot.add_child(detail)
		var title := _label(action.display_name, 12, Color("#c6d4e4"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var timer := _label("", 13, ACTIVE)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_child(title)
		detail.add_child(timer)
		_skills.append(action)
		_skill_timers.append(timer)
	refresh(false)
	custom_minimum_size.y = maxf(122.0, margin.get_combined_minimum_size().y)


func refresh(selected: bool) -> void:
	var active := is_instance_valid(unit) and unit.alive
	if disabled and not active:
		return
	disabled = not active
	add_theme_stylebox_override("normal", _selected_style if selected else _normal_style)
	_portrait.modulate = Color.WHITE if active else Color("#697483")
	_health.value = unit.hp_ratio() if active else 0.0
	_mana.value = clampf(unit.mana / maxf(1.0, unit.max_mana), 0.0, 1.0) if active else 0.0
	_state.text = unit.state_machine.display_name() if active else "阵亡"
	if active:
		tooltip_text = "生命 %.0f / %.0f · 蓝量 %.0f / %.0f" % [unit.hp, unit.max_hp, unit.mana, unit.max_mana]
	else:
		tooltip_text = "阵亡"
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


func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


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
	bar.add_theme_stylebox_override("background", _panel(Color("#0a111c"), Color.TRANSPARENT))
	bar.add_theme_stylebox_override("fill", _panel(color, Color.TRANSPARENT))
	return bar
