class_name StunStars
extends Node2D

## patch-gg/pixelfx 的 Stunned 循环精灵表。状态控制器负责创建和释放节点。

const FRAME_SIZE := Vector2i(60, 64)
const FRAME_COUNT := 60
const COLUMNS := 8
const FPS := 30.0
const SHEET := preload("res://assets/fx/pixelfx/stunned.png")

var _playing := false
var _elapsed := 0.0
var _frame := 0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	# 素材的视觉中心位于帧中心上方约 12 像素。
	_sprite.position = Vector2(0.0, 12.0)
	add_child(_sprite)
	_show_frame(0)
	visible = false
	set_process(false)


func play() -> void:
	_playing = true
	_elapsed = 0.0
	_show_frame(0)
	visible = true
	set_process(true)


func stop() -> void:
	_playing = false
	visible = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func star_count() -> int:
	return 3


func current_frame() -> int:
	return _frame


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_show_frame(int(_elapsed * FPS) % FRAME_COUNT)


func _show_frame(index: int) -> void:
	_frame = index
	if _sprite != null:
		_sprite.region_rect = Rect2(
			Vector2i(index % COLUMNS, index / COLUMNS) * FRAME_SIZE,
			FRAME_SIZE
		)
