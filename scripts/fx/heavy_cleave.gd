@tool
extends Node2D

## patch-gg/pixelfx Heavy cleave 的透明逐帧动画。
const FRAME_SIZE := Vector2i(208, 116)
const FRAME_COUNT := 58
const COLUMNS := 6
const FPS := 30.0
const SOURCE_PIVOT := Vector2(36.0, -38.0)

## 在 heavy_cleave.tscn 的 Inspector 中调整。偏移相对施法者脚底，Y 向下为正。
@export var effect_offset := Vector2.ZERO:
	set(value):
		effect_offset = value
		_update_sprite_transform()
@export_range(0.5, 3.0, 0.1) var effect_scale := 1.5:
	set(value):
		effect_scale = value
		_update_sprite_transform()
@export_range(0.1, 3.0, 0.1) var playback_speed := 1.0
## 仅用于编辑器：关闭播放后可拖动时间，逐帧比较人物与特效。
@export var preview_play := true
@export_range(0.0, 1.9, 0.033) var preview_time := 0.0:
	set(value):
		preview_time = value
		if Engine.is_editor_hint():
			_show_preview(value)

var elapsed := 0.0
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	z_index = 25
	_update_sprite_transform()
	_show_frame(0)
	if Engine.is_editor_hint():
		_show_preview(preview_time)


func setup_from_effect(source: Unit, _effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	global_position = source.global_position
	scale.x = -1.0 if source.visual.flip_h else 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if preview_play:
			preview_time = fmod(preview_time + delta * playback_speed, float(FRAME_COUNT) / FPS)
		_show_preview(preview_time)
		return
	elapsed += delta * playback_speed
	var frame := int(elapsed * FPS)
	if frame >= FRAME_COUNT:
		if Engine.is_editor_hint():
			elapsed = 0.0
			_show_frame(0)
		else:
			queue_free()
	else:
		_show_frame(frame)


func _show_frame(frame: int) -> void:
	sprite.region_rect = Rect2(Vector2i(frame % COLUMNS, int(frame / COLUMNS)) * FRAME_SIZE, FRAME_SIZE)


func _show_preview(time: float) -> void:
	var effect_sprite := get_node_or_null("Sprite") as Sprite2D
	if effect_sprite == null:
		return
	var frame := mini(int(time * FPS), FRAME_COUNT - 1)
	effect_sprite.region_rect = Rect2(Vector2i(frame % COLUMNS, int(frame / COLUMNS)) * FRAME_SIZE, FRAME_SIZE)


func _update_sprite_transform() -> void:
	var preview_sprite := get_node_or_null("Sprite") as Sprite2D
	if preview_sprite == null:
		return
	preview_sprite.scale = Vector2.ONE * effect_scale
	preview_sprite.position = SOURCE_PIVOT * effect_scale + effect_offset
